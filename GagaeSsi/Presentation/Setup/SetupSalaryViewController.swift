//
//  SetupSalaryViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import UIKit

final class SetupSalaryViewController: BaseViewController {
    // MARK: - Properties
    private let viewModel: SetupViewModel
    
    // MARK: - UI Components
    private let characterImageView: UIImageView = {
       let iv = UIImageView()
        iv.image = UIImage(named: "characterPig")
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "월급을 입력해주세요."
        label.textColor = UIColor(named: "textColor")
        return label
    }()
    
    private let currencyLabel: UILabel = {
        let label = UILabel()
        label.text = "₩"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        return label
    }()
    
    private let salaryTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "0,000,000"
//        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        return tf
    }()
    
    private let salaryStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .fill
        sv.distribution = .equalSpacing
        sv.spacing = 8
        return sv
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
    
    // MARK: - Initializer
    init(viewModel: SetupViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupActions()
    }

    // MARK: - UI Setup
    private func setupLayout() {
        [characterImageView, titleLabel, salaryStackView, paydayTextField, nextButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        [currencyLabel, salaryTextField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            salaryStackView.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            characterImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            characterImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            characterImageView.widthAnchor.constraint(equalToConstant: 100),
            characterImageView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: characterImageView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            salaryStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            salaryStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            paydayTextField.topAnchor.constraint(equalTo: salaryStackView.bottomAnchor, constant: 30),
            paydayTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            nextButton.topAnchor.constraint(equalTo: paydayTextField.bottomAnchor, constant: 40),
            nextButton.leadingAnchor.constraint(equalTo: salaryTextField.leadingAnchor),
            nextButton.trailingAnchor.constraint(equalTo: salaryTextField.trailingAnchor),
            nextButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Actions/Bindings
    private func setupActions() {
        salaryTextField.addTarget(self, action: #selector(salaryChanged), for: .editingChanged)
        paydayTextField.addTarget(self, action: #selector(paydayChanged), for: .editingChanged)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
    }
    
    // MARK: - Event Handlers
    @objc private func salaryChanged() {
        guard let result = FormatterUtils.formatCurrencyInput(salaryTextField.text) else { return }
        
        currencyLabel.textColor = .text

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

    // MARK: - Helpers
    private func updateNextButtonState() {
        nextButton.isEnabled = viewModel.isValid
        nextButton.backgroundColor = viewModel.isValid ? .systemBlue : .systemGray
    }
}
