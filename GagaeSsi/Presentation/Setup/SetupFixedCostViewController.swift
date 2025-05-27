//
//  SetupFixedCostViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import UIKit

final class SetupFixedCostViewController: UIViewController {
    
    // MARK: - UI
    private let tableView = UITableView()
    private let addButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    // MARK: - ViewModel
    private let viewModel: SetupViewModel

    // MARK: - Init
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
        setupUI()
        setupTableView()
        setupActions()
    }

    // MARK: - UI 구성
    private func setupUI() {
        addButton.setTitle("＋ 고정비 추가", for: .normal)
        skipButton.setTitle("건너뛰기", for: .normal)
        saveButton.setTitle("저장하고 시작하기", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 8
        
        [tableView, addButton, skipButton, saveButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            addButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            tableView.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -20),

            skipButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            skipButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.widthAnchor.constraint(equalToConstant: 180),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupTableView() {
        tableView.register(FixedCostCell.self, forCellReuseIdentifier: "FixedCostCell")
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupActions() {
        addButton.addTarget(self, action: #selector(addFixedCostTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    }

    // MARK: - Actions
    @objc private func addFixedCostTapped() {
        let alert = UIAlertController(title: "고정비 추가", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "이름 (예: 집세)" }
        alert.addTextField {
            $0.placeholder = "금액 (예: 500000)"
            $0.keyboardType = .numberPad
            $0.addTarget(self, action: #selector(self.alertAmountChanged(_:)), for: .editingChanged)
        }
        let add = UIAlertAction(title: "추가", style: .default) { _ in
            guard let title = alert.textFields?[0].text,
                  let rawAmountText = alert.textFields?[1].text,
                  !title.isEmpty else { return }

            let plainText = rawAmountText.replacingOccurrences(of: ",", with: "")
            guard let amount = Int(plainText) else { return }
            
            print("amount : \(amount)")

            self.viewModel.model.fixedCosts.append(FixedCostModel(title: title, amount: amount))
            self.tableView.reloadData()
        }

        alert.addAction(add)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func alertAmountChanged(_ textField: UITextField) {
        let formatter = FormatterUtils.currencyFormatter

        let raw = textField.text ?? ""
        let plain = raw.replacingOccurrences(of: ",", with: "")

        if let number = Int(plain) {
            let formatted = formatter.string(from: NSNumber(value: number))
            textField.text = formatted
        } else {
            textField.text = nil
        }
    }

    // 고정비 추가 없이 홈화면으로 이동
    @objc private func skipTapped() {
//        CoreDataManager.shared.save(budgetModel: viewModel.model)
        
        switchToMainTabBar()
    }
    
    @objc private func saveTapped() {
//        CoreDataManager.shared.save(budgetModel: viewModel.model)
        
        switchToMainTabBar()
    }
    
    private func switchToMainTabBar() {
        let tabBar = MainTabBarController()

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            window.rootViewController = tabBar
            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve, // transitionFlipFromRight
                              animations: nil,
                              completion: nil)
        }
    }
}

// MARK: - TableView DataSource
extension SetupFixedCostViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.model.fixedCosts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let fixed = viewModel.model.fixedCosts[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "FixedCostCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = fixed.title
        content.secondaryText = "₩\(fixed.amount.formatted())"
        cell.contentConfiguration = content
        return cell
    }
}
