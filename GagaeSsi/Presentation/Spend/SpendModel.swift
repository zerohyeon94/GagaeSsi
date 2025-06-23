//
//  SpendModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation

struct SpendingRecordModel {
    var id: UUID
    var title: String
    var amount: Int
    var date: Date
    
    init(id: UUID, title: String, amount: Int, date: Date) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
    }
    
    init(entity: SpendingRecord) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
    }
}
