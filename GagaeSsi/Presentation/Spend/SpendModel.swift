//
//  SpendModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation

// MARK: - 소비 기록 모델
struct SpendingRecordModel: Identifiable {
    var id: UUID
    var title: String
    var amount: Int
    var date: Date
    
    // MARK: - Initializer
    /// 일반 생성자
    init(id: UUID, title: String, amount: Int, date: Date) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
    }
    
    /// CoreData Entity -> Model 변환 생성자
    init(entity: SpendingRecord) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
    }
}
