//
//  FixedExpenseListViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/31/25.
//

import UIKit

final class FixedExpenseListViewController: BaseViewController {
    private let tableView = UITableView()
    private let viewModel = FixedExpenseListViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "고정비 목록"
        view.backgroundColor = .systemBackground

        setupTableView()
        bindViewModel()
        setupNavigationBar()
        viewModel.fetchFixedCosts()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func bindViewModel() {
        viewModel.onDataUpdated = { [weak self] in
            self?.tableView.reloadData()
        }
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapAdd)
        )
    }

    @objc private func didTapAdd() {
        let editVC = FixedExpenseEditViewController()
        editVC.onSave { [weak self] newItem in
            CoreDataManager.shared.insertOrUpdateFixedCost(newItem)
            self?.viewModel.fetchFixedCosts()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }
}

extension FixedExpenseListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.fixedCosts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.fixedCosts[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = "₩\(item.amount.formatted())"
        
        return cell
    }

    // Swipe-to-delete
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            self?.viewModel.deleteItem(at: indexPath.row)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
    
    // 사용자가 특정 셀을 탭한 경우
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = viewModel.fixedCosts[indexPath.row]
        let name = model.title

        // CoreData 객체도 함께 찾기
        let fixedObjects = CoreDataManager.shared.fetchFixedCostEntity(named: name)
        let editVC = FixedExpenseEditViewController(editingItem: model, object: fixedObjects)

        editVC.onSave { [weak self] model, original in
            CoreDataManager.shared.updateFixedCost(model, original: original)
            self?.viewModel.fetchFixedCosts()
        }

        navigationController?.pushViewController(editVC, animated: true)
    }

}
