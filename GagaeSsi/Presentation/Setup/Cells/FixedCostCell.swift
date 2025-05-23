//
//  FixedCostCell.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import UIKit

final class FixedCostCell: UITableViewCell {

    // MARK: - UI
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()

    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .right
        label.textColor = .systemGray
        return label
    }()

    private let containerStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.distribution = .equalSpacing
        return sv
    }()

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout
    private func setupLayout() {
        containerStackView.addArrangedSubview(titleLabel)
        containerStackView.addArrangedSubview(amountLabel)
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerStackView)

        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            containerStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            containerStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Configuration
    func configure(with model: FixedCostModel) {
        titleLabel.text = model.title
        amountLabel.text = "₩\(model.amount.formatted())"
    }
}
