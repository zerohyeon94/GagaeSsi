//
//  HistoryViewModel.swift
//  GagaeSsi
//
//  소비 내역 (월간 캘린더 + 날짜별 목록)
//

import SwiftUI
import Observation

@Observable
final class HistoryViewModel {
    var selectedMonth: Date = Calendar.current.startOfDay(for: Date())
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    /// 날짜(startOfDay) -> 그날 총소비
    private(set) var dayTotals: [Date: Int] = [:]
    private(set) var monthTotal: Int = 0
    private(set) var selectedRecords: [SpendingRecordModel] = []
    /// 그 달 하루 기본 예산 (기록이 없는 날의 대체 기준)
    private(set) var baseDailyBudget: Int = 0
    /// 날짜(startOfDay) -> 그날 실제 잔액. 이월까지 반영된 값이라
    /// "기본 예산만 보고 판단"하던 기존 방식보다 정확하다.
    private(set) var dayBalances: [Date: Int] = [:]
    /// 날짜(startOfDay) -> 그날 실제로 쓸 수 있었던 금액 (기본 예산 + 이월)
    private(set) var dayAvailable: [Date: Int] = [:]

    /// 선택한 날의 초과 금액 (0이면 초과 안 함)
    var selectedOverspentAmount: Int {
        max(0, -(dayBalances[cal.startOfDay(for: selectedDate)] ?? 0))
    }
    /// 선택한 날 실제로 쓸 수 있었던 금액
    var selectedAvailable: Int {
        dayAvailable[cal.startOfDay(for: selectedDate)] ?? baseDailyBudget
    }

    private let cal = Calendar.current

    var monthLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월"
        return f.string(from: selectedMonth)
    }
    var selectedDateLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일 (E)"
        return f.string(from: selectedDate)
    }

    /// 다음 달로 이동 가능 여부 (미래 달 제한)
    var canGoNext: Bool {
        guard let next = cal.date(byAdding: .month, value: 1, to: selectedMonth) else { return false }
        return !cal.isDate(next, equalTo: Date(), toGranularity: .month) ? next < Date() : true
    }

    // MARK: - Load
    func load() {
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        guard let year = comps.year, let month = comps.month else { return }

        if let config = CoreDataManager.shared.fetchBudgetConfig() {
            baseDailyBudget = DailyBudgetCalculator.calculate(
                from: config, installments: CoreDataManager.shared.fetchInstallments(), for: selectedMonth)
        }

        let records = CoreDataManager.shared.fetchSpendingRecords(year: year, month: month)
        monthTotal = records.reduce(0) { $0 + $1.amount }
        var totals: [Date: Int] = [:]
        for r in records {
            let d = cal.startOfDay(for: r.date)
            totals[d, default: 0] += r.amount
        }
        dayTotals = totals
        loadDayBalances(year: year, month: month)
        loadSelected()
    }

    /// 그 달 일자별 잔액·가용액을 읽어둔다 (캘린더 상태 색과 초과 배지 기준)
    private func loadDayBalances(year: Int, month: Int) {
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let next = cal.date(byAdding: .month, value: 1, to: first) else { return }
        let budgets = CoreDataManager.shared.fetchDailyBudgetModels(from: first, to: next)

        var balances: [Date: Int] = [:]
        var available: [Date: Int] = [:]
        for budget in budgets {
            let day = cal.startOfDay(for: budget.date)
            balances[day] = budget.todayAvailable
            available[day] = budget.availableAmount + budget.carryOverSources.map(\.amount).reduce(0, +)
        }
        dayBalances = balances
        dayAvailable = available
    }

    func loadSelected() {
        selectedRecords = CoreDataManager.shared.fetchSpendingRecords(date: selectedDate)
            .sorted { $0.date > $1.date }
    }

    // MARK: - 캘린더
    /// 해당 월의 날짜들 (앞쪽 요일 정렬용 nil 포함)
    func monthGrid() -> [Date?] {
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth)),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let leading = cal.component(.weekday, from: first) - 1   // 일요일=0 칸
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            cells.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        return cells
    }

    func total(on date: Date) -> Int { dayTotals[cal.startOfDay(for: date)] ?? 0 }
    func hasRecord(on date: Date) -> Bool { (dayTotals[cal.startOfDay(for: date)] ?? 0) != 0 }
    func isSelected(_ date: Date) -> Bool { cal.isDate(date, inSameDayAs: selectedDate) }
    func isToday(_ date: Date) -> Bool { cal.isDateInToday(date) }
    func isFuture(_ date: Date) -> Bool { cal.startOfDay(for: date) > cal.startOfDay(for: Date()) }

    /// 예산 상태: 0 여유(<70%) / 1 근접(70~100%) / 2 초과(잔액 음수)
    ///
    /// 그날 **실제로 쓸 수 있었던 금액**(기본 예산 + 이월) 기준으로 판단한다.
    /// 기본 예산만 보면 이월이 두둑한 날을 "초과"로, 이월이 마이너스인 날을 "여유"로
    /// 잘못 표시한다 — 되짚어보려는 사용자가 엉뚱한 날을 보게 된다.
    func status(on date: Date) -> Int {
        let day = cal.startOfDay(for: date)

        // 잔액 기록이 있으면 그게 가장 정확하다
        if let balance = dayBalances[day] {
            if balance < 0 { return 2 }
            let available = dayAvailable[day] ?? baseDailyBudget
            guard available > 0 else { return 0 }
            let ratio = Double(total(on: date)) / Double(available)
            return ratio >= 0.7 ? 1 : 0
        }

        // 기록이 없는 날은 기존 방식(기본 예산 대비)으로 대체
        guard baseDailyBudget > 0 else { return 0 }
        let ratio = Double(total(on: date)) / Double(baseDailyBudget)
        if ratio > 1.0 { return 2 }
        return ratio >= 0.7 ? 1 : 0
    }

    func select(_ date: Date) {
        selectedDate = cal.startOfDay(for: date)
        loadSelected()
    }
    func goPrevMonth() {
        selectedMonth = cal.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        load()
    }
    func goNextMonth() {
        guard canGoNext else { return }
        selectedMonth = cal.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        load()
    }

    // MARK: - 삭제 (과거 → 이월 체인 재계산)
    func delete(_ record: SpendingRecordModel, eventBus: AppEventBus) {
        if CoreDataManager.shared.deleteSpendingRecord(id: record.id) {
            CoreDataManager.shared.recalculateCarryOverChain(from: record.date)
            eventBus.notifySpendingAdded()
            load()
        }
    }

    /// 편집 저장 후 호출 (편집 시트에서 updateSpendingRecord 완료 후)
    func afterEdit(affectedFrom: Date, eventBus: AppEventBus) {
        CoreDataManager.shared.recalculateCarryOverChain(from: affectedFrom)
        eventBus.notifySpendingAdded()
        load()
    }
}
