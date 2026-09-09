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

    func test_인원을_바꾸면_그날_예산이_다시_계산된다() {
        let id = spend(90_000, participants: 3, paidByMe: false)
        let before = available()
        var edited = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }!
        edited.participants = 2
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertEqual(available(), before - 15_000, "내 몫이 3만 → 4.5만으로 늘어난 만큼 더 빠진다")
    }

    /// 과거 소비를 고치면 이월 체인을 타고 오늘 잔액까지 와야 한다.
    func test_과거_소비의_결제자를_바꾸면_이월이_다시_계산된다() {
        makeDay(-3)
        sut.processDailyBudgets(upTo: day(0))
        let before = available(0)
        var r = SpendingRecordModel(title: "여행", amount: 90_000, date: day(-3),
                                    participants: 3, paidByMe: false)
        XCTAssertTrue(sut.createSpendingRecord(r))
        XCTAssertEqual(available(0), before - 30_000, "친구가 냈으니 내 몫만")

        r.paidByMe = true
        XCTAssertTrue(sut.updateSpendingRecord(r))
        XCTAssertEqual(available(0), before - 90_000, "편집이 이월 체인을 타고 오늘까지 와야 한다")
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
        XCTAssertEqual(sut.wishSpendableLimit(for: wallet, excluding: friendPaid), 50_000,
                       "이미 쓴 내 몫 4만은 되돌려 계산한다")
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

    /// 금액을 올려도 잔액 안이면 연결이 유지돼야 한다.
    /// (연결이 끊기면 그 돈이 예산으로 되돌아와 그날을 초과로 만들고 이월까지 타고 내려간다)
    func test_금액을_올려도_잔액_안이면_연결이_유지된다() {
        let wallet = seedWallet(100_000)
        var record = SpendingRecordModel(title: "여행", amount: 50_000, date: day(0))
        XCTAssertTrue(sut.createSpendingRecord(record))
        XCTAssertTrue(sut.linkSpendingToWish(recordId: record.id, wishItemId: wallet))

        record.amount = 80_000
        XCTAssertTrue(sut.updateSpendingRecord(record))
        XCTAssertEqual(sut.wishSpentAmount(for: wallet), 80_000, "잔액 안이면 지갑에 그대로 붙어 있어야 한다")
        XCTAssertNotNil(sut.fetchSpendingRecords(date: day(0)).first { $0.id == record.id }?.wishItemId)
    }

    // MARK: - 홈 "오늘 소비" 집계 (Task 4 회귀 — HomeViewModel.spent가 budgetedSpending을 쓴다)

    /// 지갑에서 산 위시(예: 여행)는 저금 시점에 이미 예산에서 빠진 돈이라, 홈 "오늘 소비"
    /// (budgetedSpending)에는 잡히지 않아야 한다 — 기록 자체는 지워지지 않고 그대로 남는다.
    /// ₩400,000짜리 위시를 지갑에서 사면 홈 소비가 ₩400,000이 아니라 ₩0으로 보이는 게 의도다.
    func test_지갑에서_산_소비는_그날_budgetedSpending에_잡히지_않는다() {
        let wallet = seedWallet(400_000)
        let id = spend(400_000)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))

        let budget = sut.fetchDailyBudgetModel(date: day(0))
        XCTAssertEqual(budget?.budgetedSpending, 0,
                       "지갑 연결 소비는 이미 예산에서 빠진 돈이라 오늘 소비로 다시 잡히면 안 된다")
        XCTAssertTrue(sut.fetchSpendingRecords(date: day(0)).contains { $0.id == id },
                      "예산에서 빠졌다고 기록 자체가 사라지면 안 된다")
    }

    // MARK: - 최근 평균 소비 (Fix 3 회귀 — recentAverageDailySpending의 예산 렌즈)

    /// 지갑에서 쓴 소비는 저금 시점에 이미 예산에서 빠진 돈이다. 7일 평균에 다시 잡히면
    /// "이대로면 부채가 줄지 않아요" 경고가 지갑으로 쓴 여행비 때문에 잘못 뜬다.
    func test_지갑에서_쓴_소비는_최근_평균_소비에_잡히지_않는다() {
        spend(70_000, on: -1)
        let before = sut.recentAverageDailySpending(days: 7)

        let wallet = seedWallet(600_000)
        let walletSpendId = spend(600_000, on: -2)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: walletSpendId, wishItemId: wallet))

        XCTAssertEqual(sut.recentAverageDailySpending(days: 7), before,
                       "지갑 연결 소비를 추가해도 7일 평균이 바뀌면 안 된다")
    }

    /// 친구가 낸 공용 소비는 내 몫만 예산에서 빠지므로 최근 평균에도 내 몫만 반영돼야 한다.
    func test_친구가_낸_공용_소비는_최근_평균_소비에_내_몫만_반영된다() {
        spend(90_000, on: -1, participants: 3, paidByMe: false)
        XCTAssertEqual(sut.recentAverageDailySpending(days: 7), 30_000 / 7,
                       "90,000을 3명이 나눈 내 몫 30,000만 반영돼야 한다")
    }

    // MARK: - overBudgetDays 회귀 (C2)
    //
    // StatsViewModel은 CoreDataManager.shared를 직접 참조해서 in-memory 테스트 스토어로
    // 갈아끼울 seam이 없다. 그래서 overBudgetDays가 기대는 규칙 자체 —
    // 공용 소비를 내가 대신 낸 날은 예산 렌즈(budgetOutflow)와 소비 렌즈(myShareTotal)의
    // 판정이 실제로 갈린다는 것 — 를 여기서 고정한다.
    func test_공용_소비를_내가_대신_낸_날은_예산_렌즈로만_초과가_잡힌다() {
        let baseDailyBudget = 100_000
        let records = [
            SpendingRecordModel(title: "저녁", amount: 300_000, date: day(0),
                                participants: 4, paidByMe: true),
        ]
        XCTAssertGreaterThan(records.budgetOutflow, baseDailyBudget,
                             "300,000을 전액 결제했으니 예산 렌즈로는 초과다")
        XCTAssertLessThanOrEqual(records.myShareTotal, baseDailyBudget,
                                 "내 몫은 75,000이라 소비 렌즈로는 초과가 아니다 — overBudgetDays가 이 값을 쓰면 안 된다")
    }

    // MARK: - 여행 헬퍼

    @discardableResult
    func makeTrip(_ title: String = "제주", from: Int = 0, to: Int = 2, participants: Int = 3,
                  wishItemId: UUID? = nil) -> TripModel {
        let trip = TripModel(title: title, startDate: day(from), endDate: day(to),
                             defaultParticipants: participants, wishItemId: wishItemId)
        XCTAssertTrue(sut.createTrip(trip))
        return trip
    }

    // MARK: - 여행 CRUD

    func test_여행을_만들고_읽고_고치고_지운다() {
        let trip = makeTrip()
        XCTAssertEqual(sut.fetchTrips().map(\.id), [trip.id])

        XCTAssertTrue(sut.updateTrip(id: trip.id, title: "부산", startDate: trip.startDate,
                                     endDate: trip.endDate, defaultParticipants: 4,
                                     wishItemId: trip.wishItemId))
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.title, "부산")
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.defaultParticipants, 4)

        XCTAssertTrue(sut.deleteTrip(id: trip.id))
        XCTAssertTrue(sut.fetchTrips().isEmpty)
    }

    func test_updateTrip은_없는_id면_false다() {
        XCTAssertFalse(sut.updateTrip(id: UUID(), title: "없음", startDate: day(0), endDate: day(0),
                                      defaultParticipants: 2, wishItemId: nil))
    }

    func test_fetchTrip은_없는_id면_nil이다() {
        XCTAssertNil(sut.fetchTrip(id: UUID()))
    }

    func test_같은_날_시작한_여행은_최근_생성순이다() {
        let first = makeTrip("먼저", from: 0, to: 2)
        let second = makeTrip("나중", from: 0, to: 2)
        XCTAssertEqual(sut.fetchTrips().map(\.id), [second.id, first.id])
    }

    func test_여행에_지갑을_연결해_저장한다() {
        let wallet = seedWallet(100_000)
        let trip = makeTrip(wishItemId: wallet)
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.wishItemId, wallet)
    }

    /// 정산 완료 정렬과 자동 선택 제외는 `settleTrip`이 있어야 검증할 수 있어 Task 6에서
    /// 함께 확인한다. 여기서는 정산이 없는 상태에서 시작일 최근순 정렬과, 정산이 하나도
    /// 없을 때 `fetchActiveTrips`가 `fetchTrips`와 같다는 것만 고정한다.
    func test_진행_중_여행들은_시작일_최근순이고_전부_활성이다() {
        let old = makeTrip("작년", from: -400, to: -398)
        let recent = makeTrip("최근", from: -3, to: -1)
        let mid = makeTrip("중간", from: -30, to: -28)

        XCTAssertEqual(sut.fetchTrips().map(\.id), [recent.id, mid.id, old.id])
        XCTAssertEqual(sut.fetchActiveTrips().map(\.id), sut.fetchTrips().map(\.id))
    }

    func test_소비에_여행을_묶고_여행별로_읽는다() {
        let trip = makeTrip()
        let a = spend(90_000, participants: 3, tripId: trip.id)
        let b = spend(30_000, on: 1, participants: 3, paidByMe: false, tripId: trip.id)
        spend(5_000)   // 여행 아님

        let records = sut.fetchSpendingRecords(tripId: trip.id)
        XCTAssertEqual(records.map(\.id), [a, b], "날짜 오름차순")
        XCTAssertEqual(records.first { $0.id == a }?.participants, 3)
        XCTAssertEqual(records.first { $0.id == b }?.paidByMe, false)
    }

    func test_수정으로_여행_연결을_바꿀_수_있다() {
        let trip = makeTrip()
        let id = spend(50_000)
        var edited = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }!
        edited.tripId = trip.id; edited.participants = 2
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertEqual(sut.fetchSpendingRecords(tripId: trip.id).map(\.id), [id])

        edited.tripId = nil
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertTrue(sut.fetchSpendingRecords(tripId: trip.id).isEmpty)
    }

    func test_여행을_지워도_소비와_예산_영향은_남는다() {
        let trip = makeTrip()
        let id = spend(90_000, participants: 3, paidByMe: false, tripId: trip.id)
        let before = available()

        XCTAssertTrue(sut.deleteTrip(id: trip.id))
        let record = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }
        XCTAssertNotNil(record)
        XCTAssertNil(record?.tripId)
        XCTAssertEqual(record?.participants, 3, "인원·결제자는 그대로")
        XCTAssertEqual(available(), before, "예산 영향 불변")
    }

    // MARK: - 날짜로 여행 찾기

    func test_기간에_드는_진행_중_여행이_하나면_그걸_준다() {
        let trip = makeTrip(from: 0, to: 2)
        XCTAssertEqual(sut.trip(containing: day(1))?.id, trip.id)
        XCTAssertNil(sut.trip(containing: day(3)))
    }

    func test_기간이_겹치는_여행이_둘이면_고르지_않는다() {
        makeTrip("A", from: 0, to: 2)
        makeTrip("B", from: 1, to: 3)
        XCTAssertNil(sut.trip(containing: day(1)))
    }

    // MARK: - 집계

    func test_여행_집계는_사용자_예시와_같다() {
        let trip = makeTrip(participants: 3)
        spend(100_000, participants: 3, tripId: trip.id)
        spend(200_000, participants: 3, tripId: trip.id)
        spend(150_000, on: 1, participants: 3, tripId: trip.id)

        let s = sut.tripSettlement(for: trip.id)
        XCTAssertEqual(s.perPersonSpending, 150_000)
        XCTAssertEqual(s.paidByMeTotal, 450_000)
        // 10만·20만은 3으로 나누어떨어지지 않아 항목별 버림의 나머지가 여기 붙는다
        XCTAssertEqual(s.receivable, 300_001)
    }
}
