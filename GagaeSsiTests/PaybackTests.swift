//
//  PaybackTests.swift
//  GagaeSsi
//
//  페이백/환급 — 순 지출·환급 받음 크레딧 테스트
//

import XCTest
@testable import GagaeSsi

final class PaybackTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        _ = sut.fetchOrCreateTodayDailyBudget()   // 오늘 DailyBudget 생성
    }
    override func tearDownWithError() throws { sut = nil }

    private func todayModel() -> DailyBudgetModel? {
        sut.fetchDailyBudgetModel(date: cal.startOfDay(for: Date()))
    }
    private func carrySum() -> Int {
        todayModel()?.carryOverSources.map { $0.amount }.reduce(0, +) ?? 0
    }

    func testNetAmount() {
        let m = SpendingRecordModel(title: "지하철", amount: 210_000, date: Date(), expectedPayback: 160_000)
        XCTAssertEqual(m.netAmount, 50_000)
    }

    func testCreate_persistsPaybackFields() {
        let m = SpendingRecordModel(title: "지하철", amount: 210_000, date: Date(), expectedPayback: 160_000)
        XCTAssertTrue(sut.createSpendingRecord(m))
        let fetched = sut.fetchSpendingRecords(date: Date()).first { $0.title == "지하철" }!
        XCTAssertEqual(fetched.expectedPayback, 160_000)
        XCTAssertFalse(fetched.paybackReceived)
    }

    func testReceivePayback_marksReceived_andCreditsToday() {
        let id = UUID()
        _ = sut.createSpendingRecord(SpendingRecordModel(id: id, title: "지하철", amount: 210_000,
                                                         date: Date(), expectedPayback: 160_000))
        let before = carrySum()

        XCTAssertTrue(sut.receivePayback(recordId: id))

        let fetched = sut.fetchSpendingRecords(date: Date()).first { $0.id == id }!
        XCTAssertTrue(fetched.paybackReceived)
        XCTAssertEqual(carrySum(), before + 160_000)   // 오늘 예산에 +크레딧
    }

    func testReceivePayback_guardsDoubleAndZero() {
        let id = UUID()
        _ = sut.createSpendingRecord(SpendingRecordModel(id: id, title: "지하철", amount: 210_000,
                                                         date: Date(), expectedPayback: 160_000))
        XCTAssertTrue(sut.receivePayback(recordId: id))
        XCTAssertFalse(sut.receivePayback(recordId: id))   // 재수령 방지

        let id2 = UUID()
        _ = sut.createSpendingRecord(SpendingRecordModel(id: id2, title: "커피", amount: 4_000, date: Date()))
        XCTAssertFalse(sut.receivePayback(recordId: id2))  // 환급 예정 0
    }
}
