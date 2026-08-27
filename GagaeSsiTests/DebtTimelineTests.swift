//
//  DebtTimelineTests.swift
//  GagaeSsi
//
//  "언제 시작해서 어떻게 갚아왔고 언제 끝났는지" — 부채 하나의 갚기 여정 조회.
//

import XCTest
@testable import GagaeSsi

final class DebtTimelineTests: XCTestCase {
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
    /// 테스트 구간에 급여일이 걸리면 부채가 흡수돼 단정이 실행일에 따라 깨진다
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
    private func allowance(_ date: Date) -> Int {
        guard let budget = sut.fetchDailyBudgetModel(date: date) else { return 0 }
        return OverspendAnalyzer.evaluate(budget).allowance
    }
    private func addSpend(_ amount: Int, on date: Date) {
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: amount, date: date))
    }

    // 초과가 부채로 넘어온 날이 여정의 시작으로 남는다
    func test_초과_전환이_여정에_남는다() {
        setup()
        seedDays()
        addSpend(allowance(day(-3)) + 40_000, on: day(-3))

        let debt = try! XCTUnwrap(sut.fetchActiveDebt())
        let timeline = sut.fetchDebtTimeline(for: debt)

        XCTAssertEqual(timeline.events.count, 1)
        XCTAssertEqual(timeline.events.first?.date, day(-2), "전환은 초과한 날의 다음 날")
        XCTAssertEqual(timeline.events.first?.signedAmount, 40_000)
    }

    // 여러 날 초과 + 상환이 시간순으로 정렬된다
    func test_초과와_상환이_시간순으로_정렬된다() {
        setup()
        seedDays()
        addSpend(allowance(day(-4)) + 30_000, on: day(-4))
        addSpend(allowance(day(-2)) + 20_000, on: day(-2))
        _ = sut.confirmDebtPlan(ratePercent: 20)          // 오늘 상환 1회 발생

        let debt = try! XCTUnwrap(sut.fetchActiveDebt())
        let timeline = sut.fetchDebtTimeline(for: debt)

        let dates = timeline.events.map(\.date)
        XCTAssertEqual(dates, dates.sorted(), "오래된 순이어야 한다")
        XCTAssertTrue(timeline.events.contains { $0.signedAmount == 30_000 })
        XCTAssertTrue(timeline.events.contains { $0.signedAmount == 20_000 })
        XCTAssertTrue(timeline.events.contains { $0.signedAmount < 0 }, "상환 이벤트가 있어야 한다")
    }

    // 같은 날이면 부채가 늘어난 쪽이 먼저 온다
    func test_같은_날이면_초과가_상환보다_먼저() {
        setup()
        seedDays()
        addSpend(allowance(day(-1)) + 40_000, on: day(-1))   // 전환일 = 오늘
        _ = sut.confirmDebtPlan(ratePercent: 20)             // 상환일 = 오늘

        let debt = try! XCTUnwrap(sut.fetchActiveDebt())
        let sameDay = sut.fetchDebtTimeline(for: debt).events.filter { $0.date == day(0) }

        XCTAssertGreaterThanOrEqual(sameDay.count, 2)
        XCTAssertGreaterThan(sameDay[0].signedAmount, 0, "넘긴 것이 먼저")
        XCTAssertLessThan(sameDay[1].signedAmount, 0, "갚은 것이 나중")
    }

    // 완납한 부채도 여정이 남고, 걸린 일수를 구할 수 있다
    func test_완납한_부채의_여정과_소요일() {
        setup()
        seedDays()
        addSpend(allowance(day(-3)) + 40_000, on: day(-3))
        _ = sut.settleDebtImmediately()

        let settled = sut.fetchCompletedDebts()
        XCTAssertEqual(settled.count, 1)

        let timeline = sut.fetchDebtTimeline(for: settled[0])
        XCTAssertTrue(timeline.events.contains { $0.signedAmount == 40_000 }, "초과 전환")
        XCTAssertTrue(timeline.events.contains { $0.signedAmount == -40_000 }, "한 번에 갚기")
        XCTAssertEqual(timeline.elapsedDays(), 3, "-2일 시작 → 오늘 완납 = 3일")
    }

    // 다른 부채의 상환 기록이 섞이지 않는다
    func test_다른_부채의_상환은_섞이지_않는다() {
        setup()
        seedDays()
        addSpend(allowance(day(-4)) + 30_000, on: day(-4))
        _ = sut.settleDebtImmediately()                      // 첫 부채 완납
        addSpend(allowance(day(-2)) + 20_000, on: day(-2))   // 두 번째 부채

        let active = try! XCTUnwrap(sut.fetchActiveDebt())
        let timeline = sut.fetchDebtTimeline(for: active)

        XCTAssertFalse(timeline.events.contains { $0.signedAmount == -30_000 },
                       "이전 부채의 상환이 들어오면 안 된다")
        XCTAssertTrue(timeline.events.contains { $0.signedAmount == 20_000 })
    }
}

