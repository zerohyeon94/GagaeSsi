//
//  BudgetModeTests.swift
//  GagaeSsi
//
//  예산 모드 3종 테스트 — 기본 일일 예산 산출만 달라지고 나머지는 동일해야 한다
//

import XCTest
@testable import GagaeSsi

final class BudgetModeTests: XCTestCase {
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
    private func lumpSum(total: Int, endOffset: Int, startOffset: Int = 0) -> BudgetConfigModel {
        BudgetConfigModel(salary: 0, payday: 25, fixedCosts: [],
                          budgetMode: .lumpSum, totalAmount: total,
                          lumpSumStart: day(startOffset), lumpSumEnd: day(endOffset))
    }

    // MARK: - 기본값·마이그레이션

    func test_기본_모드는_정기수입() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        XCTAssertEqual(sut.fetchBudgetConfig()?.budgetMode, .recurring)
    }

    func test_알_수_없는_값은_정기수입으로_해석한다() {
        XCTAssertEqual(BudgetMode.from(nil), .recurring)
        XCTAssertEqual(BudgetMode.from("이상한값"), .recurring)
        XCTAssertEqual(BudgetMode.from("lumpSum"), .lumpSum)
    }

    func test_급여기간_개념은_정기수입에만_있다() {
        XCTAssertTrue(BudgetMode.recurring.hasPayPeriod)
        XCTAssertFalse(BudgetMode.lumpSum.hasPayPeriod)
        XCTAssertFalse(BudgetMode.fixedDaily.hasPayPeriod)
    }

    // MARK: - 정기 수입 (기존 동작 회귀)

    func test_정기수입은_기존_계산과_동일하다() {
        let config = BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: [])
        let period = DailyBudgetCalculator.payPeriod(payday: 25, containing: day(0))
        let days = cal.dateComponents([.day], from: period.start, to: period.end).day!

        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(0)),
                       3_000_000 / days)
    }

    // MARK: - 총액 모드

    func test_총액을_기간_일수로_나눈다() {
        // 오늘~9일 뒤 = 10일 (종료일 당일 포함)
        let config = lumpSum(total: 1_000_000, endOffset: 9)
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(0)), 100_000)
    }

    func test_종료일_당일도_쓸_수_있다() {
        let config = lumpSum(total: 100_000, endOffset: 9)
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(9)), 10_000)
        XCTAssertFalse(DailyBudgetCalculator.isLumpSumPeriodOver(config: config, on: day(9)))
    }

    /// 마지막 값을 유지하면 이미 다 쓴 돈을 계속 배정하게 된다
    func test_종료일이_지나면_0원이_된다() {
        let config = lumpSum(total: 100_000, endOffset: 9)
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(10)), 0)
        XCTAssertTrue(DailyBudgetCalculator.isLumpSumPeriodOver(config: config, on: day(10)))
    }

    func test_남은_일수는_종료일_당일을_포함한다() {
        let config = lumpSum(total: 100_000, endOffset: 9)
        XCTAssertEqual(DailyBudgetCalculator.lumpSumDaysLeft(config: config, on: day(0)), 10)
        XCTAssertEqual(DailyBudgetCalculator.lumpSumDaysLeft(config: config, on: day(9)), 1)
        XCTAssertEqual(DailyBudgetCalculator.lumpSumDaysLeft(config: config, on: day(10)), 0)
    }

    func test_총액이나_기간이_없으면_0() {
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: lumpSum(total: 0, endOffset: 9), for: day(0)), 0)

        let noPeriod = BudgetConfigModel(salary: 0, payday: 25, fixedCosts: [],
                                         budgetMode: .lumpSum, totalAmount: 100_000)
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: noPeriod, for: day(0)), 0)
    }

    func test_총액모드는_고정비를_빼지_않는다() {
        var config = lumpSum(total: 1_000_000, endOffset: 9)
        config.fixedCosts = [FixedCostModel(title: "월세", amount: 500_000)]
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(0)), 100_000,
                       "총액 모드엔 고정비 개념이 없다 — 미리 빼고 넣도록 안내한다")
    }

    // MARK: - 하루 직접 설정

    func test_직접_설정한_금액을_그대로_쓴다() {
        let config = BudgetConfigModel(salary: 0, payday: 25, fixedCosts: [],
                                       budgetMode: .fixedDaily, dailyAmount: 30_000)
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(0)), 30_000)
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(100)), 30_000,
                       "날짜와 무관하게 같다")
    }

    func test_음수는_0으로_막는다() {
        let config = BudgetConfigModel(salary: 0, payday: 25, fixedCosts: [],
                                       budgetMode: .fixedDaily, dailyAmount: -5_000)
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: config, for: day(0)), 0)
    }

    // MARK: - 저장·전환

    func test_모드와_관련_값이_저장된다() {
        _ = sut.createBudgetConfig(from: lumpSum(total: 500_000, endOffset: 20))

        let loaded = sut.fetchBudgetConfig()
        XCTAssertEqual(loaded?.budgetMode, .lumpSum)
        XCTAssertEqual(loaded?.totalAmount, 500_000)
        XCTAssertEqual(loaded?.lumpSumEnd.map { cal.startOfDay(for: $0) }, day(20))
    }

    func test_모드를_바꿔도_과거_기록은_보존된다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 50_000, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "점심", amount: 9_000, date: day(-1)))

        var config = sut.fetchBudgetConfig()!
        config.budgetMode = .fixedDaily
        config.dailyAmount = 20_000
        XCTAssertTrue(sut.updateBudgetConfig(config))

        XCTAssertEqual(sut.fetchSpendingRecords(date: day(-1)).count, 1, "지난 소비 기록이 남는다")
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(-1))?.availableAmount, 50_000,
                       "지난 일자의 예산도 재계산되지 않는다")
    }

    // MARK: - 부채 정산과의 관계

    /// 급여일 정산은 급여 기간이 있는 모드에서만 일어나야 한다
    func test_급여기간이_없는_모드는_급여일_흡수를_하지_않는다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 0, payday: cal.component(.day, from: day(0)), fixedCosts: [],
            debtPlanEnabled: true, budgetMode: .fixedDaily, dailyAmount: 50_000))

        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 50_000, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: 200_000, date: day(-1)))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertNotNil(sut.fetchActiveDebt(), "부채는 정상적으로 생긴다")
        XCTAssertEqual(sut.fetchBudgetConfig()?.absorbedDebtAmount, 0, "흡수는 일어나지 않는다")
        XCTAssertFalse(sut.needsPaydayAbsorptionPrompt())
    }

    /// 모드가 달라도 이월·부채 전환은 동일하게 동작해야 한다
    func test_총액모드에서도_초과분이_부채로_전환된다() {
        _ = sut.createBudgetConfig(from: {
            var c = lumpSum(total: 1_000_000, endOffset: 9, startOffset: -1)
            c.debtPlanEnabled = true
            return c
        }())
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        XCTAssertGreaterThan(base, 0)

        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: base * 3, date: day(-1)))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, base * 2)
    }

    func test_모든_모드에_라벨과_설명이_있다() {
        for mode in BudgetMode.allCases {
            XCTAssertFalse(mode.label.isEmpty)
            XCTAssertFalse(mode.emoji.isEmpty)
            XCTAssertFalse(mode.summary.isEmpty)
        }
        XCTAssertEqual(BudgetMode.allCases.count, 3)
    }
}
