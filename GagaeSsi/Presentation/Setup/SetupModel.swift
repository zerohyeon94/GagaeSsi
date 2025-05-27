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
}

struct FixedCostModel {
    var title: String
    var amount: Int
}
