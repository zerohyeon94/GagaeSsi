//
//  WishWalletTests.swift
//  GagaeSsi
//
//  위시로 모은 돈으로 쓴 소비는 하루 예산에서 다시 빠지지 않아야 한다.
//
//  전에는 여행비를 위시로 모아두고 여행 중 소비를 기록하면 그날 예산에서 또 빠져
//  (이중 차감) 큰 초과 → 부채가 됐다. 모은 돈으로 쓴 건데 빚이 되는 셈이었다.
//

import XCTest
@testable import GagaeSsi

final class WishWalletTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
    }
    override func tearDownWithError() throws { sut = nil }

    // MARK: - Helpers

    private func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date())!)
    }
    /// 테스트 구간에 급여일이 걸리면 부채 흡수가 끼어들어 실행일에 따라 단정이 깨진다
    private var safePayday: Int {
        ((cal.component(.day, from: Date()) + 13 - 1) % 28) + 1
    }
    private func setup() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: safePayday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
    }
    private func seedDays() {
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 0, date: day(-5),
                                                   carryOverSources: [], spendingRecords: []))
        sut.processDailyBudgets(upTo: day(0))
    }

    /// 목표를 이미 채운 "여행 지갑"을 만든다 (저금 엔트리를 직접 심어 모은 돈을 만든다)
    @discardableResult
    private func seedWallet(_ amount: Int, title: String = "제주 여행") -> UUID {
        let wish = WishItemModel(title: title, targetAmount: amount, dailySaving: amount,
                                 status: .saving, activatedAt: day(-5))
        _ = sut.createWishItem(wish)
        _ = sut.activateWish(id: wish.id, dailySaving: amount)
        sut.processDailyBudgets(upTo: day(0))
        return wish.id
    }

    private func addSpend(_ amount: Int, on date: Date, title: String = "지출") -> UUID {
        let record = SpendingRecordModel(title: title, amount: amount, date: date)
        _ = sut.createSpendingRecord(record)
        return record.id
    }
    private func available(_ date: Date) -> Int {
        sut.fetchDailyBudgetModel(date: date)?.todayAvailable ?? 0
    }

    // MARK: - 예산 차감

    // 위시 지갑에 연결한 소비는 그날 예산을 줄이지 않는다
    func test_지갑에_연결한_소비는_예산에서_빠지지_않는다() {
        setup()
        seedDays()
        let wishId = seedWallet(300_000)
        let before = available(day(0))

        let recordId = addSpend(120_000, on: day(0), title: "숙소")
        XCTAssertEqual(available(day(0)), before - 120_000, "연결 전에는 예산에서 빠진다")

        XCTAssertTrue(sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId))

        XCTAssertEqual(available(day(0)), before, "연결하면 예산이 원래대로 돌아온다")
    }

    // 연결을 끊으면 다시 예산에서 빠진다
    func test_연결을_끊으면_다시_예산에서_빠진다() {
        setup()
        seedDays()
        let wishId = seedWallet(300_000)
        let before = available(day(0))
        let recordId = addSpend(120_000, on: day(0))
        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)
        XCTAssertEqual(available(day(0)), before)

        XCTAssertTrue(sut.unlinkSpendingFromWish(recordId: recordId))

        XCTAssertEqual(available(day(0)), before - 120_000)
    }

    // 지갑에서 쓴 날은 '초과한 날'로 잡히지 않는다
    func test_지갑에서_쓴_날은_초과일이_아니다() {
        setup()
        seedDays()
        let wishId = seedWallet(500_000)
        let recordId = addSpend(400_000, on: day(-2), title: "항공권")

        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)

        let overspendDays = sut.fetchOverspendDays(months: 3).map(\.date)
        XCTAssertFalse(overspendDays.contains(day(-2)), "모아둔 돈으로 쓴 날이 초과일이면 안 된다")
    }

    // 모아둔 돈으로 쓴 여행은 부채가 되지 않는다 (이중 차감 회귀)
    func test_지갑에서_쓴_소비는_부채가_되지_않는다() {
        setup()
        seedDays()
        let wishId = seedWallet(500_000)
        let recordId = addSpend(400_000, on: day(-3), title: "여행 경비")

        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)

        XCTAssertNil(sut.fetchActiveDebt(), "모은 돈으로 쓴 게 빚이 되면 안 된다")
    }

    // MARK: - 잔액

    func test_잔액은_모은돈에서_쓴만큼_줄어든다() {
        setup()
        seedDays()
        let wishId = seedWallet(300_000)
        XCTAssertEqual(sut.wishBalance(for: wishId), 300_000)

        let recordId = addSpend(120_000, on: day(0))
        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)

        XCTAssertEqual(sut.wishSpentAmount(for: wishId), 120_000)
        XCTAssertEqual(sut.wishBalance(for: wishId), 180_000)
    }

    // 잔액을 넘는 연결은 거부되고 아무것도 바뀌지 않는다
    func test_잔액을_넘으면_연결되지_않는다() {
        setup()
        seedDays()
        let wishId = seedWallet(100_000)
        let before = available(day(0))
        let recordId = addSpend(150_000, on: day(0))

        XCTAssertFalse(sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId))

        XCTAssertEqual(sut.wishBalance(for: wishId), 100_000, "잔액은 그대로")
        XCTAssertEqual(available(day(0)), before - 150_000, "예산에서는 그대로 빠진다")
    }

    // 잔액이 0이면 더 붙일 수 없다
    func test_잔액이_0이면_더_연결할_수_없다() {
        setup()
        seedDays()
        let wishId = seedWallet(100_000)
        let first = addSpend(100_000, on: day(0))
        XCTAssertTrue(sut.linkSpendingToWish(recordId: first, wishItemId: wishId))
        XCTAssertEqual(sut.wishBalance(for: wishId), 0)

        let second = addSpend(10_000, on: day(0))
        XCTAssertFalse(sut.linkSpendingToWish(recordId: second, wishItemId: wishId))
    }

    // 잔액이 남은 위시만 연결 후보로 나온다
    func test_잔액이_남은_위시만_후보가_된다() {
        setup()
        seedDays()
        let wishId = seedWallet(100_000)
        XCTAssertEqual(sut.fetchSpendableWishItems().map(\.id), [wishId])

        let recordId = addSpend(100_000, on: day(0))
        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)

        XCTAssertTrue(sut.fetchSpendableWishItems().isEmpty, "다 쓴 지갑은 후보에서 빠진다")
    }

    // MARK: - 연동

    // 과거 날짜 소비를 연결하면 그 뒤 날들의 이월이 되살아난다
    func test_과거_소비를_연결하면_이후_이월이_되살아난다() {
        setup()
        seedDays()
        let wishId = seedWallet(300_000)
        let beforeToday = available(day(0))

        let recordId = addSpend(150_000, on: day(-3), title: "여행")
        XCTAssertEqual(available(day(0)), beforeToday - 150_000, "연결 전에는 오늘까지 이월이 줄어든다")

        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)

        XCTAssertEqual(available(day(0)), beforeToday, "연결하면 이후 날 이월이 되돌아온다")
    }

    // 위시를 지우면 연결이 끊겨 소비가 다시 예산 차감 대상이 된다.
    //
    // 이때 저금 엔트리도 함께 사라지므로 **쓰지 않은 잔액은 예산으로 돌아온다**.
    // 순효과 = +잔액(180,000): 안 쓴 돈은 돌려받고, 쓴 120,000은 평소 소비가 된다.
    func test_위시를_지우면_소비가_다시_예산_차감_대상이_된다() {
        setup()
        seedDays()
        let wishId = seedWallet(300_000)
        let linkedToday = available(day(0))
        let recordId = addSpend(120_000, on: day(-2))
        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)
        XCTAssertEqual(available(day(0)), linkedToday)

        XCTAssertTrue(sut.deleteWishItem(id: wishId))

        let budget = try! XCTUnwrap(sut.fetchDailyBudgetModel(date: day(-2)))
        XCTAssertEqual(budget.budgetedSpending, 120_000, "다시 예산에서 빠지는 소비가 된다")
        XCTAssertEqual(sut.fetchSpendingRecords(date: day(-2)).count, 1, "소비 기록 자체는 남는다")
        XCTAssertEqual(available(day(0)), linkedToday + 180_000, "안 쓴 잔액만 예산으로 돌아온다")
    }

    // 금액을 올려 잔액을 넘기면 연결이 끊긴다 (Σ연결소비 ≤ 모은 돈 유지)
    func test_금액을_잔액_넘게_올리면_연결이_끊긴다() {
        setup()
        seedDays()
        let wishId = seedWallet(100_000)
        var record = SpendingRecordModel(title: "여행", amount: 80_000, date: day(0))
        _ = sut.createSpendingRecord(record)
        _ = sut.linkSpendingToWish(recordId: record.id, wishItemId: wishId)
        XCTAssertEqual(sut.wishSpentAmount(for: wishId), 80_000)

        record.amount = 150_000
        _ = sut.updateSpendingRecord(record)

        XCTAssertEqual(sut.wishSpentAmount(for: wishId), 0, "잔액을 넘으면 지갑에서 떨어진다")
        XCTAssertEqual(sut.wishBalance(for: wishId), 100_000)
    }

    // 지갑에서 쓴 소비도 내역·통계에는 그대로 남는다
    func test_지갑_소비도_내역에_남는다() {
        setup()
        seedDays()
        let wishId = seedWallet(300_000)
        let recordId = addSpend(120_000, on: day(0), title: "숙소")
        _ = sut.linkSpendingToWish(recordId: recordId, wishItemId: wishId)

        let records = sut.fetchSpendingRecords(date: day(0))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].title, "숙소")
        XCTAssertEqual(records[0].wishItemId, wishId, "어느 지갑에서 썼는지 남는다")
    }
}
