//
//  EditBudgetViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/30/25.
//

import UIKit

final class EditBudgetViewController: BaseViewController {
    
    private let viewModel = EditBudgetViewModel()

    private let salaryTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "월급 입력 (예: 3,000,000)"
        tf.keyboardType = .numberPad
        tf.borderStyle = .roundedRect
        return tf
    }()

    private let paydayTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "월급일 (1~31)"
        tf.keyboardType = .numberPad
        tf.borderStyle = .roundedRect
        return tf
    }()

    private let saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("저장", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "예산 설정"
        view.backgroundColor = .systemBackground
        setupUI()
        setupActions()
        
        viewModel.fetchBudget()
        setText()
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [salaryTextField, paydayTextField, saveButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setText() {
        let salaryText = viewModel.budget.salary.formatted()
        let paydayText = String(viewModel.budget.payday)
        
        salaryTextField.text = salaryText
        paydayTextField.text = paydayText
    }
    
    // MARK: - Actions
    private func setupActions() {
        salaryTextField.addTarget(self, action: #selector(salaryChanged), for: .editingChanged)
        paydayTextField.addTarget(self, action: #selector(paydayChanged), for: .editingChanged)
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
    }
    
    @objc private func salaryChanged() {
        guard let result = FormatterUtils.formatCurrencyInput(salaryTextField.text) else { return }

        viewModel.tempSalary = result.plainNumber
        salaryTextField.text = result.formatted

        updateNextButtonState()
    }

    @objc private func paydayChanged() {
        guard let rawText = paydayTextField.text else { return }
        
        viewModel.tempPayday = Int(rawText) ?? 0
        updateNextButtonState()
    }

    @objc private func didTapSave() {
        viewModel.budget.salary = viewModel.tempSalary
        viewModel.budget.payday = viewModel.tempPayday
        
        viewModel.updateBudget()
        
        navigationController?.popViewController(animated: true)
    }
    
    private func updateNextButtonState() {
        saveButton.isEnabled = viewModel.isValid
        saveButton.backgroundColor = viewModel.isValid ? .systemBlue : .systemGray
    }
}
