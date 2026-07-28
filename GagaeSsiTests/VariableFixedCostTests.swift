//
//  VariableFixedCostTests.swift
//  GagaeSsi
//
//  변동 고정비 + 월별 확정 금액 테스트
//

import XCTest
@testable import GagaeSsi

final class VariableFixedCostTests: XCTestCase {
    var sut: CoreDataManager!
    private let year = 2026
    private let month = 5

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        // 고정비 생성에는 BudgetConfig가 필요
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
    }
    override func tearDownWithError() throws { sut = nil }

    private func makeVariableCost(title: String = "관리비", estimate: Int = 100_000, dueDay: Int = 15) -> FixedCostModel {
        let model = FixedCostModel(title: title, amount: estimate, isVariable: true, dueDay: dueDay)
        XCTAssertTrue(sut.createFixedCost(model))
        return sut.fetchFixedCosts().first { $0.title == title }!
    }

    // MARK: - 모델 저장
    func testCreateVariableFixedCost_persistsFlags() {
        _ = makeVariableCost(estimate: 90_000, dueDay: 15)
        let fetched = sut.fetchFixedCosts().first { $0.title == "관리비" }!
        XCTAssertTrue(fetched.isVariable)
        XCTAssertEqual(fetched.dueDay, 15)
        XCTAssertEqual(fetched.amount, 90_000)
    }

    // MARK: - 확정 upsert + amount 갱신
    func testConfirmMonthlyAmount_recordsEntryAndUpdatesAmount() {
        let cost = makeVariableCost(estimate: 100_000)
        XCTAssertNil(sut.fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month))  // 미확정

        XCTAssertTrue(sut.confirmMonthlyAmount(fixedCostId: cost.id, year: year, month: month, amount: 120_000))

        let entry = sut.fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month)
        XCTAssertEqual(entry?.amount, 120_000)
        // 예상액(amount)이 확정액으로 갱신되어 배분에 반영
        XCTAssertEqual(sut.fetchFixedCosts().first { $0.id == cost.id }?.amount, 120_000)
    }

    func testConfirmMonthlyAmount_upsertOverwritesSameMonth() {
        let cost = makeVariableCost(estimate: 100_000)
        _ = sut.confirmMonthlyAmount(fixedCostId: cost.id, year: year, month: month, amount: 120_000)
        _ = sut.confirmMonthlyAmount(fixedCostId: cost.id, year: year, month: month, amount: 135_000)

        XCTAssertEqual(sut.fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month)?.amount, 135_000)
        XCTAssertEqual(sut.fetchFixedCosts().first { $0.id == cost.id }?.amount, 135_000)
    }

    func testFetchMonthlyEntry_differentMonth_isNil() {
        let cost = makeVariableCost()
        _ = sut.confirmMonthlyAmount(fixedCostId: cost.id, year: year, month: month, amount: 120_000)
        XCTAssertNil(sut.fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month + 1))
    }

    // MARK: - 예산 반영
    func testCalculate_reflectsConfirmedAmount() {
        let cost = makeVariableCost(estimate: 100_000)
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!

        // 확정 전: (3,000,000 - 100,000) / 31
        let before = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: date)
        XCTAssertEqual(before, 2_900_000 / 31)

        _ = sut.confirmMonthlyAmount(fixedCostId: cost.id, year: year, month: month, amount: 120_000)

        // 확정 후: (3,000,000 - 120,000) / 31
        let after = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: date)
        XCTAssertEqual(after, 2_880_000 / 31)
        XCTAssertLessThan(after, before)
    }

    // MARK: - 홈 미확정 프롬프트
    func testUnconfirmedVariableCosts_reflectsDueDayAndConfirmation() {
        let cost = makeVariableCost(dueDay: 10)

        // 지출일 전(5일) → 미확정 목록 비어 있음
        XCTAssertTrue(sut.unconfirmedVariableCosts(asOf: dayOf(2026, 5, 5)).isEmpty)

        // 지출일 지남(15일) + 미확정 → 목록에 등장
        XCTAssertEqual(sut.unconfirmedVariableCosts(asOf: dayOf(2026, 5, 15)).first?.id, cost.id)

        // 확정하면 목록에서 사라짐
        _ = sut.confirmMonthlyAmount(fixedCostId: cost.id, year: 2026, month: 5, amount: 120_000)
        XCTAssertTrue(sut.unconfirmedVariableCosts(asOf: dayOf(2026, 5, 15)).isEmpty)
    }

    private func dayOf(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - cascade 삭제
    func testDeleteVariableCost_cascadesMonthlyEntries() {
        let cost = makeVariableCost()
        _ = sut.confirmMonthlyAmount(fixedCostId: cost.id, year: year, month: month, amount: 120_000)
        XCTAssertNotNil(sut.fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month))

        XCTAssertTrue(sut.deleteFixedCost(id: cost.id))
        XCTAssertNil(sut.fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month))
    }
}
