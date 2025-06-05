//
//  SetupSalaryViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import UIKit

final class SetupSalaryViewController: BaseViewController {
    
    // MARK: - UI Components
    private let salaryTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "월급을 입력하세요 (예: 3000000)"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        return tf
    }()

    private let paydayTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "월급일을 입력하세요 (예: 1 ~ 31)"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        return tf
    }()

    private let nextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("다음", for: .normal)
        btn.isEnabled = false
        btn.backgroundColor = .systemGray
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        return btn
    }()

    // MARK: - ViewModel
    private let viewModel: SetupViewModel
    
    init(viewModel: SetupViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupActions()
    }

    // MARK: - Layout
    private func setupLayout() {
        [salaryTextField, paydayTextField, nextButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            salaryTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            salaryTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            salaryTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            paydayTextField.topAnchor.constraint(equalTo: salaryTextField.bottomAnchor, constant: 30),
            paydayTextField.leadingAnchor.constraint(equalTo: salaryTextField.leadingAnchor),
            
            nextButton.topAnchor.constraint(equalTo: paydayTextField.bottomAnchor, constant: 40),
            nextButton.leadingAnchor.constraint(equalTo: salaryTextField.leadingAnchor),
            nextButton.trailingAnchor.constraint(equalTo: salaryTextField.trailingAnchor),
            nextButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Actions
    private func setupActions() {
        salaryTextField.addTarget(self, action: #selector(salaryChanged), for: .editingChanged)
        paydayTextField.addTarget(self, action: #selector(paydayChanged), for: .editingChanged)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
    }
    
    @objc private func salaryChanged() {
        guard let result = FormatterUtils.formatCurrencyInput(salaryTextField.text) else { return }

        // ViewModel 임시 값에 저장 (실시간 유효성 검사용)
        viewModel.tempSalary = result.plainNumber
        
        salaryTextField.text = result.formatted

        updateNextButtonState()
    }

    @objc private func paydayChanged() {
        guard let rawText = paydayTextField.text else { return }
        
        viewModel.tempPayday = Int(rawText) ?? 0
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
