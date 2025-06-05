//
//  HomeViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import UIKit

final class HomeViewController: BaseViewController {
    
    private let viewModel = HomeViewModel()

    // MARK: - UI Components
    private let availableTodayLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 28)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 1
        label.text = "오늘 사용할 수 있는 금액: ₩0"
        return label
    }()

    private let calculationInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "(전일 이월 ₩0 + 오늘 예산 ₩0)"
        return label
    }()

    private let recentSummaryView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        return view
    }()

    private let recentSummaryLabel: UILabel = {
        let label = UILabel()
        label.text = "최근 7일 소비 요약 (디자인 예정)"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("소비 기록하기", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 10
        return button
    }()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "오늘 얼마?"
        setupLayout()
        loadBudgetData()
    }

    // MARK: - Layout
    private func setupLayout() {
        [availableTodayLabel, calculationInfoLabel, recentSummaryView, recordButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        recentSummaryView.addSubview(recentSummaryLabel)
        recentSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            availableTodayLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            availableTodayLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            calculationInfoLabel.topAnchor.constraint(equalTo: availableTodayLabel.bottomAnchor, constant: 8),
            calculationInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            recentSummaryView.topAnchor.constraint(equalTo: calculationInfoLabel.bottomAnchor, constant: 32),
            recentSummaryView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            recentSummaryView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            recentSummaryView.heightAnchor.constraint(equalToConstant: 120),
            
            recentSummaryLabel.centerXAnchor.constraint(equalTo: recentSummaryView.centerXAnchor),
            recentSummaryLabel.centerYAnchor.constraint(equalTo: recentSummaryView.centerYAnchor),
            
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 200),
            recordButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Data Binding
    private func loadBudgetData() {
        viewModel.fetchTodayBudget()

        updateBudgetLabel(total: viewModel.todayAvailableAmount)
        
        let carryOverText = FormatterUtils.currencyString(from: viewModel.carryOverAmount)
        let baseBudgetText = FormatterUtils.currencyString(from: viewModel.baseBudget)
        let spentAmountText = FormatterUtils.currencyString(from: viewModel.spentAmount)

        calculationInfoLabel.text = "(이월 \(carryOverText) + 오늘 예산 \(baseBudgetText) - 소비 \(spentAmountText))"
    }
    
    private func updateBudgetLabel(total: Int) {
        let title = "오늘 사용할 수 있는 금액: "
        let value = FormatterUtils.currencyString(from: total)

        let attributedText = NSMutableAttributedString(
            string: title,
            attributes: [.font: UIFont.systemFont(ofSize: 20, weight: .regular),
                         .foregroundColor: UIColor.label]
        )

        let valueText = NSAttributedString(
            string: value,
            attributes: [.font: UIFont.boldSystemFont(ofSize: 28),
                         .foregroundColor: UIColor.systemBlue]
        )

        attributedText.append(valueText)
        availableTodayLabel.attributedText = attributedText
    }
}
