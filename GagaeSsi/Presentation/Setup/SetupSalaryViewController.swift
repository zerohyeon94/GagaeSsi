//
//  SetupSalaryViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import UIKit

final class SetupSalaryViewController: UIViewController {

    // MARK: - UI Components
    private let salaryTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "월급을 입력하세요 (예: 3000000)"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        return tf
    }()

    private let paydayPicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    private let nextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("다음", for: .normal)
        btn.isEnabled = false
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        return btn
    }()

    // MARK: - ViewModel
    private let viewModel = SetupViewModel()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupActions()
    }

    // MARK: - Layout
    private func setupLayout() {
        [salaryTextField, paydayPicker, nextButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            salaryTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            salaryTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            salaryTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            paydayPicker.topAnchor.constraint(equalTo: salaryTextField.bottomAnchor, constant: 30),
            paydayPicker.leadingAnchor.constraint(equalTo: salaryTextField.leadingAnchor),
            
            nextButton.topAnchor.constraint(equalTo: paydayPicker.bottomAnchor, constant: 40),
            nextButton.leadingAnchor.constraint(equalTo: salaryTextField.leadingAnchor),
            nextButton.trailingAnchor.constraint(equalTo: salaryTextField.trailingAnchor),
            nextButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Actions
    private func setupActions() {
        salaryTextField.addTarget(self, action: #selector(salaryChanged), for: .editingChanged)
        paydayPicker.addTarget(self, action: #selector(paydayChanged), for: .valueChanged)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
    }
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal // 천 단위 쉼표
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    @objc private func salaryChanged() {
        // 현재 입력된 문자열 (예: "1,200,000")
        guard let rawText = salaryTextField.text else { return }
        
        // 쉼표 제거된 숫자 문자열 (예: "1200000")
        let plainText = rawText.replacingOccurrences(of: ",", with: "")
        
        // 숫자로 변환
        if let number = Int(plainText) {
            // 모델에 저장
            viewModel.model.salary = number
            
            // 다시 포맷된 문자열로 업데이트
            let formatted = numberFormatter.string(from: NSNumber(value: number))
            
            // 커서 위치 보존 없이 업데이트 (간단한 방식)
            salaryTextField.text = formatted
        } else {
            // 숫자가 아님 → 0 처리
            viewModel.model.salary = 0
            salaryTextField.text = nil
        }
        
        updateNextButtonState()
    }


    @objc private func paydayChanged() {
        viewModel.model.payday = paydayPicker.date
        updateNextButtonState()
    }

    private func updateNextButtonState() {
        nextButton.isEnabled = viewModel.isValid
        nextButton.backgroundColor = viewModel.isValid ? .systemBlue : .systemGray
    }

    @objc private func nextTapped() {
        print("next Button")
        let nextVC = SetupFixedCostViewController(viewModel: viewModel)
        navigationController?.pushViewController(nextVC, animated: true)
    }
}
