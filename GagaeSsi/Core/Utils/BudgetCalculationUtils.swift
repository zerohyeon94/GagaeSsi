//
//  BudgetCalculationUtils.swift
//  GagaeSsi
//
//  예산 계산 유틸리티
//

import Foundation

struct DailyBudgetCalculator {

    // MARK: - 일일 예산

    /// 일일 예산 계산: (월급 − 고정비 합계) ÷ 급여 기간 일수 (원 단위 내림)
    static func calculate(from config: BudgetConfigModel, for date: Date) -> Int {
        let fixedTotal = config.fixedCosts.map { $0.amount }.reduce(0, +)
        let usableSalary = config.salary - fixedTotal

        let period = payPeriod(payday: config.payday, containing: date)
        let totalDays = Calendar.current.dateComponents([.day], from: period.start, to: period.end).day ?? 0
        guard totalDays > 0 else { return usableSalary }   // 방어: 비정상 기간

        return usableSalary / totalDays
    }

    // MARK: - 실효 급여일 (말일 보정 + 주말 보정)

    /// 명목 급여일을 해당 연·월의 실제 입금일(startOfDay)로 보정한다.
    /// 1) 말일 보정: 그 달에 없는 날(예: 31일)이면 말일로 clamp
    /// 2) 주말 보정: 토요일이면 −1일(금), 일요일이면 −2일(금)
    static func effectivePayday(payday: Int, year: Int, month: Int) -> Date {
        let calendar = Calendar.current
        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!

        // 1) 말일 보정
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let clampedDay = min(max(payday, 1), daysInMonth)
        var date = calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))!

        // 2) 주말 보정 (1=일 ... 7=토)
        switch calendar.component(.weekday, from: date) {
        case 7: date = calendar.date(byAdding: .day, value: -1, to: date)!   // 토 → 금
        case 1: date = calendar.date(byAdding: .day, value: -2, to: date)!   // 일 → 금
        default: break
        }

        return calendar.startOfDay(for: date)
    }

    /// 명목 급여일이 실제 보정(말일 clamp 또는 주말 이동)되는지 여부
    static func isPaydayAdjusted(payday: Int, year: Int, month: Int) -> Bool {
        let calendar = Calendar.current
        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let nominalDay = min(max(payday, 1), daysInMonth)
        let nominal = calendar.startOfDay(for:
            calendar.date(from: DateComponents(year: year, month: month, day: nominalDay))!)
        return effectivePayday(payday: payday, year: year, month: month) != nominal
            || nominalDay != payday
    }

    // MARK: - 급여 기간

    /// `date`가 속한 급여 기간 [start, end) 을 반환한다.
    /// today 주변 3개월(전·이번·다음)의 실효 급여일 후보로 감싸므로,
    /// 실효 급여일이 달 경계를 넘는 경우(예: 1일이 일요일 → 전월 말)도 정확히 처리한다.
    static func payPeriod(payday: Int, containing date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let comps = calendar.dateComponents([.year, .month], from: today)
        guard let year = comps.year, let month = comps.month else { return (today, today) }

        let firstThisMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!

        // 전·이번·다음 달의 실효 급여일 후보
        var candidates: [Date] = []
        for offset in -1...1 {
            let m = calendar.date(byAdding: .month, value: offset, to: firstThisMonth)!
            let mc = calendar.dateComponents([.year, .month], from: m)
            candidates.append(effectivePayday(payday: payday, year: mc.year!, month: mc.month!))
        }
        candidates.sort()

        let start = candidates.last { $0 <= today }
            ?? candidates.first!
        let end = candidates.first { $0 > today }
            ?? calendar.date(byAdding: .month, value: 1, to: start)!
        return (start, end)
    }

    /// 급여 기간 시작일 (실효 급여일)
    static func calculatePayPeriodStart(payday: Int, today: Date) -> Date {
        payPeriod(payday: payday, containing: today).start
    }

    /// 다음 실효 급여일 (급여 기간 종료 경계)
    static func nextPayday(payday: Int, from date: Date = Date()) -> Date {
        payPeriod(payday: payday, containing: date).end
    }

    /// 급여 기간 종료일까지 남은 일수
    static func daysUntilNextPayday(payday: Int, from date: Date = Date()) -> Int {
        let period = payPeriod(payday: payday, containing: date)
        let today = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: today, to: period.end).day ?? 0
    }
}