// MARK: - 할부로 나누기

extension DebtTimelineTests {

    // 남은 초과분이 할부로 바뀌고 부채는 완납 처리된다
    func test_할부로_전환하면_부채가_완납된다() {
        setup()
        seedDays()
        addSpend(allowance(day(-3)) + 60_000, on: day(-3))
        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, 60_000)

        XCTAssertTrue(sut.convertDebtToInstallment(months: 3))

        XCTAssertNil(sut.fetchActiveDebt(), "부채는 끝난다")
        let installments = sut.fetchInstallments()
        XCTAssertEqual(installments.count, 1)
        XCTAssertEqual(installments[0].totalAmount, 60_000)
        XCTAssertEqual(installments[0].months, 3)
        XCTAssertEqual(installments[0].monthlyAmount, 20_000)
    }

    // 조기 완납과 달리 오늘 예산에서 한 번에 빼지 않는다.
    // 할부가 하루 기본 예산을 조금 낮출 뿐, 60,000이 통째로 빠지면 안 된다.
    func test_할부_전환은_오늘_예산에서_한번에_빼지_않는다() {
        setup()
        seedDays()
        addSpend(allowance(day(-3)) + 60_000, on: day(-3))
        let before = sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable ?? 0

        _ = sut.convertDebtToInstallment(months: 3)

        let repaid = sut.fetchCarryOverSources(date: day(0)).filter { $0.reason == .debtRepay }
        XCTAssertTrue(repaid.isEmpty, "일시 차감 크레딧이 생기면 안 된다")

        let after = sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable ?? 0
        XCTAssertLessThanOrEqual(after, before, "할부만큼 하루 예산이 조금 줄어든다")
        XCTAssertGreaterThan(after, before - 60_000, "한 번에 빠지면 안 된다")
    }

    // 여정에 '할부로 나눔'이 마지막 사건으로 남는다
    func test_할부_전환이_여정에_남는다() {
        setup()
        seedDays()
        addSpend(allowance(day(-3)) + 60_000, on: day(-3))
        _ = sut.convertDebtToInstallment(months: 6)

        let settled = sut.fetchCompletedDebts()
        XCTAssertEqual(settled.count, 1)
        let timeline = sut.fetchDebtTimeline(for: settled[0])

        guard case .repayment(let entry)? = timeline.events.last else {
            return XCTFail("마지막 사건이 상환이어야 한다")
        }
        XCTAssertEqual(entry.source, .installment)
        XCTAssertEqual(entry.amount, 60_000)
    }

    // 갚을 부채가 없으면 할부를 만들지 않는다
    func test_부채가_없으면_할부로_전환하지_않는다() {
        setup()
        seedDays()
        XCTAssertFalse(sut.convertDebtToInstallment(months: 3))
        XCTAssertTrue(sut.fetchInstallments().isEmpty)
    }
}
