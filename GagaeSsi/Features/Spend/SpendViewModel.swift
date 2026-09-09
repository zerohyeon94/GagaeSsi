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

    /// 모아둔 위시 지갑에서 쓸지 — 선택하면 그날 예산에서 빠지지 않는다
    var tempWishItemId: UUID?
    /// 잔액이 남아 고를 수 있는 지갑들
    var spendableWishes: [WishItemModel] = []

    var selectedWish: WishItemModel? {
        spendableWishes.first { $0.id == tempWishItemId }
    }
    /// 고른 지갑으로 이 소비의 부담액을 감당할 수 있는지 (친구가 낸 소비는 내 몫만)
    var wishCoversAmount: Bool {
        guard let wishId = tempWishItemId else { return true }
        return previewRecord.budgetAmount <= CoreDataManager.shared.wishSpendableLimit(for: wishId,
                                                                                      excluding: editingRecordId)
    }
    /// 고른 지갑에서 이 소비에 쓸 수 있는 금액 (안내 문구용)
    var selectedWishLimit: Int {
        guard let wishId = tempWishItemId else { return 0 }
        return CoreDataManager.shared.wishSpendableLimit(for: wishId, excluding: editingRecordId)
    }

    // MARK: 여행
    /// 이 소비를 묶을 여행 (nil이면 평소 소비)
    var tempTripId: UUID?
    /// 나누는 인원 (1 = 내 개인 소비)
    var tempParticipants: Int = 1
    /// 내가 냈는지
    var tempPaidByMe: Bool = true
    /// 고를 수 있는 여행들 — 진행 중 + (편집 중이면) 그 기록이 묶인 정산 완료 여행
    var activeTrips: [TripModel] = []
    /// 사용자가 "여행 아님"을 직접 골랐으면 날짜를 바꿔도 다시 자동 선택하지 않는다
    private var tripAutoSelectDismissed = false
    /// 사용자가 지갑을 직접 골랐으면 자동 선택이 더는 손대지 않는다
    private var walletManuallyPicked = false

    var selectedTrip: TripModel? {
        activeTrips.first { $0.id == tempTripId }
    }
    /// 정산 완료 여행의 소비는 여행·인원·결제자를 못 바꾼다
    var isTripLocked: Bool { selectedTrip?.isSettled == true }
    /// 공용 소비면 환급 필드를 숨긴다 — 정산과 겹치면 이중 반영
    var isSharedSpending: Bool { tempTripId != nil && tempParticipants > 1 }

    /// 지금 입력값으로 만든 임시 기록 — 내 몫·부담액 미리보기용
    var previewRecord: SpendingRecordModel {
        SpendingRecordModel(title: tempTitle, amount: tempAmount, date: tempDate,
                            tripId: tempTripId,
                            participants: tempTripId == nil ? 1 : tempParticipants,
                            paidByMe: tempTripId == nil ? true : tempPaidByMe)
    }

    /// 인원·결제자에 따라 이 소비가 어떻게 잡히는지 한 줄
    var tripPreviewText: String {
        let p = previewRecord
        guard p.isShared, p.amount > 0 else { return "" }
        let share = FormatterUtils.currencyString(from: p.myShare)
        if p.paidByMe {
            return "내 몫 \(share) · 정산 때 \(FormatterUtils.currencyString(from: p.receivable)) 돌아와요"
        }
        return "내 몫 \(share)만 오늘 예산에서 빠져요"
    }

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
    /// 금액만 있으면 저장 가능 (내용은 선택, 비우면 카테고리명 사용).
    /// 지갑에서 쓰기로 했다면 잔액을 넘지 않아야 한다.
    var isValid: Bool {
        return tempAmount > 0 && wishCoversAmount
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
        revalidateAutoWallet()
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
        model.tripId = tempTripId
        model.participants = tempTripId == nil ? 1 : tempParticipants
        model.paidByMe = tempTripId == nil ? true : tempPaidByMe
        // 공용 소비는 정산이 환급 역할을 하므로 환급 필드를 비운다
        if model.isShared { model.expectedPayback = 0 }

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

        // 지갑 연결은 저장 뒤에 붙인다 — 잔액 검사가 데이터 계층 한 곳에만 있게 된다
        if let wishId = tempWishItemId {
            CoreDataManager.shared.linkSpendingToWish(recordId: model.id, wishItemId: wishId)
        } else {
            CoreDataManager.shared.unlinkSpendingFromWish(recordId: model.id)
        }

        editingRecordId = nil
        fetchSpending(on: model.date)
        loadSpendableWishes()      // 지갑 잔액이 줄었으므로 다시 읽는다
        eventBus.notifySpendingAdded()
        showSuccessAlert = true
        completion(true)
    }

    /// 편집 시작: 선택한 기록 값을 입력 폼에 채움
    func beginEdit(_ record: SpendingRecordModel) {
        // 폼이 다루지 않는 필드(인원·결제자·여행 연결 등)가 저장 때 기본값으로 덮이지 않도록
        // 편집 대상 기록을 그대로 싣고 시작한다
        model = record
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
        tempWishItemId = record.wishItemId
        tempTripId = record.tripId
        tempParticipants = record.participants
        tempPaidByMe = record.paidByMe
        walletManuallyPicked = false
        loadSpendableWishes()
        loadActiveTrips()
    }

    /// 잔액이 남은 지갑 목록을 불러온다 (화면 진입·편집 시작 시)
    func loadSpendableWishes() {
        var wishes = CoreDataManager.shared.fetchSpendableWishItems()
        // 편집 중인 기록이 붙어 있던 지갑은 잔액이 0이 됐어도 후보로 남겨야 한다
        if let id = tempWishItemId, !wishes.contains(where: { $0.id == id }),
           let linked = CoreDataManager.shared.fetchWishItems().first(where: { $0.id == id }) {
            wishes.append(linked)
        }
        spendableWishes = wishes
    }

    /// 고를 수 있는 여행을 불러온다 (화면 진입·편집 시작·저장 후)
    func loadActiveTrips() {
        var trips = CoreDataManager.shared.fetchActiveTrips()
        // 편집 중인 기록이 정산 완료 여행에 묶여 있으면 그 여행도 보여야 한다 (잠긴 채로)
        if let id = tempTripId, !trips.contains(where: { $0.id == id }),
           let linked = CoreDataManager.shared.fetchTrip(id: id) {
            trips.append(linked)
        }
        activeTrips = trips
        autoSelectTrip()
    }

    /// 소비 날짜가 진행 중 여행 하나의 기간 안이면 그 여행을 미리 고른다
    func autoSelectTrip() {
        guard !isEditing, tempTripId == nil, !tripAutoSelectDismissed,
              let trip = CoreDataManager.shared.trip(containing: tempDate) else { return }
        selectTrip(trip.id)
    }

    /// 여행을 고르거나(id) 푼다(nil). 고르면 인원 기본값과 지갑을 채운다.
    func selectTrip(_ id: UUID?) {
        tempTripId = id
        if let trip = activeTrips.first(where: { $0.id == id }) {
            tempParticipants = max(1, trip.defaultParticipants)
            tempPaidByMe = true
            autoSelectWallet(for: trip)
        } else {
            tripAutoSelectDismissed = true
            tempParticipants = 1
            tempPaidByMe = true
            if !walletManuallyPicked { tempWishItemId = nil }
        }
    }

    /// 사용자가 지갑을 직접 고름 — 이후 자동 선택이 손대지 않는다
    func pickWallet(_ id: UUID?) {
        tempWishItemId = id
        walletManuallyPicked = true
    }

    /// 여행에 지갑이 있고 잔액이 내 부담액을 덮으면 지갑을 미리 고른다. 부족하면 예산에서.
    private func autoSelectWallet(for trip: TripModel) {
        guard !walletManuallyPicked, let wishId = trip.wishItemId, tempWishItemId == nil else { return }
        let limit = CoreDataManager.shared.wishSpendableLimit(for: wishId, excluding: editingRecordId)
        if previewRecord.budgetAmount <= limit { tempWishItemId = wishId }
    }

    /// 금액·인원·결제자가 바뀐 뒤 자동 선택을 다시 판정한다.
    /// 잔액을 넘기면 조용히 예산으로 돌리고, 다시 덮을 수 있게 되면 지갑으로 되돌린다.
    /// 사용자가 직접 고른 지갑은 건드리지 않는다.
    func revalidateAutoWallet() {
        guard !walletManuallyPicked, let trip = selectedTrip, trip.wishItemId != nil else { return }
        if tempWishItemId != nil, !wishCoversAmount {
            tempWishItemId = nil
        } else if tempWishItemId == nil {
            autoSelectWallet(for: trip)
        }
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
        if CoreDataManager.shared.withdrawFromPool(amount: amount, reason: .shortfall) {
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
        tempWishItemId = nil
        tempTripId = nil
        tempParticipants = 1
        tempPaidByMe = true
        tripAutoSelectDismissed = false
        walletManuallyPicked = false
        editingRecordId = nil
        model = SpendingRecordModel(id: UUID(), title: "", amount: 0, date: Date())
        autoSelectTrip()
    }
}
