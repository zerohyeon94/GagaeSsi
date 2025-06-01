//
//  FixedExpenseEditViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/1/25.
//

import UIKit

final class FixedExpenseEditViewController: UIViewController {
    private let viewModel: FixedExpenseEditViewModel

    private let titleField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "고정비 이름 (예: 월세)"
        tf.borderStyle = .roundedRect
        return tf
    }()

    private let amountField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "금액 입력 (예: 500000)"
        tf.keyboardType = .numberPad
        tf.borderStyle = .roundedRect
        return tf
    }()

    private let saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("저장", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        return btn
    }()

    init(editingItem: FixedCostModel? = nil, object: FixedCost? = nil) {
        if let item = editingItem {
            viewModel = FixedExpenseEditViewModel(title: item.title, amount: item.amount)
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
        bind()
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [titleField, amountField, saveButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        titleField.text = viewModel.title
        amountField.text = "\(viewModel.amount)"
    }

    private func bind() {
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
    }

    @objc private func didTapSave() {
        guard let titleText = titleField.text, !titleText.isEmpty,
              let amountText = amountField.text, Int(amountText) != nil else {
            showAlert("입력값을 확인해주세요.")
            return
        }

//        viewModel.updateTitle(titleText)
//        viewModel.updateAmount(amountText)
        viewModel.save()
        navigationController?.popViewController(animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // 1. 기본 저장용 (추가)
    func onSave(_ handler: @escaping (FixedCostModel) -> Void) {
        viewModel.onSave = { model, _ in
            handler(model)
        }
    }

    // 2. 수정용
    func onSave(_ handler: @escaping (FixedCostModel, FixedCost?) -> Void) {
        viewModel.onSave = handler
    }
}
