//
//  MissingDayBackfillTests.swift
//  GagaeSsi
//
//  앱을 며칠 안 쓴 뒤 들어와도 그 사이 이월이 이어지는지 검증.
//
//  백필(`processDailyBudgets`)은 홈 진입에서만 돌기 때문에, 홈보다 먼저 오늘 일자를
//  만드는 경로(기록 탭의 `fetchOrCreateTodayDailyBudget` 등)를 타면 "오늘까지 이미 처리됨"으로
//  판정돼 중간 날짜가 통째로 비고 이월이 끊긴다.
//

import XCTest
@testable import GagaeSsi

final class MissingDayBackfillTests: XCTestCase {
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
    private func setup(_ mode: CarryOverMode = .full, debtPlanEnabled: Bool = true) {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25,
                                                           fixedCosts: [], carryOverMode: mode,
                                                           debtPlanEnabled: debtPlanEnabled))
    }
    private func seedDay(_ date: Date, available: Int) {
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: available, date: date,
                                                   carryOverSources: [], spendingRecords: []))
    }
    private func carrySum(_ date: Date) -> Int {
        sut.fetchDailyBudgetModel(date: date)?.carryOverSources.map(\.amount).reduce(0, +) ?? 0
    }
    private func exists(_ date: Date) -> Bool {
        sut.fetchDailyBudgetModel(date: date) != nil
    }

    // 홈보다 먼저 오늘 일자가 만들어져도, 그 사이 빈 날들이 채워지고 이월이 이어진다
    func test_오늘이_먼저_만들어져도_사이의_빈_날이_채워진다() {
        setup()
        seedDay(day(-3), available: 20_000)

        // 기록 탭 등 홈이 아닌 경로가 오늘을 먼저 만든다
        _ = sut.fetchOrCreateTodayDailyBudget()

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertTrue(exists(day(-2)), "-2일이 채워져야 한다")
        XCTAssertTrue(exists(day(-1)), "-1일이 채워져야 한다")
        let prevBalance = sut.fetchDailyBudgetModel(date: day(-1))?.todayAvailable ?? 0
        XCTAssertGreaterThan(prevBalance, 0)
        XCTAssertEqual(carrySum(day(0)), prevBalance, "전날 잔액이 오늘로 이월돼야 한다")
    }

    // 빈 날이 없더라도, 다른 경로가 만든 오늘 일자에 전날 잔액이 이월되어야 한다
    func test_오늘이_먼저_만들어져도_전날_잔액이_이월된다() {
        setup()
        seedDay(day(-1), available: 20_000)

        _ = sut.fetchOrCreateTodayDailyBudget()

        XCTAssertEqual(carrySum(day(0)), 20_000, "생성 시점에 전날 잔액이 이월돼야 한다")
    }

    // 과거 소비가 있어 전날이 적자면 음수 이월도 그대로 넘어온다 (과소비 페널티가 제품 의도).
    // 부채 전환은 끄고 본다 — 켜져 있으면 적자가 부채로 옮겨가 상쇄 크레딧이 붙는다.
    func test_전날이_적자면_음수_이월도_넘어온다() {
        setup(debtPlanEnabled: false)
        seedDay(day(-1), available: 20_000)
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: 30_000, date: day(-1)))

        _ = sut.fetchOrCreateTodayDailyBudget()

        XCTAssertEqual(carrySum(day(0)), -10_000)
    }

    // 백필은 여러 번 돌아도 이월을 중복해서 더하지 않는다 (멱등)
    func test_백필은_여러_번_돌아도_이월이_중복되지_않는다() {
        setup()
        seedDay(day(-3), available: 20_000)
        _ = sut.fetchOrCreateTodayDailyBudget()

        sut.processDailyBudgets(upTo: day(0))
        let once = carrySum(day(0))
        sut.processDailyBudgets(upTo: day(0))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(carrySum(day(0)), once)
    }

    // 기록이 전혀 없는 신규 사용자는 백필할 것이 없다
    func test_기록이_없으면_아무것도_만들지_않는다() {
        setup()
        sut.processDailyBudgets(upTo: day(0))
        XCTAssertFalse(exists(day(0)))
        XCTAssertFalse(exists(day(-1)))
    }

    // 분리 모드에서도 빈 날이 채워지며 남은 돈이 풀로 적립된다
    func test_분리모드_빈_날이_채워지며_풀에_적립된다() {
        setup(.separate)
        seedDay(day(-3), available: 20_000)
        _ = sut.fetchOrCreateTodayDailyBudget()

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertTrue(exists(day(-2)))
        XCTAssertGreaterThan(sut.carryOverPoolBalance(), 0, "쓰지 않은 날의 잔액이 풀로 적립된다")
    }
}
