//
//  BudgetCalculationUtils.swift
//  GagaeSsi
//
//  예산 계산 유틸리티
//

import Foundation

struct DailyBudgetCalculator {

    // MARK: - 일일 예산

    /// 기본 일일 예산을 산출한다. **예산 모드에 따라 산출 방식만 달라지고**,
    /// 이월·위시 저금·부채 상환·통계는 모드와 무관하게 동일하게 동작한다.
    static func calculate(from config: BudgetConfigModel,
                          installments: [InstallmentModel] = [],
                          for date: Date) -> Int {
        switch config.budgetMode {
        case .recurring:
            return recurringDailyBudget(from: config, installments: installments, for: date)
        case .lumpSum:
            return lumpSumDailyBudget(from: config, for: date)
        case .fixedDaily:
            return max(0, config.dailyAmount)
        }
    }

    /// 정기 수입: (수입 − 고정비 − 할부 − 흡수한 초과분) ÷ 급여 기간 일수 (원 단위 내림)
    ///
    /// 흡수한 초과분은 급여일에 남아 있던 부채를 그 급여 기간 예산에 녹인 금액이다.
    /// 부채가 급여 기간을 넘어 무한히 끌리지 않게 하고, 하루 예산이 음수로 보이지 않게 한다.
    private static func recurringDailyBudget(from config: BudgetConfigModel,
                                             installments: [InstallmentModel],
                                             for date: Date) -> Int {
        let period = payPeriod(payday: config.payday, containing: date)
        let usableSalary = usableSalary(from: config, installments: installments,
                                        for: date, period: period)

        let totalDays = Calendar.current.dateComponents([.day], from: period.start, to: period.end).day ?? 0
        guard totalDays > 0 else { return usableSalary }   // 방어: 비정상 기간

        return usableSalary / totalDays
    }

    /// 총액 모드: 총액 ÷ (시작일 ~ 종료일 일수). 종료일이 지나면 **0**.
    ///
    /// 마지막 값을 유지하면 이미 다 쓴 돈을 계속 배정하는 셈이라, 없으면 없다고 보여준다.
    /// 홈에서 기간 종료를 안내해 재설정을 유도한다.
    private static func lumpSumDailyBudget(from config: BudgetConfigModel, for date: Date) -> Int {
        guard config.totalAmount > 0,
              let start = config.lumpSumStart, let end = config.lumpSumEnd else { return 0 }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        guard day <= endDay else { return 0 }              // 기간 종료 → 재설정 필요
        guard let days = calendar.dateComponents([.day], from: startDay, to: endDay).day,
              days >= 0 else { return 0 }

        return config.totalAmount / (days + 1)             // 종료일 당일도 쓸 수 있는 날
    }

    /// 총액 모드에서 기간이 끝났는지 (홈 안내용)
    static func isLumpSumPeriodOver(config: BudgetConfigModel, on date: Date = Date()) -> Bool {
        guard config.budgetMode == .lumpSum, let end = config.lumpSumEnd else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: end)
    }

    /// 총액 모드에서 남은 일수 (종료일 당일 포함). 기간이 끝났으면 0.
    static func lumpSumDaysLeft(config: BudgetConfigModel, on date: Date = Date()) -> Int {
        guard config.budgetMode == .lumpSum, let end = config.lumpSumEnd else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: end)).day ?? -1
        return max(0, days + 1)
    }

    /// 급여 기간 전체에 배분할 금액 (흡수한 초과분 차감 전/후 구분용으로 분리)
    private static func usableSalary(from config: BudgetConfigModel,
                                     installments: [InstallmentModel],
                                     for date: Date,
                                     period: (start: Date, end: Date)) -> Int {
        let base = absorbableSalary(from: config, installments: installments, for: date)

        // 이 급여 기간에 흡수한 초과분이 있으면 차감한다
        guard let absorbedStart = config.absorbedDebtPeriodStart,
              Calendar.current.isDate(absorbedStart, inSameDayAs: period.start) else { return base }
        return base - config.absorbedDebtAmount
    }

    /// 초과분 흡수 전 배분 가능 금액 (월급 − 고정비 − 할부).
    /// 급여일에 흡수할 수 있는 부채의 상한이기도 하다 — 이보다 많이 흡수하면 하루 예산이 음수가 된다.
    static func absorbableSalary(from config: BudgetConfigModel,
                                 installments: [InstallmentModel] = [],
                                 for date: Date) -> Int {
        let fixedTotal = config.fixedCosts.map { $0.amount }.reduce(0, +)
        let installmentTotal = InstallmentModel.activeMonthlyTotal(installments, for: date)
        return config.salary - fixedTotal - installmentTotal
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
