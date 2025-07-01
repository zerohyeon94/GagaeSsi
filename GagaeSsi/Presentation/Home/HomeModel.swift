//
//  HomeModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/18/25.
//

import Foundation

// MARK: - 날짜별 예산 모델
struct DailyBudgetModel {
    var availableAmount: Int
    var date: Date
    var carryOverSources: [CarryOverSourceModel]
    var spendingRecords: [SpendingRecordModel]
    
    // 실제 오늘 쓸 수 있는 총 금액
    // MARK: - Computed
    var todayAvailable: Int {
        let carry = carryOverSources.map { $0.amount }.reduce(0, +)
        let spent = spendingRecords.map { $0.amount }.reduce(0, +)
        return availableAmount + carry - spent
    }
    
    // MARK: - Initializer
    /// 일반 생성자
    init(availableAmount: Int, date: Date, carryOverSources: [CarryOverSourceModel], spendingRecords: [SpendingRecordModel]) {
        self.availableAmount = availableAmount
        self.date = date
        self.carryOverSources = carryOverSources
        self.spendingRecords = spendingRecords
    }
    
    /// CoreData Entity -> Model 변환 생성자
    init(entity: DailyBudget) {
        self.availableAmount = Int(truncating: entity.availableAmount ?? 0)
        self.date = entity.date ?? Date()
        
        let sources = entity.carryOverSources?.allObjects as? [CarryOverSource] ?? []
        self.carryOverSources = sources.map(CarryOverSourceModel.init)
        
        let records = entity.spendingRecords?.allObjects as? [SpendingRecord] ?? []
        self.spendingRecords = records.map(SpendingRecordModel.init)
    }
}

// MARK: - 이월 금액 모델
struct CarryOverSourceModel {
    var id: UUID
    var amount: Int
    var date: Date      // 남은 금액이 발생한 날짜
    var toDate: Date    // 이월된 날짜 (다음날)
    
    init(id: UUID, amount: Int, date: Date, toDate: Date) {
        self.id = id
        self.amount = amount
        self.date = date
        self.toDate = toDate
    }
    
    init(entity: CarryOverSource) {
        self.id = entity.id ?? UUID()
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
        self.toDate = entity.toDate ?? Date()
    }
}
