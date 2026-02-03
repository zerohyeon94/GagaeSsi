//
//  SpendViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import SwiftUI
import Observation

@Observable
final class SpendViewModel {
    var model: SpendingRecordModel
    var spendingRecords: [SpendingRecordModel] = []
    var tempTitle: String = ""
    var tempAmount: Int = 0
    var tempAmountText: String = ""
    var tempDate: Date = Date()
    
    var showSuccessAlert = false
    var showErrorAlert = false
    var errorMessage = ""
    
    var isValid: Bool {
        !tempTitle.isEmpty && tempAmount > 0
    }
    
    init() {
        self.model = SpendingRecordModel(id: UUID(), title: "", amount: 0, date: Date())
    }
    
    func fetchSpending(on date: Date) {
        spendingRecords = CoreDataManager.shared.fetchSpendingRecords(date: date)
    }
    
    func updateAmountFromText(_ text: String) {
        if let result = FormatterUtils.formatCurrencyInput(text) {
            tempAmount = result.plainNumber
            tempAmountText = result.formatted
        }
    }
    
    func saveSpending(completion: @escaping (Bool) -> Void) {
        guard isValid else {
            errorMessage = "제목과 금액을 입력해주세요"
            showErrorAlert = true
            completion(false)
            return
        }
        
        model.title = tempTitle
        model.amount = tempAmount
        model.date = Calendar.current.startOfDay(for: tempDate)
        
        let success = CoreDataManager.shared.createSpendingRecord(model)
        
        if success {
            AppEventBus.shared.notifySpendingAdded()
            showSuccessAlert = true
            fetchSpending(on: model.date)
        } else {
            errorMessage = "저장에 실패했습니다"
            showErrorAlert = true
        }
        completion(success)
    }
    
    func clearForm() {
        tempTitle = ""
        tempAmount = 0
        tempAmountText = ""
        tempDate = Date()
    }
}
