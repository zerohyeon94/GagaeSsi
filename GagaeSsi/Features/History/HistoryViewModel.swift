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
    /// 그 달 하루 기본 예산 (캘린더 상태 색 기준)
    private(set) var baseDailyBudget: Int = 0

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
        loadSelected()
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

    /// 예산 상태: 0 여유(<70%) / 1 근접(70~100%) / 2 초과(>100%)
    func status(on date: Date) -> Int {
        guard baseDailyBudget > 0 else { return 0 }
        let ratio = Double(total(on: date)) / Double(baseDailyBudget)
        if ratio > 1.0 { return 2 }
        if ratio >= 0.7 { return 1 }
        return 0
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
