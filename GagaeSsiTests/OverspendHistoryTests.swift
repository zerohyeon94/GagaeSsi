//
//  OverspendHistoryTests.swift
//  GagaeSsi
//
//  "언제 초과했는지" 역산 테스트
//

import XCTest
@testable import GagaeSsi

final class OverspendHistoryTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
    }
    override func tearDownWithError() throws { sut = nil }

    private func day(_ o: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: o, to: Date())!)
    }

    // MARK: - 순수 역산 로직

    func test_잔액이_음수인_날만_초과일로_잡는다() {
        let budgets = [
            DailyBudgetModel(availableAmount: 50_000, date: day(-3),
                             carryOverSources: [], spendingRecords: [
                                SpendingRecordModel(title: "점심", amount: 20_000, date: day(-3))]),
            DailyBudgetModel(availableAmount: 50_000, date: day(-2),
                             carryOverSources: [], spendingRecords: [
                                SpendingRecordModel(title: "쇼핑", amount: 80_000, date: day(-2))]),
        ]

        let days = OverspendAnalyzer.overspendDays(from: budgets)

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].date, day(-2))
        XCTAssertEqual(days[0].overspentAmount, 30_000)
        XCTAssertEqual(days[0].spent, 80_000)
        XCTAssertEqual(days[0].availableThatDay, 50_000)
    }

    func test_이월을_반영해_초과를_판정한다() {
        // 소비는 기본 예산보다 많지만 이월이 넉넉해 실제로는 초과가 아니다
        let notOver = DailyBudgetModel(
            availableAmount: 50_000, date: day(-1),
            carryOverSources: [CarryOverSourceModel(amount: 100_000, date: day(-2), toDate: day(-1))],
            spendingRecords: [SpendingRecordModel(title: "큰 지출", amount: 120_000, date: day(-1))])

        // 소비는 적지만 음수 이월 때문에 실제로는 초과다
        let over = DailyBudgetModel(
            availableAmount: 50_000, date: day(-2),
            carryOverSources: [CarryOverSourceModel(amount: -80_000, date: day(-3), toDate: day(-2))],
            spendingRecords: [SpendingRecordModel(title: "커피", amount: 5_000, date: day(-2))])

        let days = OverspendAnalyzer.overspendDays(from: [notOver, over])

        XCTAssertEqual(days.map(\.date), [day(-2)], "이월까지 봐야 실제 초과일을 가린다")
        XCTAssertEqual(days[0].overspentAmount, 35_000)
    }

    func test_위시저금도_초과_계산에_포함된다() {
        let budget = DailyBudgetModel(
            availableAmount: 50_000, date: day(-1), carryOverSources: [],
            spendingRecords: [SpendingRecordModel(title: "점심", amount: 48_000, date: day(-1))],
            wishSavingAmount: 5_000)

        let days = OverspendAnalyzer.overspendDays(from: [budget])

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].overspentAmount, 3_000)
        XCTAssertEqual(days[0].wishSaving, 5_000)
    }

    func test_최신순_정렬되고_합계와_최악의날을_구한다() {
        let budgets = (1...3).map { offset in
            DailyBudgetModel(availableAmount: 10_000, date: day(-offset),
                             carryOverSources: [], spendingRecords: [
                                SpendingRecordModel(title: "지출", amount: 10_000 + offset * 1_000,
                                                    date: day(-offset))])
        }

        let days = OverspendAnalyzer.overspendDays(from: budgets)

        XCTAssertEqual(days.map(\.date), [day(-1), day(-2), day(-3)], "최신순")
        XCTAssertEqual(OverspendAnalyzer.total(of: days), 1_000 + 2_000 + 3_000)
        XCTAssertEqual(OverspendAnalyzer.worst(of: days)?.date, day(-3), "가장 크게 넘긴 날")
    }

    func test_임계금액_미만은_무시한다() {
        let budget = DailyBudgetModel(availableAmount: 10_000, date: day(-1),
                                      carryOverSources: [], spendingRecords: [
                                        SpendingRecordModel(title: "지출", amount: 10_050, date: day(-1))])

        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget], minimumAmount: 100).isEmpty)
        XCTAssertEqual(OverspendAnalyzer.overspendDays(from: [budget], minimumAmount: 1).count, 1)
    }

    func test_초과가_없으면_빈배열() {
        let budget = DailyBudgetModel(availableAmount: 50_000, date: day(-1),
                                      carryOverSources: [], spendingRecords: [])
        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget]).isEmpty)
    }

    // MARK: - CoreData 조회

    func test_fetchOverspendDays는_실제_기록에서_초과일을_뽑는다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-5))

        for offset in [-5, -4, -3] {
            _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(offset),
                                                       carryOverSources: [], spendingRecords: []))
        }
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "작은 지출", amount: base / 2, date: day(-5)))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: base * 2, date: day(-4)))

        let days = sut.fetchOverspendDays(months: 3)

        XCTAssertEqual(days.map(\.date), [day(-4)])
        XCTAssertEqual(days[0].overspentAmount, base)
    }

    func test_조회_기간_밖의_초과는_제외된다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        let old = cal.date(byAdding: .month, value: -5, to: day(0))!
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 10_000, date: old,
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "옛날 지출", amount: 50_000, date: old))

        XCTAssertTrue(sut.fetchOverspendDays(months: 3).isEmpty)
        XCTAssertEqual(sut.fetchOverspendDays(months: 6).count, 1)
    }

    func test_부채로_전환돼도_초과한_날_기록은_남는다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [], debtPlanEnabled: true))
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))

        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: base * 3, date: day(-1)))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertNotNil(sut.fetchActiveDebt(), "부채로 전환됐다")

        let days = sut.fetchOverspendDays(months: 3)
        XCTAssertEqual(days.map(\.date), [day(-1)], "전환돼도 초과한 날은 되짚을 수 있어야 한다")
        XCTAssertEqual(days[0].overspentAmount, sut.fetchActiveDebt()?.remainingAmount,
                       "초과액이 부채 금액과 일치한다")
    }
}
