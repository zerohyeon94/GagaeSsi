//
//  StatsViewModel.swift
//  GagaeSsi
//

import SwiftUI
import Observation

@Observable
final class StatsViewModel {
    // MARK: - State
    var selectedMonth: Date = Calendar.current.startOfDay(for: Date())
    var categoryTotals: [CategoryTotal] = []
    /// 소비 기록 렌즈(`myShare`) 일별 합계 — 차트 시리즈. "얼마나 썼나"를 보여준다.
    var dailyTotals: [DailyTotal] = []
    /// 예산 렌즈(`budgetOutflow`) 일별 합계 — 예산 판정 전용.
    /// `dailyTotals`와 값이 다를 수 있다: 공용 소비를 내가 대신 낸 날은 예산에서
    /// 더 많이 빠지고(`budgetOutflow` > `myShare` 합), 위시 지갑에서 쓴 소비는
    /// 저금 시점에 이미 예산에서 빠졌으므로 여기서는 제외된다. 두 시리즈가 다른 게 정상이다.
    private(set) var dailyBudgetTotals: [DailyTotal] = []
    /// 소비 기록 렌즈(`myShare`) 월 합계 — 소비 총액 표시용.
    var monthlyTotal: Int = 0
    /// 예산 렌즈(`budgetOutflow`) 월 합계 — 절약액·사용률 판정 전용.
    private(set) var monthlyBudgetTotal: Int = 0
    /// 환급 예정 합계 (이번 달)
    var expectedPaybackTotal: Int = 0
    /// 순 지출 (실지출 − 환급 예정)
    var netSpendingTotal: Int { monthlyTotal - expectedPaybackTotal }
    var prevMonthTotal: Int = 0
    var dailyAverage: Int = 0
    var baseDailyBudget: Int = 0

    /// 이번 달 저축·투자 (소비가 아니라 이동이라 위 소비 합계에는 포함되지 않는다)
    var transferSummary = AssetTransferSummary()

    /// 시간대별 소비 (오전/점심/저녁/심야)
    var timeSlotTotals: [TimeSlotTotal] = []
    /// 시간 정보가 있어 시간대 집계에 포함된 기록 수
    var timedRecordCount: Int = 0
    /// 가장 많이 쓴 시간대 (금액 0이면 nil)
    var peakTimeSlot: TimeSlot? {
        guard let top = timeSlotTotals.max(by: { $0.amount < $1.amount }), top.amount > 0 else { return nil }
        return top.slot
    }

    struct CategoryTotal: Identifiable {
        let id = UUID()
        let category: SpendingCategory
        let amount: Int
        var percentage: Double = 0
    }

