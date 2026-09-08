//
//  TripTests.swift
//  GagaeSsi
//
//  여행 소비는 내 몫만 예산에서 빠지고, 정산 때 남의 몫이 지갑(또는 예산)으로 돌아온다.
//

import XCTest
@testable import GagaeSsi

final class TripTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        setupConfig()
        makeDay(0)
    }
    override func tearDownWithError() throws { sut = nil }

    // MARK: - Helpers

    func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date())!)
    }
    /// 테스트 구간에 급여일이 걸리면 부채 흡수가 끼어들어 실행일에 따라 단정이 깨진다
    private var safePayday: Int {
        ((cal.component(.day, from: Date()) + 13 - 1) % 28) + 1
    }
    private func setupConfig() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: safePayday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
    }
    /// 이월 없이 그날 예산만 만든다 (before/after 차이로만 단정하므로 배정액은 임의)
    func makeDay(_ offset: Int, available: Int = 100_000) {
        guard sut.fetchDailyBudgetModel(date: day(offset)) == nil else { return }
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: available, date: day(offset),
                                                   carryOverSources: [], spendingRecords: []))
    }
    /// 목표를 이미 채운 지갑을 만든다 (WishWalletTests와 같은 방식)
    @discardableResult
    func seedWallet(_ amount: Int, title: String = "제주 여행") -> UUID {
        makeDay(-5)
        let wish = WishItemModel(title: title, targetAmount: amount, dailySaving: amount,
                                 status: .saving, activatedAt: day(-5))
        _ = sut.createWishItem(wish)
        _ = sut.activateWish(id: wish.id, dailySaving: amount)
        sut.processDailyBudgets(upTo: day(0))
        return wish.id
    }
    @discardableResult
    func spend(_ amount: Int, on offset: Int = 0, participants: Int = 1, paidByMe: Bool = true,
               tripId: UUID? = nil, title: String = "지출") -> UUID {
        makeDay(offset)
        let record = SpendingRecordModel(title: title, amount: amount, date: day(offset),
                                         tripId: tripId, participants: participants, paidByMe: paidByMe)
        XCTAssertTrue(sut.createSpendingRecord(record))
        return record.id
    }
    func available(_ offset: Int = 0) -> Int {
        sut.fetchDailyBudgetModel(date: day(offset))?.todayAvailable ?? 0
    }
    func outgoing(_ offset: Int = 0) -> Int {
        guard let budget = sut.fetchDailyBudgetModel(date: day(offset)) else { return 0 }
        return OverspendAnalyzer.evaluate(budget).outgoing
    }

    // MARK: - 예산 차감

    func test_내가_낸_공용_소비는_그날_예산에서_전액_빠진다() {
        let before = available()
        spend(90_000, participants: 3, paidByMe: true)
        XCTAssertEqual(available(), before - 90_000)
    }

    func test_친구가_낸_공용_소비는_내_몫만_빠진다() {
        let before = available()
        spend(90_000, participants: 3, paidByMe: false)
        XCTAssertEqual(available(), before - 30_000)
    }

    func test_초과_판정도_내_몫_기준이다() {
        spend(120_000, participants: 3, paidByMe: false)
        XCTAssertEqual(outgoing(), 40_000, "친구가 낸 소비는 내 몫만 그날 지출로 잡힌다")
        spend(120_000, participants: 3, paidByMe: true)
        XCTAssertEqual(outgoing(), 160_000, "내가 낸 소비는 전액")
    }

    func test_인원을_바꾸면_그날부터_다시_계산된다() {
        let id = spend(90_000, participants: 3, paidByMe: false)
        let before = available()
        var edited = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }!
        edited.participants = 2
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertEqual(available(), before - 15_000, "내 몫이 3만 → 4.5만으로 늘어난 만큼 더 빠진다")
    }

    // MARK: - 지갑

    func test_지갑에_연결한_친구_결제_소비는_내_몫만_지갑에서_빠진다() {
        let wallet = seedWallet(100_000)
        let id = spend(90_000, participants: 3, paidByMe: false)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertEqual(sut.wishBalance(for: wallet), 70_000)
    }

    func test_지갑_잔액_비교는_내_부담액_기준이다() {
        let wallet = seedWallet(50_000)
        let friendPaid = spend(120_000, participants: 3, paidByMe: false)   // 내 부담 4만
        XCTAssertTrue(sut.linkSpendingToWish(recordId: friendPaid, wishItemId: wallet))
        XCTAssertEqual(sut.wishBalance(for: wallet), 10_000)

        let iPaid = spend(120_000, participants: 3, paidByMe: true)         // 내 부담 12만
        XCTAssertFalse(sut.linkSpendingToWish(recordId: iPaid, wishItemId: wallet), "잔액을 넘으면 연결 안 됨")
    }

    func test_지갑_소비의_금액을_올려_잔액을_넘기면_연결이_끊긴다() {
        let wallet = seedWallet(50_000)
        let id = spend(90_000, participants: 3, paidByMe: false)            // 내 부담 3만
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))

        var edited = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }!
        edited.paidByMe = true                                              // 내 부담 9만 > 5만
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertNil(sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }?.wishItemId)
        XCTAssertEqual(sut.wishBalance(for: wallet), 50_000)
    }
}
