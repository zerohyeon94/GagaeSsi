//
//  SetupModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/23/25.
//

import Foundation

struct BudgetConfigModel {
    var salary: Int
    var payday: Int
    var fixedCosts: [FixedCostModel]
    
    // 💡 기본 생성자 명시적으로 선언
    init(salary: Int, payday: Int, fixedCosts: [FixedCostModel]) {
        self.salary = salary
        self.payday = payday
        self.fixedCosts = fixedCosts
    }
    
    init(entity: BudgetConfig) {
        self.salary = Int(truncating: entity.salary ?? 0)
        self.payday = Int(truncating: entity.payday ?? 0)
        
        let costs = entity.fixedCosts?.allObjects as? [FixedCost] ?? []
        self.fixedCosts = costs.map(FixedCostModel.init)
    }
}

struct FixedCostModel {
    var id: UUID
    var title: String
    var amount: Int
    
    init(entity: FixedCost) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
    }
}