    struct DailyTotal: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Int
    }

    // MARK: - Computed
    var currentMonthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: selectedMonth)
    }

    var savingsAmount: Int { monthBudget - monthlyBudgetTotal }
    var savingsRatio: Double {
        guard monthBudget > 0 else { return 0 }
        return max(0, min(1, Double(savingsAmount) / Double(monthBudget)))
    }

    /// 이번 달 총 예산 (하루 기본 예산 × 일수)
    var monthBudget: Int { baseDailyBudget * daysInSelectedMonth }

    /// 예산 사용률 (%)
    var budgetUsagePct: Int {
        guard monthBudget > 0 else { return 0 }
        return Int((Double(monthlyBudgetTotal) / Double(monthBudget) * 100).rounded())
    }

    /// 전월 대비 증감액
    var diffAmount: Int { monthlyTotal - prevMonthTotal }

    /// 이번 달 가장 자주 나타난 캐릭터 상태 (소비가 있는 날 기준)
    /// 예산 판정이므로 `dailyBudgetTotals`(예산 렌즈)를 쓴다 — `myShare` 기준이면 친구
    /// 몫까지 낸 날에도 적게 쓴 것처럼 웃는 얼굴이 나온다.
    var dominantState: CharacterState? {
        let states = dailyBudgetTotals.filter { $0.amount > 0 }
            .map { CharacterState.from(spent: $0.amount, base: baseDailyBudget, coveredFromPool: false) }
        guard !states.isEmpty else { return nil }
        let counts = Dictionary(grouping: states, by: { $0 }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }

    /// 예산 초과한 날 수 — 예산 렌즈(`dailyBudgetTotals`) 기준.
    /// `dailyTotals`(myShare)로 세면 공용 소비를 내가 대신 낸 날 실제로는 예산을
    /// 넘겼는데도 초과일에서 빠진다 (초과분 되짚어보기 화면과 답이 어긋난다).
    var overBudgetDays: Int {
        guard baseDailyBudget > 0 else { return 0 }
        return dailyBudgetTotals.filter { $0.amount > baseDailyBudget }.count
    }

    private var daysInSelectedMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)
        return range?.count ?? 30
    }

    // MARK: - Load
    func load() {
        loadBaseBudget()
        loadCategoryStats()
        loadDailyStats()
        loadMonthlyComparison()
        loadTimeSlotStats()
        loadTransferSummary()
    }

    private func loadTransferSummary() {
        let comps = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
        transferSummary = CoreDataManager.shared.assetTransferSummary(
            year: comps.year ?? 0, month: comps.month ?? 0)
    }

    func goToPrevMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        load()
    }

    func goToNextMonth() {
        let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        if next <= Calendar.current.startOfDay(for: Date()) {
            selectedMonth = next
            load()
        }
    }

    var canGoToNextMonth: Bool {
        let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        return Calendar.current.isDate(next, equalTo: Date(), toGranularity: .month) ||
               next < Calendar.current.startOfDay(for: Date())
    }

    /// 이전 달 이동 가능 여부 (현재로부터 24개월 전까지)
    var isFirstMonth: Bool {
        let earliest = Calendar.current.date(byAdding: .month, value: -24, to: Date()) ?? Date()
        return Calendar.current.isDate(selectedMonth, equalTo: earliest, toGranularity: .month)
            || selectedMonth < earliest
    }

    // MARK: - Private

    private func loadBaseBudget() {
        guard let config = CoreDataManager.shared.fetchBudgetConfig() else { return }
        baseDailyBudget = DailyBudgetCalculator.calculate(from: config, installments: CoreDataManager.shared.fetchInstallments(), for: selectedMonth)
    }

    private func loadCategoryStats() {
        let comps = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
        guard let year = comps.year, let month = comps.month else { return }

        let records = CoreDataManager.shared.fetchSpendingRecords(year: year, month: month)
        monthlyTotal = records.myShareTotal
        monthlyBudgetTotal = records.budgetOutflow
        expectedPaybackTotal = records.reduce(0) { $0 + $1.expectedPayback }
        dailyAverage = records.isEmpty ? 0 : monthlyTotal / max(1, Calendar.current.component(.day, from: Date()))

        var dict: [SpendingCategory: Int] = [:]
        for record in records {
            dict[record.category, default: 0] += record.myShare
        }

        var totals = dict.map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }

        let total = totals.reduce(0) { $0 + $1.amount }
        if total > 0 {
            totals = totals.map {
                var t = $0
                t.percentage = Double(t.amount) / Double(total)
                return t
            }
        }
        categoryTotals = totals
    }

    private func loadDailyStats() {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: selectedMonth)
        guard let year = comps.year, let month = comps.month,
              let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else { return }

        let records = CoreDataManager.shared.fetchSpendingRecords(from: startDate, to: endDate)
        let daysCount = calendar.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30

        // 같은 달의 기록을 하루씩 필터링하는 패스는 한 번만 돈다 — 소비 렌즈와 예산 렌즈
        // 두 시리즈를 같은 필터 결과에서 함께 뽑는다.
        var myShareSeries: [DailyTotal] = []
        var budgetSeries: [DailyTotal] = []
        myShareSeries.reserveCapacity(daysCount)
        budgetSeries.reserveCapacity(daysCount)
        for offset in 0..<daysCount {
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let dayRecords = records.filter { $0.date >= startOfDay && $0.date < endOfDay }
            myShareSeries.append(DailyTotal(date: startOfDay, amount: dayRecords.myShareTotal))
            budgetSeries.append(DailyTotal(date: startOfDay, amount: dayRecords.budgetOutflow))
        }
        dailyTotals = myShareSeries
        dailyBudgetTotals = budgetSeries
    }

    private func loadTimeSlotStats() {
        let comps = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
        guard let year = comps.year, let month = comps.month else { return }
        let records = CoreDataManager.shared.fetchSpendingRecords(year: year, month: month)
        let result = TimeSlot.totals(from: records)
        timeSlotTotals = result.totals
        timedRecordCount = result.timedCount
    }

    private func loadMonthlyComparison() {
        let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        let comps = Calendar.current.dateComponents([.year, .month], from: prevMonth)
        guard let year = comps.year, let month = comps.month else { return }
        let records = CoreDataManager.shared.fetchSpendingRecords(year: year, month: month)
        prevMonthTotal = records.reduce(0) { $0 + $1.myShare }
    }
}
