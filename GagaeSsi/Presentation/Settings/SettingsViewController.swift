//
//  SettingsViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import UIKit

final class SettingsViewController: BaseViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var viewModel: SettingsViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "설정"
        view.backgroundColor = .systemBackground

        viewModel = SettingsViewModel { [weak self] action in
            print("action : \(action)")
            self?.handle(action: action)
        }

        setupTableView()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func handle(action: SettingsAction) {
        switch action {
        case .editBudget:
            print("➡️ 월급 수정 화면으로 이동")
            let config = CoreDataManager.shared.fetchBudgetConfig()
            print("config.salary : \(config.salary)")
            print("config.payday : \(config.payday)")
            print("config.fixedCosts : \(config.fixedCosts)")
            let vc = EditBudgetViewController(currentSalary: config.salary, currentPayday: config.payday)
            
            vc.onSave { salary, payday in
                CoreDataManager.shared.updateBudgetConfig(salary: salary, payday: payday)
            }
            
            navigationController?.pushViewController(vc, animated: true)
        case .manageFixedExpenses:
            print("➡️ 고정비 관리 화면으로 이동")
        case .resetData:
            print("🗑 데이터 초기화")
        case .backupData:
            print("📦 데이터 백업")
        case .sendFeedback:
            print("📧 피드백 전송")
        default:
            break
        }
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        SettingSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.settingSections[section].count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        SettingSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.settingSections[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = item.title
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = viewModel.settingSections[indexPath.section][indexPath.row]
        item.action()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

