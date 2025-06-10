//
//  FixedExpenseEditViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/1/25.
//

import UIKit

final class FixedExpenseEditViewController: BaseViewController {
    private let viewModel: FixedExpenseEditViewModel

    private let titleTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "고정비 이름 (예: 월세)"
        tf.borderStyle = .roundedRect
        return tf
    }()

    private let amountTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "금액 입력 (예: 500,000)"
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

    init(editingItem: FixedCostModel? = nil, object: FixedCost? = nil) {
        if let item = editingItem {
            viewModel = FixedExpenseEditViewModel(title: item.title, amount: item.amount, object: object)
        } else {
            viewModel = FixedExpenseEditViewModel()
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "고정비 항목"
        view.backgroundColor = .systemBackground
        setupUI()
        setupActions()
        
        setText()
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [titleTextField, amountTextField, saveButton])
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
        let titleText = viewModel.fixedCost.title
        let amountText = FormatterUtils.inputAmountString(from: viewModel.fixedCost.amount)
        
        titleTextField.text = titleText
        amountTextField.text = amountText
        
        print("")
        
        updateNextButtonState()
    }
    
    // MARK: - Actions
    private func setupActions() {
        titleTextField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)
        amountTextField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
    }
    
    @objc private func titleChanged() {
        guard let result = titleTextField.text else { return }

        viewModel.tempTitle = result

        updateNextButtonState()
    }

    @objc private func amountChanged() {
        guard let result = FormatterUtils.formatCurrencyInput(amountTextField.text) else { return }
        
        viewModel.tempAmount = result.plainNumber
        amountTextField.text = result.formatted
        updateNextButtonState()
    }

    @objc private func didTapSave() {
        viewModel.fixedCost.title = viewModel.tempTitle
        viewModel.fixedCost.amount = viewModel.tempAmount
        
        viewModel.saveFixedExpense()
        
        navigationController?.popViewController(animated: true)
    }
    
    private func updateNextButtonState() {
        saveButton.isEnabled = viewModel.isValid
        saveButton.backgroundColor = viewModel.isValid ? .systemBlue : .systemGray
    }
}
