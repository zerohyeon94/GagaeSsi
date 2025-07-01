//
//  FixedExpenseListViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/31/25.
//

import UIKit
import RxSwift

final class FixedExpenseListViewController: BaseViewController {
    // MARK: - Properties
    private let viewModel = FixedExpenseListViewModel()
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "고정비 목록"
        view.backgroundColor = .systemBackground

        setupTableView()
        setupNavigationBar()
        
        bind()
        viewModel.bind()
        viewModel.fetchFixedCosts()
    }

    // MARK: - UI Setup
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    // MARK: - Actions
    @objc private func didTapAdd() {
        let editVC = FixedExpenseEditViewController()
        
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    // MARK: - Bindings
    private func bind() {
        viewModel.fixedCosts
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Event Handlers
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapAdd)
        )
    }
}

// MARK: - UITableViewDataSource
extension FixedExpenseListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.fixedCosts.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.fixedCosts.value[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = "₩\(item.amount.formatted())"
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension FixedExpenseListViewController: UITableViewDelegate {
    // Swipe-to-delete
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            self?.viewModel.deleteFixedCost(at: indexPath.row)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
    
    // 사용자가 특정 셀을 탭한 경우
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = viewModel.fixedCosts.value[indexPath.row]

        let editVC = FixedExpenseEditViewController(editingItem: model)

        navigationController?.pushViewController(editVC, animated: true)
    }
}
