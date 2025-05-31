//
//  FixedExpenseListViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/31/25.
//

import Foundation

final class FixedExpenseListViewModel {
    private(set) var fixedCosts: [FixedCostModel] = []

    var onDataUpdated: (() -> Void)?

    func fetchFixedCosts() {
        fixedCosts = CoreDataManager.shared.fetchFixedCosts()
        onDataUpdated?()
    }

    func deleteItem(at index: Int) {
        let item = fixedCosts[index]
        CoreDataManager.shared.deleteFixedCost(named: item.title)
        fixedCosts.remove(at: index)
        onDataUpdated?()
    }
}
