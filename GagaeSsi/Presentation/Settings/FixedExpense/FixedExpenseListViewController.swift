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
        print("➕ 고정비 추가 화면 이동 예정")
        // navigationController?.pushViewController(FixedExpenseEditViewController(), animated: true)
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
}
