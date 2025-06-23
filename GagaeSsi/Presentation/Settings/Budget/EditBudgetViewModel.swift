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
        if let config = CoreDataManager.shared.fetchBudgetConfig() {
            // ✅ 존재할 때 처리
            budget = config
            tempSalary = budget.salary
            tempPayday = budget.payday
        } else {
            // ❗ 존재하지 않음 → 사용자에게 메시지 표시하거나 초기 설정 유도
//            showInitialSetupUI()
        }        
    }
    
    var tempSalary: Int = 0
    var tempPayday: Int = 0

    var isValid: Bool {
        return tempSalary > 0 && tempPayday > 0
    }

    func updateBudget() {
        let success = CoreDataManager.shared.updateBudgetConfig(budget)
        if success {
            print("✅ 업데이트 성공")
            AppEventBus.shared.budgetChanged.onNext(())
        } else {
            print("⚠️ BudgetConfig가 존재하지 않아 업데이트 실패")
            // → 설정화면 유도 or alert
        }
    }
}
