//
//  SetupViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import Foundation

final class SetupViewModel {
    // MARK: - Properties
    var model: BudgetConfigModel
    var tempSalary: Int = 0
    var tempPayday: Int = 0

    // MARK: - Computed
    var isValid: Bool {
        tempSalary > 0 && tempPayday > 0
    }
    
    // MARK: - Init
    init() {
        self.model = BudgetConfigModel(salary: 0, payday: 0, fixedCosts: [])
    }
    
    // MARK: - Public Methods
    func saveBudgetConfig(completion: @escaping (Bool) -> Void) {
        let success = CoreDataManager.shared.createBudgetConfig(from: model)
        completion(success)
    }
}
