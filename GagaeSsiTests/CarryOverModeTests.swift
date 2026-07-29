//
//  CarryOverModeTests.swift
//  GagaeSsi
//
//  이월 방식(전액 이월 / 모아둔 이월금 분리) 테스트
//

import XCTest
@testable import GagaeSsi

final class CarryOverModeTests: XCTestCase {
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
    private func base(_ date: Date) -> Int {
        DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: date)
    }
    /// 특정 날짜를 시드한다 (spend>0이면 소비 기록 추가 → 음수 잔액 유도)
    private func seedDay(_ date: Date, availableAmount: Int, spend: Int = 0) {
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: availableAmount, date: date,
                                                   carryOverSources: [], spendingRecords: []))
        if spend > 0 {
            _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: spend, date: date))
        }
    }
    private func carrySum(_ date: Date) -> Int {
        sut.fetchDailyBudgetModel(date: date)?.carryOverSources.map { $0.amount }.reduce(0, +) ?? 0
    }

    // MARK: - 분리 모드
    func testSeparate_positiveLeftover_goesToPool_noCarry() {
        setup(.separate)
        seedDay(day(-1), availableAmount: 20_000)          // 어제 +20,000
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.carryOverPoolBalance(), 20_000)  // 풀에 적립
        XCTAssertEqual(carrySum(day(0)), 0)                 // 오늘 이월 0
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.availableAmount, base(day(0)))
    }

    func testSeparate_negativeLeftover_carriesAsPenalty_noPool() {
        setup(.separate)
        seedDay(day(-1), availableAmount: 10_000, spend: 15_000)  // 어제 -5,000 (과소비)
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.carryOverPoolBalance(), 0)   // 풀 적립 없음
        XCTAssertEqual(carrySum(day(0)), -5_000)        // 페널티 이월
    }

    func testSeparate_poolAccumulatesOverDays() {
        setup(.separate)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))
        // day(-1): 어제(-2) +20,000 적립 / day(0): day(-1) 잔액(base) 적립
        XCTAssertEqual(sut.carryOverPoolBalance(), 20_000 + base(day(-1)))
    }

    // MARK: - 꺼내 쓰기
    func testWithdraw_movesPoolToToday() {
        setup(.separate)
        seedDay(day(-1), availableAmount: 30_000)
        sut.processDailyBudgets(upTo: day(0))
        let before = sut.carryOverPoolBalance()          // 30,000

        XCTAssertTrue(sut.withdrawFromPool(amount: 10_000))
        XCTAssertEqual(sut.carryOverPoolBalance(), before - 10_000)
        XCTAssertEqual(carrySum(day(0)), 10_000)         // 오늘 예산에 +10,000
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable, base(day(0)) + 10_000)
    }

    func testWithdraw_guardsBalance() {
        setup(.separate)
        XCTAssertFalse(sut.withdrawFromPool(amount: 5_000))   // 빈 풀
        seedDay(day(-1), availableAmount: 3_000)
        sut.processDailyBudgets(upTo: day(0))
        XCTAssertFalse(sut.withdrawFromPool(amount: 5_000))   // 잔액 초과
        XCTAssertTrue(sut.withdrawFromPool(amount: 3_000))    // 정확히 잔액
    }

    // MARK: - 전액 이월(기본) 회귀
    func testFull_positiveLeftover_carries_noPool() {
        setup(.full)
        seedDay(day(-1), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.carryOverPoolBalance(), 0)   // 풀 미사용
        XCTAssertEqual(carrySum(day(0)), 20_000)        // 전액 이월
    }

    // MARK: - 모드 전환은 오늘부터
    func testModeSwitch_appliesFromToday() {
        setup(.full)
        seedDay(day(-2), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(-1))          // 어제까지 전액 이월
        XCTAssertEqual(sut.carryOverPoolBalance(), 0)
        XCTAssertEqual(carrySum(day(-1)), 20_000)       // 전액 이월된 상태 보존

        XCTAssertTrue(sut.updateCarryOverMode(.separate))
        sut.processDailyBudgets(upTo: day(0))           // 오늘부터 분리 모드
        XCTAssertGreaterThan(sut.carryOverPoolBalance(), 0)  // 어제 잔액이 풀로
        XCTAssertEqual(carrySum(day(0)), 0)
    }

    // 전환 시 '오늘 이미 넘어온 양수 이월'을 즉시 풀로 옮긴다 (오늘부터 반영)
    func testModeSwitch_sweepsExistingTodayPositiveCarry() {
        setup(.full)
        seedDay(day(-1), availableAmount: 20_000)
        sut.processDailyBudgets(upTo: day(0))           // 오늘 전액 이월 +20,000
        XCTAssertEqual(carrySum(day(0)), 20_000)
        XCTAssertEqual(sut.carryOverPoolBalance(), 0)

        XCTAssertTrue(sut.updateCarryOverMode(.separate))  // 스윕

        XCTAssertEqual(sut.carryOverPoolBalance(), 20_000)  // 풀로 이동
        XCTAssertEqual(carrySum(day(0)), 0)                 // 오늘 이월 제거
    }

    // 전환 시 오늘 음수 이월(과소비 페널티)은 풀로 옮기지 않고 유지
    func testModeSwitch_keepsTodayNegativeCarry() {
        setup(.full)
        seedDay(day(-1), availableAmount: 10_000, spend: 15_000)  // 어제 -5,000
        sut.processDailyBudgets(upTo: day(0))
        XCTAssertEqual(carrySum(day(0)), -5_000)

        XCTAssertTrue(sut.updateCarryOverMode(.separate))

        XCTAssertEqual(sut.carryOverPoolBalance(), 0)   // 음수는 풀 이동 안 함
        XCTAssertEqual(carrySum(day(0)), -5_000)        // 페널티 유지
    }
}
