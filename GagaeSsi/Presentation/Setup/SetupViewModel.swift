//
//  SetupViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import Foundation

final class SetupViewModel {
    // 모델 상태 보관용
    var model: BudgetConfigModel

    init() {
        self.model = BudgetConfigModel(salary: 0, payday: Date(), fixedCosts: [])
    }

    var isValid: Bool {
        return model.salary > 0 && model.payday <= Date()
    }
}
