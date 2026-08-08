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
    /// 지출일이 지났는데 이번 달 아직 확정 안 한 변동 고정비 (홈 프롬프트)
    var unconfirmedVariableCosts: [FixedCostModel] = []
    /// 이월 방식 (전액 이월 / 모아둔 이월금 분리)
    var carryOverMode: CarryOverMode = .full
    /// 모아둔 이월금 풀 잔액 (분리 모드)
    var carryOverPoolBalance: Int = 0
    /// 오늘 모아둔 이월금에서 가져온 금액 (인출·부족액 충당)
    var todayPoolWithdrawn: Int = 0
    /// 진행 중인 초과 소비 부채 (없으면 nil)
    var activeDebt: SpendingDebtModel?
    /// 오늘 초과분 상환으로 차감된 금액
    var todayDebtRepayment: Int = 0
    /// 최근 7일 하루 평균 소비 (상환 속도 점검용)
    var recentAverageSpending: Int = 0
    /// 오늘 모아둔 이월금으로 갚은 금액
    var todayPoolRepayment: Int = 0
    /// 모아둔 이월금으로 갚을 수 있는 최대 금액 (풀 잔액과 남은 부채 중 작은 쪽)
    var maxRepayableFromPool: Int = 0
    /// 급여일에 "모아둔 이월금으로 먼저 갚을까요?"를 물어야 하는 상태
    var needsPaydayAbsorptionPrompt: Bool = false

    /// 모아둔 이월금으로 갚기 버튼을 노출할지
    var canRepayDebtFromPool: Bool { maxRepayableFromPool > 0 }

    /// 최근 씀씀이로는 부채가 줄지 않는 상태인지
    var isDebtOffTrack: Bool {
        guard let debt = activeDebt, debt.isActive, debt.isPlanned else { return false }
        return DebtRepaymentPlan.isOffTrack(recentAverageSpending: recentAverageSpending,
                                            dailyBudget: baseBudget,
                                            ratePercent: debt.repayRatePercent)
    }

    /// 부채를 줄이려면 하루에 더 줄여야 하는 금액
    var debtDailyCutNeeded: Int {
        guard let debt = activeDebt else { return 0 }
        return DebtRepaymentPlan.dailyCutNeeded(recentAverageSpending: recentAverageSpending,
                                                dailyBudget: baseBudget,
                                                ratePercent: debt.repayRatePercent)
    }

    /// 계획 미확정 부채가 있어 오늘 설정 팝업을 띄워야 하는지
    var needsDebtPlanPrompt: Bool {
        activeDebt?.needsPlanPrompt() ?? false
    }

    /// 화면에 표시할 이월 금액. 초과분 상환은 `CarryOverSource`(음수)로 저장되지만
    /// 예산 현황에서는 별도 행으로 보여주므로 이월 금액에서 다시 빼둔다.
    var displayCarryOverAmount: Int { carryOverAmount + todayDebtRepayment }

    /// 캐릭터 소비 상태 (하루 예산 사용률 기반)
    var characterState: CharacterState {
        CharacterState.from(spent: spentAmount, base: baseBudget,
                            coveredFromPool: todayPoolWithdrawn > 0,
                            repayingDebt: todayDebtRepayment > 0,
                            todayAvailable: todayAvailableAmount)
    }
    
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

        unconfirmedVariableCosts = CoreDataManager.shared.unconfirmedVariableCosts()
        carryOverMode = CoreDataManager.shared.fetchBudgetConfig()?.carryOverMode ?? .full
        carryOverPoolBalance = CoreDataManager.shared.carryOverPoolBalance()
        todayPoolWithdrawn = CoreDataManager.shared.todayPoolWithdrawnAmount()
        activeDebt = CoreDataManager.shared.fetchActiveDebt()
        todayDebtRepayment = CoreDataManager.shared.todayDebtRepaymentAmount()
        recentAverageSpending = CoreDataManager.shared.recentAverageDailySpending(days: 7)
        todayPoolRepayment = CoreDataManager.shared.todayPoolRepaymentAmount()
        maxRepayableFromPool = CoreDataManager.shared.maxRepayableFromPool()
        needsPaydayAbsorptionPrompt = CoreDataManager.shared.needsPaydayAbsorptionPrompt()
        isLoading = false
    }

    /// 모아둔 이월금으로 초과분을 갚는다.
    @discardableResult
    func repayDebtFromPool(amount: Int) -> Bool {
        let ok = CoreDataManager.shared.repayDebtFromPool(amount: amount)
        if ok { fetchTodayBudget() }
        return ok
    }

    /// 급여일 프롬프트 응답 (모아둔 이월금을 먼저 쓸지)
    func resolvePaydayAbsorption(usingPool: Bool) {
        CoreDataManager.shared.resolvePaydayAbsorption(usingPool: usingPool)
        fetchTodayBudget()
    }

    /// 상환 계획 확정 (팝업 "이 계획으로 갚기")
    func confirmDebtPlan(ratePercent: Int) {
        CoreDataManager.shared.confirmDebtPlan(ratePercent: ratePercent)
        fetchTodayBudget()
    }

    /// 상환 계획 설정을 오늘 미룸 (팝업 "나중에")
    func deferDebtPlan() {
        CoreDataManager.shared.deferDebtPlan()
        fetchTodayBudget()
    }

    /// 모아둔 이월금에서 오늘 예산으로 꺼내 쓴다.
    @discardableResult
    func withdrawFromPool(amount: Int) -> Bool {
        let ok = CoreDataManager.shared.withdrawFromPool(amount: amount)
        if ok { fetchTodayBudget() }
        return ok
    }

    func recalculateTodayBudget() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let config = CoreDataManager.shared.fetchBudgetConfig() else {
            DebugLogger.log("❌ BudgetConfig 없음 → Budget 설정 필요")
            errorMessage = "예산 설정이 필요합니다"
            return
        }
        let baseAmount = DailyBudgetCalculator.calculate(from: config, installments: CoreDataManager.shared.fetchInstallments(), for: today)

        if let model = CoreDataManager.shared.fetchOrCreateTodayDailyBudget() {
            // 기존 carryOverSources, spendingRecords 유지
            let updatedModel = DailyBudgetModel(
                availableAmount: baseAmount,
                date: model.date,
                carryOverSources: model.carryOverSources,
                spendingRecords: model.spendingRecords,
                wishSavingAmount: model.wishSavingAmount   // 위시 저금 차감 유지
            )
            let success = CoreDataManager.shared.updateDailyBudget(updatedModel)
            if success {
                applyDailyBudgetModel(updatedModel)
            } else {
                DebugLogger.log("❌ DailyBudget 업데이트 실패")
            }
        }
        unconfirmedVariableCosts = CoreDataManager.shared.unconfirmedVariableCosts()
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
