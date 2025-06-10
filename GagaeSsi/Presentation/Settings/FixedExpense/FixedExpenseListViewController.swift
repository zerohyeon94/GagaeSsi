//
//  FixedExpenseListViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/31/25.
//

import UIKit
import RxSwift

final class FixedExpenseListViewController: BaseViewController {
    private let disposeBag = DisposeBag()
    private let viewModel = FixedExpenseListViewModel()
    
    private let tableView = UITableView()

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

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func bind() {
        viewModel.fixedCosts
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
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
        
        navigationController?.pushViewController(editVC, animated: true)
    }
}

extension FixedExpenseListViewController: UITableViewDataSource, UITableViewDelegate {
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
        let model = viewModel.fixedCosts.value[indexPath.row]
        let name = model.title

        // CoreData 객체도 함께 찾기
        let fixedObjects = CoreDataManager.shared.fetchFixedCostEntity(named: name)
        let editVC = FixedExpenseEditViewController(editingItem: model, object: fixedObjects)

        navigationController?.pushViewController(editVC, animated: true)
    }
}
