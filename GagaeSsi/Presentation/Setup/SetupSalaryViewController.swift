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
    
    @objc private func salaryChanged() {
        // 현재 입력된 문자열 (예: "1,200,000")
        guard let rawText = salaryTextField.text else { return }
        
        // 쉼표 제거된 숫자 문자열 (예: "1200000")
        let plainText = rawText.replacingOccurrences(of: ",", with: "")
        let number = Int(plainText) ?? 0

        // ViewModel 임시 값에 저장 (실시간 유효성 검사용)
        viewModel.tempSalary = number

        // 텍스트 포맷
        let formatted = FormatterUtils.currencyFormatter.string(from: NSNumber(value: number))
        salaryTextField.text = formatted

        updateNextButtonState()
    }

    @objc private func paydayChanged() {
        viewModel.tempPayday = paydayPicker.date
        updateNextButtonState()
    }

    @objc private func nextTapped() {
        // 여기서만 실제 모델에 확정 저장
        viewModel.model.salary = viewModel.tempSalary
        viewModel.model.payday = viewModel.tempPayday

        // 다음 화면 이동
        let fixedCostVC = SetupFixedCostViewController(viewModel: viewModel)
        navigationController?.pushViewController(fixedCostVC, animated: true)
    }

    private func updateNextButtonState() {
        nextButton.isEnabled = viewModel.isValid
        nextButton.backgroundColor = viewModel.isValid ? .systemBlue : .systemGray
    }
}
