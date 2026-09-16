//
//  DailyBudgetCalculatorTests.swift
//  GagaeSsi
//
//  급여일 보정(말일 clamp + 주말 → 직전 금요일) 및 급여 기간 계산 테스트
//

import XCTest
@testable import GagaeSsi

final class DailyBudgetCalculatorTests: XCTestCase {

    // MARK: - Helpers
    private let cal = Calendar.current

    /// 해당 연·월·일의 자정(startOfDay) Date
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.startOfDay(for: cal.date(from: DateComponents(year: y, month: m, day: d))!)
    }

    private func config(payday: Int, salary: Int = 3_000_000, fixed: Int = 0) -> BudgetConfigModel {
        let costs = fixed > 0 ? [FixedCostModel(title: "고정", amount: fixed)] : []
        return BudgetConfigModel(salary: salary, payday: payday, fixedCosts: costs)
    }

    // MARK: - effectivePayday: 말일 보정
    func testEffectivePayday_clampsMonthEnd_february() {
        // payday 31 + 2026년 2월(28일, 28일은 토요일) → 28일로 clamp 후 주말 보정으로 27일(금)
        XCTAssertEqual(DailyBudgetCalculator.effectivePayday(payday: 31, year: 2026, month: 2),
                       day(2026, 2, 27))
    }

    func testEffectivePayday_clampsMonthEnd_april_weekday() {
        // payday 31 + 4월(30일, 30일은 목요일) → 30일, 평일이라 보정 없음. 5월로 오버플로 금지.
        XCTAssertEqual(DailyBudgetCalculator.effectivePayday(payday: 31, year: 2026, month: 4),
                       day(2026, 4, 30))
    }

    func testEffectivePayday_clampsMonthEnd_leapYear() {
        // payday 31 + 2024년 2월(윤년, 29일, 목요일) → 29일
        XCTAssertEqual(DailyBudgetCalculator.effectivePayday(payday: 31, year: 2024, month: 2),
                       day(2024, 2, 29))
    }

    // MARK: - effectivePayday: 주말 보정
    func testEffectivePayday_saturday_shiftsToFriday() {
        // 2026-07-25 토요일 → 24일(금)
        XCTAssertEqual(DailyBudgetCalculator.effectivePayday(payday: 25, year: 2026, month: 7),
                       day(2026, 7, 24))
    }

    func testEffectivePayday_sunday_shiftsToFriday() {
        // 2026-01-25 일요일 → 23일(금) (-2)
        XCTAssertEqual(DailyBudgetCalculator.effectivePayday(payday: 25, year: 2026, month: 1),
                       day(2026, 1, 23))
    }

    func testEffectivePayday_weekday_noChange() {
        // 2026-05-25 월요일 → 그대로
        XCTAssertEqual(DailyBudgetCalculator.effectivePayday(payday: 25, year: 2026, month: 5),
                       day(2026, 5, 25))
    }

    func testEffectivePayday_neverLandsOnWeekend() {
        // 어떤 달이든 실효 급여일은 토·일이 아니어야 한다
        for month in 1...12 {
            let d = DailyBudgetCalculator.effectivePayday(payday: 25, year: 2026, month: month)
            let weekday = cal.component(.weekday, from: d)   // 1=일, 7=토
            XCTAssertFalse(weekday == 1 || weekday == 7,
                           "2026-\(month) 실효 급여일이 주말: \(d)")
        }
    }

    // MARK: - payPeriod 브래킷팅
    func testPayPeriod_startAndEndAreEffectivePaydays() {
        // 2026-07-27(월) 시점, payday 25 → 기간 [07-24(금), 08-25(화)]
        let period = DailyBudgetCalculator.payPeriod(payday: 25, containing: day(2026, 7, 27))
        XCTAssertEqual(period.start, day(2026, 7, 24))
        XCTAssertEqual(period.end, day(2026, 8, 25))
    }

    func testPayPeriod_todayEqualsEffectivePayday_isPeriodStart() {
        // 실효 급여일 당일(07-24)은 새 기간의 시작이어야 한다 (반열림 start <= today)
        let period = DailyBudgetCalculator.payPeriod(payday: 25, containing: day(2026, 7, 24))
        XCTAssertEqual(period.start, day(2026, 7, 24))
    }

    func testPayPeriod_dayBeforeEffectivePayday_belongsToPreviousPeriod() {
        // 07-23은 아직 이전 기간 → periodEnd가 07-24
        let period = DailyBudgetCalculator.payPeriod(payday: 25, containing: day(2026, 7, 23))
        XCTAssertEqual(period.end, day(2026, 7, 24))
    }

    func testPayPeriod_earlyPayday_crossesMonthBoundary() {
        // payday 1, 2026-08-01은 토요일 → 실효 07-31(금). 08-10 시점의 기간 시작은 07-31.
        let period = DailyBudgetCalculator.payPeriod(payday: 1, containing: day(2026, 8, 10))
        XCTAssertEqual(period.start, day(2026, 7, 31))
        XCTAssertEqual(period.end, day(2026, 9, 1))   // 2026-09-01 화요일, 무보정
    }

    // MARK: - daysUntilNextPayday
    func testDaysUntilNextPayday_usesAdjustedEnd() {
        // 07-24 시점 → 다음 실효 급여일 08-25까지 32일
        let days = DailyBudgetCalculator.daysUntilNextPayday(payday: 25, from: day(2026, 7, 24))
        XCTAssertEqual(days, 32)
    }

    // MARK: - calculate 회귀
    func testCalculate_weekdayPayday_dividesByPeriodDays() {
        // payday 25, 2026-05(05-25 월 ~ 06-25 목, 둘 다 평일) → 31일
        // usableSalary 3,000,000 / 31 = 96,774 (내림)
        let budget = DailyBudgetCalculator.calculate(from: config(payday: 25), for: day(2026, 5, 27))
        XCTAssertEqual(budget, 3_000_000 / 31)
    }

    func testCalculate_subtractsFixedCosts() {
        // (3,000,000 - 500,000) / 31
        let budget = DailyBudgetCalculator.calculate(from: config(payday: 25, fixed: 500_000),
                                                     for: day(2026, 5, 27))
        XCTAssertEqual(budget, 2_500_000 / 31)
    }

    func testCalculate_adjustedPeriodLengthDiffersFromNaive() {
        // 07-24(금) ~ 08-25(화) = 32일. 명목(07-25~08-25=31일)과 달라야 경계 이동이 반영된 것.
        let budget = DailyBudgetCalculator.calculate(from: config(payday: 25), for: day(2026, 7, 27))
        XCTAssertEqual(budget, 3_000_000 / 32)
        XCTAssertNotEqual(budget, 3_000_000 / 31)
    }
}
