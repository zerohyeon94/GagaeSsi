//
//  CarryOverPoolLedgerTests.swift
//  GagaeSsi
//
//  모아둔 이월금 사용 원장 테스트
//

import XCTest
@testable import GagaeSsi

final class CarryOverPoolLedgerTests: XCTestCase {
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
    private func setupSeparate() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [], carryOverMode: .separate))
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 50_000, date: day(0),
                                                   carryOverSources: [], spendingRecords: []))
    }

    // MARK: - 사유 해석

    /// 사유가 없던 기존 기록은 부호로 추정해야 한다 (마이그레이션 호환)
    func test_사유가_없으면_부호로_추정한다() {
        XCTAssertEqual(CarryOverPoolReason.inferred(from: nil, amount: 10_000), .deposit)
        XCTAssertEqual(CarryOverPoolReason.inferred(from: nil, amount: -10_000), .withdraw)
        XCTAssertEqual(CarryOverPoolReason.inferred(from: "shortfall", amount: -10_000), .shortfall)
        XCTAssertEqual(CarryOverPoolReason.inferred(from: "이상한값", amount: 10_000), .deposit)
    }

    func test_사유별_방향이_정의되어_있다() {
        XCTAssertTrue(CarryOverPoolReason.deposit.isIncoming)
        XCTAssertTrue(CarryOverPoolReason.sweep.isIncoming)
        XCTAssertFalse(CarryOverPoolReason.withdraw.isIncoming)
        XCTAssertFalse(CarryOverPoolReason.shortfall.isIncoming)
        XCTAssertFalse(CarryOverPoolReason.debtRepay.isIncoming)

        for reason in CarryOverPoolReason.allCases {
            XCTAssertFalse(reason.label.isEmpty)
            XCTAssertFalse(reason.emoji.isEmpty)
        }
    }

    // MARK: - 집계 (순수 로직)

    func test_적립과_사용을_나눠_집계한다() {
        let summary = CarryOverPoolSummary.make(from: [
            CarryOverPoolEntryModel(date: day(0), amount: 30_000, reason: .deposit),
            CarryOverPoolEntryModel(date: day(-1), amount: -10_000, reason: .withdraw),
            CarryOverPoolEntryModel(date: day(-2), amount: -5_000, reason: .shortfall),
        ])

        XCTAssertEqual(summary.depositTotal, 30_000)
        XCTAssertEqual(summary.usedTotal, 15_000)
        XCTAssertEqual(summary.net, 15_000)
    }

    func test_사유별_사용액을_많이_쓴_순으로_낸다() {
        let usage = CarryOverPoolSummary.usageByReason(from: [
            CarryOverPoolEntryModel(date: day(0), amount: 50_000, reason: .deposit),
            CarryOverPoolEntryModel(date: day(-1), amount: -5_000, reason: .withdraw),
            CarryOverPoolEntryModel(date: day(-2), amount: -20_000, reason: .debtRepay),
            CarryOverPoolEntryModel(date: day(-3), amount: -3_000, reason: .withdraw),
        ])

        XCTAssertEqual(usage.map(\.reason), [.debtRepay, .withdraw])
        XCTAssertEqual(usage[0].amount, 20_000)
        XCTAssertEqual(usage[1].amount, 8_000, "같은 사유는 합산")
    }

    // MARK: - 사유 기록

    func test_꺼내_쓰면_withdraw로_남는다() {
        setupSeparate()
        sut.depositToPool(amount: 30_000, date: day(0))

        XCTAssertTrue(sut.withdrawFromPool(amount: 10_000))

        let entries = sut.fetchPoolEntries(months: 3)
        XCTAssertEqual(entries.first(where: { $0.amount < 0 })?.reason, .withdraw)
        XCTAssertEqual(sut.carryOverPoolBalance(), 20_000)
    }

    func test_부족액_충당은_shortfall로_남는다() {
        setupSeparate()
        sut.depositToPool(amount: 30_000, date: day(0))

        XCTAssertTrue(sut.withdrawFromPool(amount: 8_000, reason: .shortfall))

        XCTAssertEqual(sut.fetchPoolEntries(months: 3).first(where: { $0.amount < 0 })?.reason,
                       .shortfall)
    }

    func test_부채_상환에_쓰면_debtRepay로_남는다() {
        // 오늘 일자를 미리 만들면 processDailyBudgets가 조기 종료해 부채가 안 생긴다
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [], carryOverMode: .separate))
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: base * 3, date: day(-1)))
        sut.processDailyBudgets(upTo: day(0))
        XCTAssertNotNil(sut.fetchActiveDebt(), "부채가 생겨야 이 테스트가 의미 있다")
        sut.depositToPool(amount: 20_000, date: day(0))

        XCTAssertTrue(sut.repayDebtFromPool(amount: 20_000))

        XCTAssertEqual(sut.fetchPoolEntries(months: 3).first(where: { $0.amount < 0 })?.reason,
                       .debtRepay)
    }

    func test_일자_전환_적립은_deposit으로_남는다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [], carryOverMode: .separate))
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))

        sut.processDailyBudgets(upTo: day(0))

        let entries = sut.fetchPoolEntries(months: 3)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].reason, .deposit)
        XCTAssertEqual(entries[0].amount, base)
    }

    func test_이월방식_전환은_sweep으로_남는다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [], carryOverMode: .full))
        _ = sut.createDailyBudget(DailyBudgetModel(
            availableAmount: 50_000, date: day(0),
            carryOverSources: [CarryOverSourceModel(amount: 30_000, date: day(-1), toDate: day(0))],
            spendingRecords: []))

        XCTAssertTrue(sut.updateCarryOverMode(.separate))

        let entries = sut.fetchPoolEntries(months: 3)
        XCTAssertEqual(entries.first?.reason, .sweep)
        XCTAssertEqual(entries.first?.amount, 30_000)
    }

    // MARK: - 조회

    func test_원장은_최신순으로_조회된다() {
        setupSeparate()
        sut.depositToPool(amount: 10_000, date: day(-2))
        sut.depositToPool(amount: 20_000, date: day(-1))
        sut.depositToPool(amount: 30_000, date: day(0))

        let entries = sut.fetchPoolEntries(months: 3)
        XCTAssertEqual(entries.map(\.amount), [30_000, 20_000, 10_000])
    }

    func test_조회_기간_밖은_제외된다() {
        setupSeparate()
        let old = cal.date(byAdding: .month, value: -5, to: day(0))!
        sut.depositToPool(amount: 10_000, date: old)
        sut.depositToPool(amount: 20_000, date: day(0))

        XCTAssertEqual(sut.fetchPoolEntries(months: 3).count, 1)
        XCTAssertEqual(sut.fetchPoolEntries(months: 6).count, 2)
    }

    /// 원장을 남겨도 잔액 계산이 달라지면 안 된다
    func test_원장_추가가_잔액에_영향을_주지_않는다() {
        setupSeparate()
        sut.depositToPool(amount: 30_000, date: day(0))
        _ = sut.withdrawFromPool(amount: 12_000, reason: .shortfall)

        XCTAssertEqual(sut.carryOverPoolBalance(), 18_000)
        let summary = CarryOverPoolSummary.make(from: sut.fetchPoolEntries(months: 3))
        XCTAssertEqual(summary.net, 18_000, "원장 합계와 잔액이 일치해야 한다")
    }
}
