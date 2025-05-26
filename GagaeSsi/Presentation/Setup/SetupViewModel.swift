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
    
    // 실시간 유효성 체크용 임시 변수 (화면과 연결)
    var tempSalary: Int = 0
    var tempPayday: Date = Date()

    var isValid: Bool {
        return tempSalary > 0 && tempPayday <= Date()
    }
}
