//
//  InstallmentTests.swift
//  GagaeSsi
//
//  할부 — 월 납입액·활성 판정·예산 반영 테스트
//

import XCTest
@testable import GagaeSsi

final class InstallmentTests: XCTestCase {
    private let cal = Calendar.current
    private func d(_ y: Int, _ m: Int, _ day: Int = 15) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day))!
    }
    private func inst(total: Int, months: Int, sy: Int, sm: Int, title: String = "할부") -> InstallmentModel {
        InstallmentModel(title: title, totalAmount: total, months: months, startYear: sy, startMonth: sm)
    }

    func testMonthlyAmount() {
        XCTAssertEqual(inst(total: 1_200_000, months: 12, sy: 2026, sm: 5).monthlyAmount, 100_000)
        XCTAssertEqual(inst(total: 0, months: 0, sy: 2026, sm: 5).monthlyAmount, 0)   // 방어
    }

    func testMonthsSinceStart() {
        let i = inst(total: 100, months: 12, sy: 2026, sm: 5)
        XCTAssertEqual(i.monthsSinceStart(for: d(2026, 5)), 0)
        XCTAssertEqual(i.monthsSinceStart(for: d(2026, 7)), 2)
        XCTAssertEqual(i.monthsSinceStart(for: d(2027, 5)), 12)
        XCTAssertEqual(i.monthsSinceStart(for: d(2026, 4)), -1)
    }

    func testIsActive() {
        let i = inst(total: 1_200_000, months: 12, sy: 2026, sm: 5)  // 2026-05 ~ 2027-04
        XCTAssertTrue(i.isActive(for: d(2026, 5)))    // 첫 달
        XCTAssertTrue(i.isActive(for: d(2027, 4)))    // 마지막 달
        XCTAssertFalse(i.isActive(for: d(2026, 4)))   // 시작 전
        XCTAssertFalse(i.isActive(for: d(2027, 5)))   // 종료 후
    }

    func testRemainingMonths() {
        let i = inst(total: 1_200_000, months: 12, sy: 2026, sm: 5)
        XCTAssertEqual(i.remainingMonths(for: d(2026, 5)), 12)
        XCTAssertEqual(i.remainingMonths(for: d(2026, 7)), 10)
        XCTAssertEqual(i.remainingMonths(for: d(2026, 4)), 12)  // 시작 전
        XCTAssertEqual(i.remainingMonths(for: d(2027, 5)), 0)   // 완료
    }

    func testActiveMonthlyTotal_sumsOnlyActive() {
        let items = [
            inst(total: 1_200_000, months: 12, sy: 2026, sm: 5),  // 활성(월 100,000)
            inst(total: 600_000, months: 6, sy: 2026, sm: 1),     // 2026-06 종료 → 2026-07엔 비활성
            inst(total: 300_000, months: 3, sy: 2026, sm: 7),     // 활성(월 100,000)
        ]
        XCTAssertEqual(InstallmentModel.activeMonthlyTotal(items, for: d(2026, 7)), 200_000)
    }

    func testCalculate_reflectsInstallment() {
        let config = BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: [])
        let items = [inst(total: 1_200_000, months: 12, sy: 2026, sm: 5)]  // 월 100,000
        // 2026-05-27: 급여기간 05-25~06-25 = 31일
        let base = DailyBudgetCalculator.calculate(from: config, installments: items, for: d(2026, 5, 27))
        XCTAssertEqual(base, (3_000_000 - 100_000) / 31)
    }

    func testCalculate_completedInstallment_notDeducted() {
        let config = BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: [])
        let items = [inst(total: 300_000, months: 3, sy: 2026, sm: 1)]  // 2026-03 종료
        let base = DailyBudgetCalculator.calculate(from: config, installments: items, for: d(2026, 5, 27))
        XCTAssertEqual(base, 3_000_000 / 31)   // 완료된 할부는 차감 안 됨
    }
}
