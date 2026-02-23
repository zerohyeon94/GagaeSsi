//
//  SpendViewModel.swift
//  GagaeSsi
//
//  소비 기록 ViewModel (@Observable 버전)
//

import SwiftUI
import Observation

@Observable
final class SpendViewModel {
    // MARK: - Properties
    var model: SpendingRecordModel
    var spendingRecords: [SpendingRecordModel] = []
    
    /// 실시간 유효성 체크용 임시 변수 (화면과 연결)
    var tempTitle: String = ""
    var tempAmount: Int = 0
    var tempAmountText: String = ""  // 포맷된 금액 텍스트
    var tempDate: Date = Date()
    
    // MARK: - State
    var isLoading: Bool = false
    var showSuccessAlert: Bool = false
    var showErrorAlert: Bool = false
    var errorMessage: String = ""
    
    // MARK: - Computed
    var isValid: Bool {
        return !tempTitle.isEmpty && tempAmount > 0
    }
    
    // MARK: - Init
    init() {
        self.model = SpendingRecordModel(id: UUID(), title: "", amount: 0, date: Date())
    }
    
    // MARK: - Public Methods
    func fetchSpending(on date: Date) {
        spendingRecords = CoreDataManager.shared.fetchSpendingRecords(date: date)
    }
    
    func updateAmountFromText(_ text: String) {
        if let result = FormatterUtils.formatCurrencyInput(text) {
            tempAmount = result.plainNumber
            tempAmountText = result.formatted
        }
    }
    
    func saveSpending(eventBus: AppEventBus, completion: @escaping (Bool) -> Void) {
        guard !tempTitle.isEmpty, tempAmount > 0 else {
            errorMessage = "제목과 금액을 입력해주세요"
            showErrorAlert = true
            completion(false)
            return
        }
        
        // 모델 업데이트
        model.title = tempTitle
        model.amount = tempAmount
        model.date = Calendar.current.startOfDay(for: tempDate)
        
        let success = CoreDataManager.shared.createSpendingRecord(model)
        guard success else {
            errorMessage = "지출 내역 저장에 실패했습니다"
            showErrorAlert = true
            completion(false)
            return
        }

        fetchSpending(on: model.date)
        eventBus.notifySpendingAdded()
        showSuccessAlert = true
        completion(true)
    }
    
    func deleteSpending(id: UUID, eventBus: AppEventBus) {
        let success = CoreDataManager.shared.deleteSpendingRecord(id: id)
        if success {
            eventBus.notifySpendingAdded()
        }
    }

    func clearForm() {
        tempTitle = ""
        tempAmount = 0
        tempAmountText = ""
        tempDate = Date()
        model = SpendingRecordModel(id: UUID(), title: "", amount: 0, date: Date())
    }
}
