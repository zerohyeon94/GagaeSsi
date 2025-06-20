//
//  HomeModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/18/25.
//

import Foundation

struct DailyBudgetModel {
    var availableAmount: Int
    var date: Date
    var spentAmount: Int
    var carryOverSources: [CarryOverSourceModel]
    var spendingRecords: [SpendingRecordModel]
    
    init(entity: DailyBudget) {
        self.availableAmount = Int(truncating: entity.availableAmount ?? 0)
        self.date = entity.date ?? Date()
        self.spentAmount = Int(truncating: entity.spentAmount ?? 0)
        
        let sources = entity.carryOverSources?.allObjects as? [CarryOverSource] ?? []
        self.carryOverSources = sources.map(CarryOverSourceModel.init)
        
        let records = entity.spendingRecords?.allObjects as? [SpendingRecord] ?? []
        self.spendingRecords = records.map(SpendingRecordModel.init)
    }
}

struct CarryOverSourceModel {
    var id: UUID
    var amount: Int
    var date: Date      // 남은 금액이 발생한 날짜
    var toDate: Date    // 이월된 날짜 (다음날)
    
    init(entity: CarryOverSource) {
        self.id = entity.id ?? UUID()
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
        self.toDate = entity.toDate ?? Date()
    }
}
