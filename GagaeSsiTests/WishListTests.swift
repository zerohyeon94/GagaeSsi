//
//  WishListTests.swift
//  GagaeSsi
//
//  위시리스트 저금(일일 저금·목표 도달·환급·완료) + 희망/필수 테스트
//

import XCTest
@testable import GagaeSsi

final class WishListTests: XCTestCase {
    var sut: CoreDataManager!

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
    }
    override func tearDownWithError() throws { sut = nil }

    @discardableResult
    private func makeWish(_ title: String, target: Int, kind: WishKind = .want) -> WishItemModel {
        let model = WishItemModel(title: title, targetAmount: target, kind: kind)
        XCTAssertTrue(sut.createWishItem(model))
        return sut.fetchWishItems().first { $0.title == title }!
    }

    private func todayBase() -> Int {
        DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: Date())
    }

    // MARK: - 생성/종류
    func testCreateWish_defaultsWaitingAndKind() {
        makeWish("에어팟", target: 100_000, kind: .need)
        let item = sut.fetchWishItems().first!
        XCTAssertEqual(item.status, .waiting)
        XCTAssertEqual(item.kind, .need)
        XCTAssertEqual(item.savedAmount, 0)
    }

    func testUpdateWish_changesKindAndTarget() {
        let w = makeWish("가방", target: 100_000, kind: .want)
        XCTAssertTrue(sut.updateWishItem(id: w.id, title: "명품 가방", targetAmount: 200_000, kind: .need))
        let updated = sut.fetchWishItems().first!
        XCTAssertEqual(updated.title, "명품 가방")
        XCTAssertEqual(updated.targetAmount, 200_000)
        XCTAssertEqual(updated.kind, .need)
    }

    // MARK: - 활성화 & 일일 저금
    func testActivate_savesTodayAndReducesAvailable() {
        let w = makeWish("에어팟", target: 100_000)
        XCTAssertTrue(sut.activateWish(id: w.id, dailySaving: 5_000))

        let model = sut.fetchOrCreateTodayDailyBudget()!
        XCTAssertEqual(model.wishSavingAmount, 5_000)
        XCTAssertEqual(model.todayAvailable, todayBase() - 5_000)

        let active = sut.fetchActiveWishItem()
        XCTAssertEqual(active?.id, w.id)
        XCTAssertEqual(active?.savedAmount, 5_000)
        XCTAssertEqual(active?.status, .saving)
    }

    func testSaving_isIdempotentPerDay() {
        let w = makeWish("에어팟", target: 100_000)
        _ = sut.activateWish(id: w.id, dailySaving: 5_000)
        _ = sut.fetchOrCreateTodayDailyBudget()
        _ = sut.fetchOrCreateTodayDailyBudget()   // 두 번 호출해도 하루 저금은 1회
        XCTAssertEqual(sut.fetchActiveWishItem()?.savedAmount, 5_000)
    }

    func testActivate_secondWhileActive_fails() {
        let a = makeWish("에어팟", target: 100_000)
        let b = makeWish("키보드", target: 80_000)
        XCTAssertTrue(sut.activateWish(id: a.id, dailySaving: 5_000))
        XCTAssertFalse(sut.activateWish(id: b.id, dailySaving: 3_000))  // 1개만 활성
    }

    // MARK: - 목표 도달
    func testSaving_capsAtTargetAndBecomesPurchasable() {
        let w = makeWish("텀블러", target: 3_000)
        _ = sut.activateWish(id: w.id, dailySaving: 5_000)  // 하루 저금 > 목표
        let model = sut.fetchOrCreateTodayDailyBudget()!

        XCTAssertEqual(model.wishSavingAmount, 3_000)  // 남은 금액만 저금
        let item = sut.fetchWishItems().first!
        XCTAssertEqual(item.savedAmount, 3_000)
        XCTAssertEqual(item.status, .purchasable)
    }

    // MARK: - 환급/해지
    func testDeactivate_refundsAndResets() {
        let w = makeWish("에어팟", target: 100_000)
        _ = sut.activateWish(id: w.id, dailySaving: 5_000)
        _ = sut.fetchOrCreateTodayDailyBudget()

        XCTAssertTrue(sut.deactivateWish(id: w.id))
        let item = sut.fetchWishItems().first!
        XCTAssertEqual(item.status, .waiting)
        XCTAssertEqual(item.savedAmount, 0)   // 엔트리 제거로 누적 초기화
        // 오늘 저금분은 엔트리 삭제로 환급 → todayAvailable이 base로 복귀
        let model = sut.fetchOrCreateTodayDailyBudget()!
        XCTAssertEqual(model.wishSavingAmount, 0)
        XCTAssertEqual(model.todayAvailable, todayBase())
    }

    // MARK: - 완료
    func testComplete_setsCompletedWithoutSpending() {
        let w = makeWish("텀블러", target: 3_000)
        _ = sut.activateWish(id: w.id, dailySaving: 5_000)
        _ = sut.fetchOrCreateTodayDailyBudget()  // 구매가능 도달

        XCTAssertTrue(sut.completeWish(id: w.id))
        let item = sut.fetchWishItems().first!
        XCTAssertEqual(item.status, .completed)
        // 소비 기록은 생성되지 않아야 한다 (이중 차감 방지)
        XCTAssertTrue(sut.fetchSpendingRecords(date: Date()).isEmpty)
    }

    // MARK: - 삭제
    func testDeleteActiveWish_refundsAndRemoves() {
        let w = makeWish("에어팟", target: 100_000)
        _ = sut.activateWish(id: w.id, dailySaving: 5_000)
        _ = sut.fetchOrCreateTodayDailyBudget()

        XCTAssertTrue(sut.deleteWishItem(id: w.id))
        XCTAssertTrue(sut.fetchWishItems().isEmpty)
        // 삭제 후 오늘 저금 차감이 사라져 base로 복귀
        XCTAssertEqual(sut.fetchOrCreateTodayDailyBudget()?.todayAvailable, todayBase())
    }
}
