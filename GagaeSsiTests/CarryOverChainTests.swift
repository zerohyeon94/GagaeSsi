//
//  CarryOverChainTests.swift
//  GagaeSsi
//
//  과거 소비 수정/삭제 후 이월 체인 재계산 테스트
//

import XCTest
@testable import GagaeSsi

final class CarryOverChainTests: XCTestCase {
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
    private func addSpend(_ amount: Int, on date: Date) {
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "x", amount: amount, date: date))
    }

    // 전액 이월: 과거 소비 추가 → 이후 날 이월이 그만큼 감소하며 전파
    func testFull_pastSpendPropagatesDown() {
        setup(.full)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let beforeD1 = carrySum(day(-1))
        let beforeD0 = carrySum(day(0))

        addSpend(5_000, on: day(-2))            // 과거 소비 추가
        sut.recalculateCarryOverChain(from: day(-2))

        XCTAssertEqual(carrySum(day(-1)), beforeD1 - 5_000)
        XCTAssertEqual(carrySum(day(0)), beforeD0 - 5_000)
    }

    // 분리 모드: 과거 소비 추가 → 풀 적립이 재계산돼 그만큼 감소
    func testSeparate_pastSpendRecomputesPool() {
        setup(.separate)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let poolBefore = sut.carryOverPoolBalance()

        addSpend(5_000, on: day(-2))
        sut.recalculateCarryOverChain(from: day(-2))

        XCTAssertEqual(sut.carryOverPoolBalance(), poolBefore - 5_000)
        XCTAssertEqual(carrySum(day(0)), 0)      // 분리 모드는 양수 이월 없음
    }

    // 오늘 소비 편집은 이후 날짜가 없어 재계산이 아무 것도 바꾸지 않음
    func testEditToday_noChainChange() {
        setup(.full)
        seedDay(day(-1), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        let before = carrySum(day(0))
        addSpend(3_000, on: day(0))
        sut.recalculateCarryOverChain(from: day(0))
        XCTAssertEqual(carrySum(day(0)), before)   // 오늘 이월(전날→오늘)은 불변
    }
}
