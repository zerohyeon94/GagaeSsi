//
//  EditBudgetViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/30/25.
//

import Foundation

final class EditBudgetViewModel {
    var budget: BudgetConfigModel
    
    init() {
        self.budget = BudgetConfigModel(salary: 0, payday: 0, fixedCosts: [])
    }
    
    func fetchBudget() {
        budget = CoreDataManager.shared.fetchBudgetConfig()
        tempSalary = budget.salary
        tempPayday = budget.payday
    }
    
    var tempSalary: Int = 0
    var tempPayday: Int = 0

    var isValid: Bool {
        return tempSalary > 0 && tempPayday > 0
    }

    func updateBudget() {
        CoreDataManager.shared.updateBudgetConfig(salary: budget.salary, payday: budget.payday)
        AppEventBus.shared.budgetChanged.onNext(())
    }
}
