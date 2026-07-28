//
//  HomeViewModel.swift
//  GagaeSsi
//
//  홈 화면 ViewModel (@Observable 버전)
//

import SwiftUI
import Observation

@Observable
final class HomeViewModel {
    // MARK: - Output State
    var todayAvailableAmount: Int = 0
    var baseBudget: Int = 0
    var carryOverAmount: Int = 0
    var spentAmount: Int = 0
    /// 오늘 저금 차감액 (활성 위시)
    var wishSavingAmount: Int = 0
    /// 현재 활성 위시 아이템 (없으면 nil)
    var activeWish: WishItemModel?
    
    // MARK: - Loading State
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Public Methods
    func fetchTodayBudget() {
        isLoading = true
        errorMessage = nil

        // 마지막 기록일 ~ 오늘까지 누락된 날의 이월금 자동 처리
        CoreDataManager.shared.processDailyBudgets(upTo: Date())

        if let model = CoreDataManager.shared.fetchOrCreateTodayDailyBudget() {
            applyDailyBudgetModel(model)
        } else {
            errorMessage = "예산 설정이 필요합니다"
        }
        
        isLoading = false
    }
    
    func recalculateTodayBudget() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let config = CoreDataManager.shared.fetchBudgetConfig() else {
            DebugLogger.log("❌ BudgetConfig 없음 → Budget 설정 필요")
            errorMessage = "예산 설정이 필요합니다"
            return
        }
        let baseAmount = DailyBudgetCalculator.calculate(from: config, for: today)

        if let model = CoreDataManager.shared.fetchOrCreateTodayDailyBudget() {
            // 기존 carryOverSources, spendingRecords 유지
            let updatedModel = DailyBudgetModel(
                availableAmount: baseAmount,
                date: model.date,
                carryOverSources: model.carryOverSources,
                spendingRecords: model.spendingRecords
            )
            let success = CoreDataManager.shared.updateDailyBudget(updatedModel)
            if success {
                applyDailyBudgetModel(updatedModel)
            } else {
                DebugLogger.log("❌ DailyBudget 업데이트 실패")
            }
        }
    }
    
    // MARK: - Private Methods
    private func applyDailyBudgetModel(_ model: DailyBudgetModel) {
        let base = model.availableAmount
        let spent = model.spendingRecords.map { $0.amount }.reduce(0, +)
        let carry = model.carryOverSources.map { $0.amount }.reduce(0, +)
        let total = model.todayAvailable

        baseBudget = base
        carryOverAmount = carry
        spentAmount = spent
        todayAvailableAmount = total
        wishSavingAmount = model.wishSavingAmount
        activeWish = CoreDataManager.shared.fetchActiveWishItem()
    }
}
