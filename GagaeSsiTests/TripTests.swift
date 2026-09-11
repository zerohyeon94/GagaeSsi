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

    // MARK: - 목록·자동 선택 (정산 완료 포함)
    //
    // `settleTrip`이 있어야 정산 완료 상태를 만들 수 있어 Task 5가 아니라 여기서 검증한다.

    func test_목록은_진행_중이_먼저_그다음_정산_완료다() {
        let old = makeTrip("작년", from: -400, to: -398)
        let settled = makeTrip("정산됨", from: -30, to: -28)
        XCTAssertTrue(sut.settleTrip(id: settled.id, actualAmount: 0))
        let recent = makeTrip("최근", from: -3, to: -1)

        XCTAssertEqual(sut.fetchTrips().map(\.id), [recent.id, old.id, settled.id])
    }

    func test_정산_완료_여행은_자동_선택_대상이_아니다() {
        let trip = makeTrip(from: 0, to: 2)
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 0))
        XCTAssertNil(sut.trip(containing: day(1)))
        XCTAssertTrue(sut.fetchActiveTrips().isEmpty)
    }

    // MARK: - 정산

    func test_정산하면_남의_몫이_오늘_예산으로_돌아온다() {
        let trip = makeTrip(participants: 3)
        spend(450_000, participants: 3, tripId: trip.id)
        let before = available()

        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: sut.tripSettlement(for: trip.id).receivable))
        XCTAssertEqual(available(), before + 300_000)
        let settled = sut.fetchTrip(id: trip.id)
        XCTAssertEqual(settled?.status, .settled)
        XCTAssertEqual(settled?.settledAmount, 300_000)
        XCTAssertNotNil(settled?.settledAt)
    }

    func test_실제_수령액을_덮어쓰면_그_금액이_반영된다() {
        let trip = makeTrip(participants: 3)
        spend(450_000, participants: 3, tripId: trip.id)
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 290_000))
        XCTAssertEqual(available(), before + 290_000)
    }

    func test_받을_돈이_없으면_크레딧_없이_상태만_바뀐다() {
        let trip = makeTrip(participants: 3)
        spend(90_000, participants: 3, paidByMe: false, tripId: trip.id)
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 0))
        XCTAssertEqual(available(), before)
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.status, .settled)
        XCTAssertNil(sut.fetchTrip(id: trip.id)?.settlementEntryId)
    }

    func test_이미_정산된_여행은_다시_정산되지_않는다() {
        let trip = makeTrip()
        spend(90_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        let before = available()
        XCTAssertFalse(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        XCTAssertEqual(available(), before)
    }

    func test_지갑_연결_여행은_정산금이_지갑으로_돌아온다() {
        let wallet = seedWallet(500_000)
        let trip = makeTrip(participants: 3, wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertEqual(sut.wishBalance(for: wallet), 50_000)
        let budgetBefore = available()

        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))
        XCTAssertEqual(sut.wishBalance(for: wallet), 350_000, "지갑 잔액이 회복된다")
        XCTAssertEqual(available(), budgetBefore, "예산에는 아무 변화 없다")
        XCTAssertEqual(sut.fetchWishItems().first { $0.id == wallet }?.returnedAmount, 300_000)
    }

    func test_지갑을_먼저_지운_여행은_정산금이_예산으로_온다() {
        let wallet = seedWallet(100_000)
        let trip = makeTrip(participants: 3, wishItemId: wallet)
        spend(90_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.deleteWishItem(id: wallet))
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        XCTAssertEqual(available(), before + 60_000)
    }

    // MARK: - 정산 다시 열기

    func test_예산으로_정산한_여행을_다시_열면_크레딧이_사라진다() {
        let trip = makeTrip()
        spend(90_000, participants: 3, tripId: trip.id)
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        XCTAssertTrue(sut.reopenTrip(id: trip.id))
        XCTAssertEqual(available(), before)
        let reopened = sut.fetchTrip(id: trip.id)
        XCTAssertEqual(reopened?.status, .active)
        XCTAssertNil(reopened?.settledAt)
        XCTAssertEqual(reopened?.settledAmount, 0)
    }

    func test_지갑으로_정산한_여행을_다시_열면_지갑_잔액이_줄어든다() {
        let wallet = seedWallet(500_000)
        let trip = makeTrip(wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))

        XCTAssertTrue(sut.reopenTrip(id: trip.id))
        XCTAssertEqual(sut.wishBalance(for: wallet), 50_000)
        XCTAssertEqual(sut.fetchWishItems().first { $0.id == wallet }?.returnedAmount, 0)
    }

    func test_지갑_크레딧을_이미_써버렸으면_다시_열_수_없다() {
        let wallet = seedWallet(500_000)
        let trip = makeTrip(wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))   // 잔액 35만

        let later = spend(320_000, on: 1)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: later, wishItemId: wallet))   // 잔액 3만

        XCTAssertFalse(sut.reopenTrip(id: trip.id))
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.status, .settled, "아무것도 바뀌지 않는다")
        XCTAssertEqual(sut.wishBalance(for: wallet), 30_000)
    }

    func test_진행_중_여행은_다시_열_수_없다() {
        let trip = makeTrip()
        XCTAssertFalse(sut.reopenTrip(id: trip.id))
    }

    // MARK: - 지갑 생애주기 vs 정산금 (Fix 1~3 회귀)

    /// Fix 1 회귀: 지갑이 목표를 채워 `.purchasable`이어도, 그 안에 든 정산금은 지갑을
    /// 지울 때 사라지지 않고 오늘 예산으로 돌아와야 한다.
    func test_지갑을_지워도_정산으로_돌아온_돈은_예산으로_환급된다() {
        let wallet = seedWallet(500_000)   // 목표 도달로 즉시 .purchasable
        let trip = makeTrip(participants: 3, wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))
        let walletBalance = sut.wishBalance(for: wallet)
        XCTAssertEqual(walletBalance, 350_000, "지갑 잔액 = 저금 80만(오늘치 50만 + 정산 30만) − 소비 45만 (사전 조건)")

        // 지갑을 지우면: 연결된 소비(45만)는 다시 예산 차감 대상이 되고, 오늘치 평소 저금(50만)은
        // 라이브 차감 해제로 자연 환급되고, 정산금(30만)은 Fix 1로 명시 환급된다.
        // 이 세 효과의 합은 정확히 지갑 잔액(35만)과 같다 — "지갑을 지우면 지갑이 쥐고 있던 돈만큼
        // 예산이 늘어난다"는 게 참이어야 한다. 버그가 있으면(정산금 환급 누락) 정확히 30만원만큼 모자란다.
        let before = available()
        XCTAssertTrue(sut.deleteWishItem(id: wallet))
        XCTAssertEqual(available(), before + walletBalance,
                       "지갑이 쥐고 있던 돈(35만, 그중 정산금 30만 포함)은 지갑을 지워도 예산으로 돌아와야 한다")
    }

    /// Fix 2 회귀: 정산 크레딧을 더 이상 찾을 수 없으면(지갑이 지워져 Fix 1로 이미 예산에
    /// 이름 없이 합쳐진 경우) `reopenTrip`은 아무것도 바꾸지 않고 거부해야 한다.
    func test_정산_크레딧을_찾을_수_없으면_다시_열_수_없다() {
        let wallet = seedWallet(500_000)
        let trip = makeTrip(participants: 3, wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))
        XCTAssertTrue(sut.deleteWishItem(id: wallet), "지갑을 지우면 정산 엔트리도 함께 사라진다")

        XCTAssertFalse(sut.reopenTrip(id: trip.id))
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.status, .settled, "상태는 그대로 정산 완료여야 한다")
    }

    /// Fix 3 회귀: 정산으로 돌아온 돈은 지갑이 실제로 쥔 돈(balance)에는 들어가지만
    /// 목표 진행률(progress)·남은 금액(remainingAmount)에는 들어가지 않아야 한다.
    func test_정산으로_돌아온_돈은_목표_진행률에_들어가지_않는다() {
        let wish = WishItemModel(title: "여행자금", targetAmount: 1_000_000, dailySaving: 500_000)
        XCTAssertTrue(sut.createWishItem(wish))
        XCTAssertTrue(sut.activateWish(id: wish.id, dailySaving: 500_000))
        XCTAssertEqual(sut.fetchWishItems().first { $0.id == wish.id }?.savedAmount, 500_000,
                       "오늘치 저금 50만원 (사전 조건)")

        let trip = makeTrip(participants: 3, wishItemId: wish.id)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wish.id))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))

        let item = sut.fetchWishItems().first { $0.id == wish.id }!
        XCTAssertEqual(item.status, .saving, "아직 목표(100만) 미달 — 정산금을 포함해도 80만이라 구매가능이 아니다")
        XCTAssertEqual(item.savedAmount, 800_000)
        XCTAssertEqual(item.balance, 350_000, "지갑이 실제로 쥔 돈(80만 저금 − 45만 소비)엔 정산금이 포함된다")
        XCTAssertEqual(item.progress, 0.5, accuracy: 0.0001, "정산금 30만을 뺀 50만 기준 진행률이어야 한다")
        XCTAssertEqual(item.remainingAmount, 500_000, "정산금은 남은 목표 금액을 줄이지 않는다")
    }

    func test_음수_수령액은_거부된다() {
        let trip = makeTrip()
        XCTAssertFalse(sut.settleTrip(id: trip.id, actualAmount: -1))
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.status, .active)
    }

    /// 정산 크레딧은 `DailyBudget`에 달리지 않는다 — 달리면 평소 저금처럼 그날 예산에서
    /// 빠져버려, "내 몫은 오늘 전액 나가고 남의 몫은 정산 때 한 번에 돌아온다"는 규칙이 깨진다.
    func test_정산_크레딧은_그날_위시_저금으로_잡히지_않는다() {
        let wallet = seedWallet(500_000)   // 목표 도달로 오늘치 저금 50만원이 오늘 예산에 붙는다
        let beforeWishSaving = sut.fetchDailyBudgetModel(date: day(0))?.wishSavingAmount
        let trip = makeTrip(participants: 3, wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))

        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.wishSavingAmount, beforeWishSaving,
                       "정산금 30만원은 DailyBudget.wishSavingEntries에 붙지 않아 오늘 위시 저금액을 그대로 둔다")
    }

    /// Fix 4 회귀: `now:`로 정산일과 재오픈일을 갈라 며칠 뒤 재오픈하는 경로를 재현한다.
    ///
    /// 정산과 재오픈 사이에 `processDailyBudgets`가 며칠치를 채우며 도는데, 이 구간에 초과
    /// 소비가 없으면(이 테스트처럼 매일 예산이 충분하면) 부채 전환이 끼어들 일이 없어
    /// `reopenTrip`이 크레딧을 지우는 것만으로 완전한 역연산이 된다 — `available()`이 정산
    /// 전 값으로 정확히 돌아온다. (초과분이 있어 그 사이에 부채로 전환됐다면 `reopenTrip`은
    /// 크레딧은 지우되 그 부채는 되돌리지 않는다 — `reopenTrip`의 문서 주석에 적어 둔 대로다.)
    func test_며칠_뒤_다시_열어도_예산은_정산_전으로_정확히_돌아온다() {
        let trip = makeTrip(from: -5, to: -3)
        spend(90_000, on: -3, participants: 3, tripId: trip.id)
        let before = available(-3)

        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 60_000, now: day(-3)))
        XCTAssertEqual(available(-3), before + 60_000)

        // 며칠이 지나가는 걸 흉내낸다 — 그사이 초과 소비가 없어 부채 전환은 일어나지 않는다.
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertTrue(sut.reopenTrip(id: trip.id, now: day(0)))
        let reopened = sut.fetchTrip(id: trip.id)
        XCTAssertEqual(reopened?.status, .active)
        XCTAssertNil(reopened?.settledAt)
        XCTAssertEqual(reopened?.settledAmount, 0)
        XCTAssertEqual(available(-3), before, "크레딧이 지워져 정산 전 값으로 정확히 돌아온다")
    }
}
