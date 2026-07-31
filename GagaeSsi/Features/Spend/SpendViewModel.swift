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
    var tempAmountText: String = ""
    var tempDate: Date = Date()
    var tempCategory: SpendingCategory = .other
    /// 환급/페이백 예정 입력
    var tempHasPayback: Bool = false
    var tempExpectedPayback: Int = 0
    var tempExpectedPaybackText: String = ""
    /// 편집 시 기존 환급 수령 여부 보존용
    private var editingPaybackReceived: Bool = false

    /// 편집 중인 지출 기록 id (nil이면 추가 모드)
    var editingRecordId: UUID?

    /// 자동완성 추천 (기존 소비 기록 파생)
    var allSuggestions: [SpendingSuggestion] = []
    /// 현재 입력(tempTitle) 기준으로 필터된 추천
    var titleSuggestions: [SpendingSuggestion] {
        SpendingSuggestionEngine.filter(allSuggestions, query: tempTitle)
    }
    
    // MARK: - State
    var isLoading: Bool = false
    var showSuccessAlert: Bool = false
    var showErrorAlert: Bool = false
    var errorMessage: String = ""
    
    // MARK: - Computed
    /// 금액만 있으면 저장 가능 (내용은 선택, 비우면 카테고리명 사용)
    var isValid: Bool {
        return tempAmount > 0
    }

    /// 편집 모드 여부
    var isEditing: Bool {
        editingRecordId != nil
    }
    
    // MARK: - Init
    init() {
        self.model = SpendingRecordModel(id: UUID(), title: "", amount: 0, date: Date())
    }
    
    // MARK: - Public Methods
    func fetchSpending(on date: Date) {
        spendingRecords = CoreDataManager.shared.fetchSpendingRecords(date: date)
    }

    /// 자동완성 추천 로드 (화면 진입·저장 후)
    func loadSuggestions() {
        allSuggestions = CoreDataManager.shared.fetchSpendingSuggestions()
    }

    /// 추천 항목 적용: 항목명 + 최근 카테고리 (금액은 자동 입력하지 않음)
    func applySuggestion(_ s: SpendingSuggestion) {
        tempTitle = s.title
        tempCategory = s.category
    }
    
    func updateAmountFromText(_ text: String) {
        if let result = FormatterUtils.formatCurrencyInput(text) {
            tempAmount = result.plainNumber
            tempAmountText = result.formatted
        }
    }
    
    func saveSpending(eventBus: AppEventBus, completion: @escaping (Bool) -> Void) {
        guard tempAmount > 0 else {
            errorMessage = "금액을 입력해주세요"
            showErrorAlert = true
            completion(false)
            return
        }

        // 모델 업데이트 (내용 비우면 카테고리명 사용)
        model.title = tempTitle.isEmpty ? tempCategory.rawValue : tempTitle
        model.amount = tempAmount
        // 시간대 리포트를 위해 실제 시각을 보존한다. DatePicker가 date-only라
        // tempDate는 시각 성분(생성=현재 시각, 편집=원래 시각)을 유지한다.
        model.date = tempDate
        model.category = tempCategory
        model.expectedPayback = tempHasPayback ? tempExpectedPayback : 0
        model.paybackReceived = (editingRecordId != nil) ? editingPaybackReceived : false

        let success: Bool
        if let editingId = editingRecordId {
            // 편집 모드: 기존 기록 수정
            model.id = editingId
            success = CoreDataManager.shared.updateSpendingRecord(model)
        } else {
            // 추가 모드: 신규 기록 생성
            success = CoreDataManager.shared.createSpendingRecord(model)
        }

        guard success else {
            errorMessage = isEditing ? "지출 내역 수정에 실패했습니다" : "지출 내역 저장에 실패했습니다"
            showErrorAlert = true
            completion(false)
            return
        }

        editingRecordId = nil
        fetchSpending(on: model.date)
        eventBus.notifySpendingAdded()
        showSuccessAlert = true
        completion(true)
    }

    /// 편집 시작: 선택한 기록 값을 입력 폼에 채움
    func beginEdit(_ record: SpendingRecordModel) {
        editingRecordId = record.id
        tempTitle = record.title
        tempAmount = record.amount
        tempAmountText = FormatterUtils.inputAmountString(from: record.amount)
        tempDate = record.date
        tempCategory = record.category
        tempExpectedPayback = record.expectedPayback
        tempExpectedPaybackText = record.expectedPayback > 0 ? FormatterUtils.inputAmountString(from: record.expectedPayback) : ""
        tempHasPayback = record.expectedPayback > 0
        editingPaybackReceived = record.paybackReceived
    }

    /// 저장 직후, 오늘 예산이 음수이고 모아둔 이월금이 있으면 충당 가능액을 반환한다.
    /// - Returns: (부족액=충당 제안 금액, 풀 잔액) 또는 nil
    func shortfallCoverage() -> (cover: Int, pool: Int)? {
        guard let today = CoreDataManager.shared.fetchOrCreateTodayDailyBudget() else { return nil }
        let available = today.todayAvailable
        guard available < 0 else { return nil }
        let pool = CoreDataManager.shared.carryOverPoolBalance()
        guard pool > 0 else { return nil }
        return (min(-available, pool), pool)
    }

    /// 모아둔 이월금에서 부족액을 충당한다.
    func coverShortfall(amount: Int, eventBus: AppEventBus) {
        if CoreDataManager.shared.withdrawFromPool(amount: amount) {
            eventBus.notifySpendingAdded()   // 오늘 예산 크레딧 → 홈 갱신
        }
    }

    /// 환급/페이백을 실제로 받음 처리
    func receivePayback(recordId: UUID, eventBus: AppEventBus) {
        if CoreDataManager.shared.receivePayback(recordId: recordId) {
            fetchSpending(on: Calendar.current.startOfDay(for: Date()))
            eventBus.notifySpendingAdded()   // 오늘 예산 크레딧 → 홈 갱신
        }
    }

    /// 편집 취소
    func cancelEdit() {
        editingRecordId = nil
        clearForm()
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
        tempCategory = .other
        tempHasPayback = false
        tempExpectedPayback = 0
        tempExpectedPaybackText = ""
        editingPaybackReceived = false
        editingRecordId = nil
        model = SpendingRecordModel(id: UUID(), title: "", amount: 0, date: Date())
    }
}
