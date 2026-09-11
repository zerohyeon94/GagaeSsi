//
//  PastSpendAutoRecalcTests.swift
//  GagaeSsi
//
//  과거 날짜 소비의 생성/수정/삭제가 이월 체인을 "자동으로" 재계산하는지 검증.
//
//  기존 CarryOverChainTests는 `recalculateCarryOverChain`을 직접 호출해 데이터 계층 로직을
//  검증한다. 여기서는 호출자가 그것을 잊어도 되도록 CRUD 자체가 재계산을 책임지는지 본다.
//  (기록 화면은 호출했지만 소비 입력 화면은 호출하지 않아 과거 날짜 추가가 반영되지 않았다)
//

import XCTest
@testable import GagaeSsi

final class PastSpendAutoRecalcTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
    }
    override func tearDownWithError() throws { sut = nil }

    private func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date())!)
    }
    private func setup(_ mode: CarryOverMode) {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25,
                                                           fixedCosts: [], carryOverMode: mode))
    }
    private func seedDay(_ date: Date, availableAmount: Int) {
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: availableAmount, date: date,
                                                   carryOverSources: [], spendingRecords: []))
    }
    private func carrySum(_ date: Date) -> Int {
        sut.fetchDailyBudgetModel(date: date)?.carryOverSources.map { $0.amount }.reduce(0, +) ?? 0
    }

    // 과거 날짜에 소비를 "추가"하면 재계산 호출 없이도 이후 날 이월이 줄어든다
    func testCreate_pastSpend_propagatesWithoutManualRecalc() {
        setup(.full)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let beforeD1 = carrySum(day(-1))
        let beforeD0 = carrySum(day(0))

        _ = sut.createSpendingRecord(SpendingRecordModel(title: "과거 소비", amount: 5_000, date: day(-2)))

        XCTAssertEqual(carrySum(day(-1)), beforeD1 - 5_000)
        XCTAssertEqual(carrySum(day(0)), beforeD0 - 5_000)
    }

    // 과거 날짜 소비를 "삭제"하면 재계산 호출 없이도 이후 날 이월이 늘어난다
    func testDelete_pastSpend_propagatesWithoutManualRecalc() {
        setup(.full)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let record = SpendingRecordModel(title: "과거 소비", amount: 5_000, date: day(-2))
        _ = sut.createSpendingRecord(record)
        let afterCreateD0 = carrySum(day(0))

        _ = sut.deleteSpendingRecord(id: record.id)

        XCTAssertEqual(carrySum(day(0)), afterCreateD0 + 5_000)
    }

    // 과거 날짜 소비의 "금액 수정"도 이후 날 이월에 반영된다
    func testUpdate_pastSpendAmount_propagatesWithoutManualRecalc() {
        setup(.full)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        var record = SpendingRecordModel(title: "과거 소비", amount: 5_000, date: day(-2))
        _ = sut.createSpendingRecord(record)
        let afterCreateD0 = carrySum(day(0))

        record.amount = 8_000
        _ = sut.updateSpendingRecord(record)

        XCTAssertEqual(carrySum(day(0)), afterCreateD0 - 3_000)
    }

    // 소비 날짜를 과거로 "이동"하면 옮긴 날부터 재계산된다 (이전 날짜·새 날짜 중 이른 쪽 기준)
    func testUpdate_moveSpendToEarlierDate_recalcsFromEarlierDay() {
        setup(.full)
        seedDay(day(-3), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        var record = SpendingRecordModel(title: "소비", amount: 5_000, date: day(-1))
        _ = sut.createSpendingRecord(record)
        let d0Before = carrySum(day(0))

        // -1일 → -3일로 이동: 총액은 같으므로 오늘 이월은 변하지 않지만, -2일 이월이 5,000 줄어야 한다
        let d2Before = carrySum(day(-2))
        record.date = day(-3)
        _ = sut.updateSpendingRecord(record)

        XCTAssertEqual(carrySum(day(-2)), d2Before - 5_000)
        XCTAssertEqual(carrySum(day(0)), d0Before)
    }

    // 분리 모드: 과거 소비 추가 시 풀 적립도 자동 재계산된다
    func testSeparate_createPastSpend_recomputesPool() {
        setup(.separate)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let poolBefore = sut.carryOverPoolBalance()

        _ = sut.createSpendingRecord(SpendingRecordModel(title: "과거 소비", amount: 5_000, date: day(-2)))

        XCTAssertEqual(sut.carryOverPoolBalance(), poolBefore - 5_000)
    }

    // 분리 모드에서 이미 인출한 뒤 과거 소비를 추가하면 풀 잔액이 음수가 될 수 있다.
    // 원장은 실제 있었던 일을 그대로 남기고(클램프하지 않는다), 추가 인출만 막는다.
    // 클램프하면 "적립 − 인출 = 잔액"이 깨져 원장을 신뢰할 수 없게 된다.
    func testSeparate_withdrawThenPastSpend_allowsNegativePoolButBlocksFurtherWithdraw() {
        setup(.separate)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let deposited = sut.carryOverPoolBalance()
        XCTAssertTrue(sut.withdrawFromPool(amount: deposited))
        XCTAssertEqual(sut.carryOverPoolBalance(), 0)

        // 적립되었던 날에 소비를 추가하면 그날 적립분이 줄어 잔액이 음수가 된다
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "과거 소비", amount: 5_000, date: day(-2)))

        XCTAssertEqual(sut.carryOverPoolBalance(), -5_000)
        XCTAssertFalse(sut.withdrawFromPool(amount: 1))   // 잔액이 없으므로 추가 인출 불가
    }

    // 오늘 소비는 재계산 대상이 아니므로 이월이 변하지 않는다 (불필요한 연쇄 방지)
    func testCreate_todaySpend_doesNotChangeCarry() {
        setup(.full)
        seedDay(day(-1), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let before = carrySum(day(0))

        _ = sut.createSpendingRecord(SpendingRecordModel(title: "오늘 소비", amount: 3_000, date: day(0)))

        XCTAssertEqual(carrySum(day(0)), before)
    }
}
