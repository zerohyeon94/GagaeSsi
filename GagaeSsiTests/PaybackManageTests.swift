//
//  PaybackManageTests.swift
//  GagaeSsi
//
//  미확정·기간형 페이백 (생명주기·수령 크레딧) 테스트
//

import XCTest
@testable import GagaeSsi

final class PaybackManageTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        _ = sut.fetchOrCreateTodayDailyBudget()
    }
    override func tearDownWithError() throws { sut = nil }

    private func carrySum() -> Int {
        sut.fetchDailyBudgetModel(date: cal.startOfDay(for: Date()))?
            .carryOverSources.map { $0.amount }.reduce(0, +) ?? 0
    }

    func testCreate_defaults() {
        _ = sut.createPayback(PaybackModel(title: "K-패스 7월", type: .period, estimatedAmount: 160_000))
        let p = sut.fetchPaybacks().first!
        XCTAssertEqual(p.title, "K-패스 7월")
        XCTAssertEqual(p.type, .period)
        XCTAssertEqual(p.status, .estimated)
        XCTAssertEqual(p.estimatedAmount, 160_000)
    }

    func testLifecycle_estimatedToConfirmed() {
        let id = UUID()
        _ = sut.createPayback(PaybackModel(id: id, title: "카드 캐시백", estimatedAmount: 10_000))
        var p = sut.fetchPaybacks().first!
        p.status = .confirmed; p.confirmedAmount = 12_000
        XCTAssertTrue(sut.updatePayback(p))
        let updated = sut.fetchPaybacks().first!
        XCTAssertEqual(updated.status, .confirmed)
        XCTAssertEqual(updated.confirmedAmount, 12_000)
    }

    func testReceive_creditsTodayAndSetsReceived() {
        let id = UUID()
        _ = sut.createPayback(PaybackModel(id: id, title: "K-패스", type: .period, status: .confirmed,
                                           estimatedAmount: 160_000, confirmedAmount: 160_000))
        let before = carrySum()

        XCTAssertTrue(sut.markPaybackReceived(id: id, amount: 160_000))

        let p = sut.fetchPaybacks().first!
        XCTAssertEqual(p.status, .received)
        XCTAssertEqual(p.receivedAmount, 160_000)
        XCTAssertNotNil(p.receivedDate)
        XCTAssertEqual(carrySum(), before + 160_000)     // 오늘 예산에 +크레딧
    }

    func testReceive_guardsDouble() {
        let id = UUID()
        _ = sut.createPayback(PaybackModel(id: id, title: "x", status: .confirmed, confirmedAmount: 5_000))
        XCTAssertTrue(sut.markPaybackReceived(id: id, amount: 5_000))
        XCTAssertFalse(sut.markPaybackReceived(id: id, amount: 5_000))   // 재수령 방지
    }
}
