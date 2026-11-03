//
//  CombinedScenarioTests.swift
//  GagaeSsi
//
//  여러 기능이 한 기간에 동시에 걸린 상태를 실사용 순서대로 흘려본다 (#27).
//
//  기능별 테스트는 각자 통과하지만, 위시 지갑 · 여행 분담 · 며칠 미실행 백필 · 급여일 통과가
//  한 장부 위에서 겹칠 때 이월 체인이 이어지는지는 따로 보지 않았다. 실기기 검증 전에
//  자동으로 잡을 수 있는 부분을 여기서 잡는다.
//

import XCTest
@testable import GagaeSsi

final class CombinedScenarioTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current
    private var now: Date!

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        now = Date()
    }
    override func tearDownWithError() throws { sut = nil }

    private func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: now)!)
    }
    private func carrySum(_ date: Date) -> Int {
        sut.fetchDailyBudgetModel(date: date)?.carryOverSources.map(\.amount).reduce(0, +) ?? 0
    }
    /// 첫 사용일 — 기록이 하나도 없으면 백필은 아무것도 만들지 않으므로 첫날은 직접 만든다
    private func seedFirstDay(_ date: Date) {
        let base = sut.fetchBudgetConfig().map { DailyBudgetCalculator.calculate(from: $0, for: date) } ?? 0
        XCTAssertTrue(sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: date,
                                                             carryOverSources: [], spendingRecords: [])))
    }
    private func available(_ date: Date) -> Int? {
        sut.fetchDailyBudgetModel(date: date)?.todayAvailable
    }

    /// 지갑 소비 · 여행 분담(내가 냄 / 친구가 냄) · 미실행 구간 · 급여일 통과가 섞여도
    /// 모든 날의 이월이 전날 잔액과 정확히 같다 (3-4 전액 이월).
    ///
    /// 부채 전환은 끈다 — 켜면 급여일 흡수·임계값 전환이 이월을 의도적으로 바꿔 등식이 성립하지 않는다.
    func test_지갑_여행_미실행_급여일이_겹쳐도_이월_체인이_이어진다() throws {
        // 급여일을 미실행 구간 한가운데(-4일)에 둔다. 주말 보정으로 실효 급여일이 ±2일 움직여도 구간 안이다.
        let payday = min(28, cal.component(.day, from: day(-4)))
        XCTAssertTrue(sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: payday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: false)))

        let wish = WishItemModel(title: "여행 지갑", targetAmount: 500_000)
        XCTAssertTrue(sut.createWishItem(wish))
        let trip = TripModel(title: "부산", startDate: day(-9), endDate: day(-8), defaultParticipants: 3)
        XCTAssertTrue(sut.createTrip(trip))

        // -10일: 앱을 처음 쓰기 시작
        seedFirstDay(day(-10))
        XCTAssertTrue(sut.createSpendingRecord(SpendingRecordModel(title: "점심", amount: 9_000, date: day(-10))))

        // -9일: 여행 첫날 — 친구가 낸 3인 저녁(내 몫만 예산에서)
        sut.processDailyBudgets(upTo: day(-9))
        XCTAssertTrue(sut.createSpendingRecord(SpendingRecordModel(
            title: "저녁", amount: 30_000, date: day(-9), tripId: trip.id, participants: 3, paidByMe: false)))

        // -8일: 내가 낸 2인 숙소(전액이 예산에서) + 기념품
        sut.processDailyBudgets(upTo: day(-8))
        XCTAssertTrue(sut.createSpendingRecord(SpendingRecordModel(
            title: "숙소", amount: 40_000, date: day(-8), tripId: trip.id, participants: 2, paidByMe: true)))
        let souvenir = SpendingRecordModel(title: "기념품", amount: 20_000, date: day(-8))
        XCTAssertTrue(sut.createSpendingRecord(souvenir))

        // -7일 ~ -1일: 앱을 열지 않음 (급여일 포함). 오늘 열면 한꺼번에 채워진다.
        sut.processDailyBudgets(upTo: day(0))

        // 오늘: 지갑에 저금하고, 지난 기념품을 지갑 소비로 돌린다 (그날부터 이월을 다시 잇는다)
        XCTAssertTrue(sut.activateWish(id: wish.id, dailySaving: 20_000))
        XCTAssertTrue(sut.linkSpendingToWish(recordId: souvenir.id, wishItemId: wish.id))

        // 렌즈: 예산 장부는 지갑 소비를 빼고, 친구가 낸 소비는 내 몫만
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(-9))?.budgetedSpending, 10_000)
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(-8))?.budgetedSpending, 40_000)

        // 체인: 모든 날이 존재하고, 이월 = 전날 잔액
        for offset in -9...0 {
            let prev = try XCTUnwrap(available(day(offset - 1)), "\(offset - 1)일 일자가 없다")
            XCTAssertNotNil(sut.fetchDailyBudgetModel(date: day(offset)), "\(offset)일 일자가 없다")
            XCTAssertEqual(carrySum(day(offset)), prev, "\(offset)일 이월이 전날 잔액과 다르다")
        }

        // 백필을 다시 돌려도 체인이 그대로다 (멱등)
        let before = available(day(0))
        sut.processDailyBudgets(upTo: day(0))
        XCTAssertEqual(available(day(0)), before)
    }

    /// 미실행 구간의 과거 날짜 소비를 나중에 추가·삭제해도 그 뒤 날들의 이월이 다시 이어진다.
    func test_미실행_구간에_과거_소비를_넣고_빼도_체인이_다시_이어진다() throws {
        XCTAssertTrue(sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 1, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: false)))
        seedFirstDay(day(-6))
        sut.processDailyBudgets(upTo: day(0))
        let baseline = try XCTUnwrap(available(day(0)))

        let record = SpendingRecordModel(title: "영수증", amount: 12_000, date: day(-4))
        XCTAssertTrue(sut.createSpendingRecord(record))
        sut.processDailyBudgets(upTo: day(0))
        XCTAssertEqual(available(day(0)), baseline - 12_000, "과거 소비가 오늘 잔액까지 이어져야 한다")

        XCTAssertTrue(sut.deleteSpendingRecord(id: record.id))
        sut.processDailyBudgets(upTo: day(0))
        XCTAssertEqual(available(day(0)), baseline, "삭제하면 원래 잔액으로 돌아와야 한다")
    }
}
