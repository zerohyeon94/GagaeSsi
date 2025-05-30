//
//  EditBudgetViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/30/25.
//

import UIKit

final class EditBudgetViewController: BaseViewController {
    private let viewModel: EditBudgetViewModel

    private let salaryTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "월급 입력 (예: 3000000)"
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
        return btn
    }()

    init(currentSalary: Int, currentPayday: Int) {
        self.viewModel = EditBudgetViewModel(currentSalary: currentSalary, currentPayday: currentPayday)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "예산 설정"
        view.backgroundColor = .systemBackground
        setupUI()
        bindViewModel()
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

        salaryTextField.text = "\(viewModel.salary)"
        paydayTextField.text = "\(viewModel.payday)"
    }

    private func bindViewModel() {
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
    }

    @objc private func didTapSave() {
        guard
            let salaryText = salaryTextField.text,
            let paydayText = paydayTextField.text,
            let salary = Int(salaryText),
            let payday = Int(paydayText),
            (1...31).contains(payday)
        else {
            showAlert("입력값을 확인해주세요.")
            return
        }

        viewModel.updateSalary(salary)
        viewModel.updatePayday(payday)
        viewModel.save()
        navigationController?.popViewController(animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // 외부에서 저장 콜백 연결할 수 있도록
    func onSave(_ handler: @escaping (Int, Int) -> Void) {
        viewModel.onSave = handler
    }
}
