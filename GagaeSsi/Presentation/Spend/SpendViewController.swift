//
//  SpendViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import UIKit

final class SpendViewController: BaseViewController {

    private let viewModel = SpendViewModel()

    private let titleTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "내용 (예: 커피)"
        tf.borderStyle = .roundedRect
        return tf
    }()

    private let amountTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "금액 (예: 5,000)"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        return tf
    }()

    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .compact
        return dp
    }()

    private let saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("저장", for: .normal)
        btn.isEnabled = false
        btn.backgroundColor = .systemGray
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
//        btn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        return btn
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupActions()
        
        let today = Calendar.current.startOfDay(for: Date())
        
        viewModel.fetchSpending(on: today)
        print("viewDidLoad : \(viewModel.spendingRecords)")
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "소비 기록"

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleTextField, amountTextField, datePicker, saveButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    // MARK: - Actions
    private func setupActions() {
        titleTextField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)
        amountTextField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
    }
    
    @objc private func titleChanged() {
        guard let text = titleTextField.text else { return }
        
        viewModel.tempTitle = text

        updateSaveButtonState()
    }
    
    @objc private func amountChanged() {
        guard let result = FormatterUtils.formatCurrencyInput(amountTextField.text) else { return }

        viewModel.tempAmount = result.plainNumber
        amountTextField.text = result.formatted

        updateSaveButtonState()
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = viewModel.isValid
        saveButton.backgroundColor = viewModel.isValid ? .systemBlue : .systemGray
    }

    @objc private func saveTapped() {
        viewModel.model.title = viewModel.tempTitle
        viewModel.model.amount = viewModel.tempAmount
        viewModel.model.date = datePicker.date

        viewModel.saveSpending { [weak self] success in
            guard let self = self else { return }
            
            if success {
                AlertHelper.showConfirm(on: self, title: "성공", message: "지출 내역 저장에 성공했습니다.")
                self.navigationController?.popViewController(animated: true)
                self.tableView.reloadData()
            } else {
                AlertHelper.showError(on: self, message: "지출 내역 저장에 실패했습니다.")
            }
        }
    }

    private func clearForm() {
        titleTextField.text = ""
        amountTextField.text = ""
        datePicker.date = Date()
        
        viewModel.tempTitle = ""
        viewModel.tempAmount = 0
        viewModel.tempDate = Date()
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SpendViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("tableView : \(viewModel.spendingRecords)")
        
        return viewModel.spendingRecords.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let record = viewModel.spendingRecords[indexPath.row]

        cell.textLabel?.text = "\(record.title) : \(FormatterUtils.currencyString(from: record.amount))"
        return cell
    }
}
