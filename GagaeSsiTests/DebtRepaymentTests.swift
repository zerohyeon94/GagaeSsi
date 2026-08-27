//
//  DebtRepaymentTests.swift
//  GagaeSsi
//
//  초과 소비 상환 계획 테스트 (순수 계산 + 부채 전환/상환 흐름)
//

import XCTest
@testable import GagaeSsi

final class DebtRepaymentTests: XCTestCase {
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

    /// 이 클래스가 쓰는 구간(day(-4) ~ day(0))에 급여일이 걸리지 않도록 오늘에서 13일 떨어뜨린다.
    /// 급여일이 구간에 들어오면 남은 부채가 새 기간 예산으로 흡수돼(정상 동작) 상환 단정이
    /// 실행일에 따라 깨진다. 급여일 흡수 자체를 검증하는 테스트는 각자 config를 따로 만든다.
    private var safePayday: Int {
        ((cal.component(.day, from: Date()) + 13 - 1) % 28) + 1
    }

    private func setup(debtPlanEnabled: Bool = true, carryOverMode: CarryOverMode = .full) {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: safePayday, fixedCosts: [],
            carryOverMode: carryOverMode, debtPlanEnabled: debtPlanEnabled))
    }

    /// 어제 날짜를 시드해 지정한 잔액을 만든다 (available − spend = 잔액)
    private func seedYesterday(available: Int, spend: Int) {
        let yesterday = day(-1)
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: available, date: yesterday,
                                                   carryOverSources: [], spendingRecords: []))
        if spend > 0 {
            _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: spend, date: yesterday))
        }
    }

    private func todayCarrySum() -> Int {
        sut.fetchDailyBudgetModel(date: day(0))?.carryOverSources.map(\.amount).reduce(0, +) ?? 0
    }

    // MARK: - 순수 계산

    func test_calculate_기본예산5만_20퍼센트_10만원부채() {
        let plan = DebtRepaymentPlan.calculate(debt: 100_000, dailyBudget: 50_000, ratePercent: 20)
        XCTAssertEqual(plan.perDay, 10_000)
        XCTAssertEqual(plan.days, 10)
    }

    func test_calculate_나누어떨어지지_않으면_일수는_올림() {
        // 하루 10,000원 상환, 부채 95,000원 → 마지막 날 5,000원만 갚으므로 10일
        let plan = DebtRepaymentPlan.calculate(debt: 95_000, dailyBudget: 50_000, ratePercent: 20)
        XCTAssertEqual(plan.perDay, 10_000)
        XCTAssertEqual(plan.days, 10)
    }

    func test_calculate_상환액이_0이면_계획불가() {
        // 예산 90원의 10% = 9원... 이 아니라 예산이 아주 작아 내림으로 0이 되는 경우
        let plan = DebtRepaymentPlan.calculate(debt: 10_000, dailyBudget: 9, ratePercent: 10)
        XCTAssertEqual(plan.perDay, 0)
        XCTAssertEqual(plan.days, 0)
    }

    func test_threshold_기본예산의_10퍼센트_원단위_내림() {
        XCTAssertEqual(DebtRepaymentPlan.threshold(dailyBudget: 50_000), 5_000)
        XCTAssertEqual(DebtRepaymentPlan.threshold(dailyBudget: 66_666), 6_666)
        XCTAssertEqual(DebtRepaymentPlan.threshold(dailyBudget: 0), 0)
    }

    func test_isAggressive_40퍼센트_이상만_경고() {
        XCTAssertFalse(DebtRepaymentPlan.isAggressive(ratePercent: 35))
        XCTAssertTrue(DebtRepaymentPlan.isAggressive(ratePercent: 40))
        XCTAssertTrue(DebtRepaymentPlan.isAggressive(ratePercent: 50))
    }

    func test_rateOptions_10부터50까지_5단위() {
        XCTAssertEqual(DebtRepaymentPlan.rateOptions, [10, 15, 20, 25, 30, 35, 40, 45, 50])
    }

    // MARK: - 초과분 → 부채 전환

    func test_임계값_이상_초과하면_이월0_부채생성() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * 2)   // 잔액 = −base (임계값 10% 훨씬 초과)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(todayCarrySum(), 0, "초과분이 부채로 빠져 이월은 0이어야 한다")
        let debt = sut.fetchActiveDebt()
        XCTAssertNotNil(debt)
        XCTAssertEqual(debt?.remainingAmount, base)
        XCTAssertEqual(debt?.isPlanned, false, "계획 확정 전에는 상환이 시작되지 않는다")
    }

    func test_임계값_미만_소액초과는_기존대로_음수이월() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        let smallOver = DebtRepaymentPlan.threshold(dailyBudget: base) - 1
        seedYesterday(available: base, spend: base + smallOver)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(todayCarrySum(), -smallOver)
        XCTAssertNil(sut.fetchActiveDebt(), "소액 초과는 부채로 만들지 않는다")
    }

    func test_기능_OFF면_기존대로_음수이월() {
        setup(debtPlanEnabled: false)
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * 2)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(todayCarrySum(), -base)
        XCTAssertNil(sut.fetchActiveDebt())
    }

    func test_양수잔액은_부채와_무관하게_기존대로_이월() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: 0)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(todayCarrySum(), base)
        XCTAssertNil(sut.fetchActiveDebt())
    }

    // MARK: - 상환

    func test_계획확정하면_오늘부터_상환액_차감_및_원장기록() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * 2)
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertTrue(sut.confirmDebtPlan(ratePercent: 20))

        let expectedPerDay = base * 20 / 100
        XCTAssertEqual(sut.todayDebtRepaymentAmount(), expectedPerDay)
        XCTAssertEqual(todayCarrySum(), -expectedPerDay, "상환액은 그날 음수 CarryOverSource로 기록된다")
        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, base - expectedPerDay)
    }

    func test_같은날_중복상환_없음_멱등성() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * 2)
        sut.processDailyBudgets(upTo: day(0))
        _ = sut.confirmDebtPlan(ratePercent: 20)

        let afterFirst = sut.fetchActiveDebt()?.remainingAmount
        sut.processDailyBudgets(upTo: day(0))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, afterFirst)
        XCTAssertEqual(sut.todayDebtRepaymentAmount(), base * 20 / 100)
    }

    func test_남은부채가_상환액보다_적으면_남은만큼만_갚고_완납() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        let threshold = DebtRepaymentPlan.threshold(dailyBudget: base)
        seedYesterday(available: base, spend: base + threshold)   // 부채 = threshold(=base의 10%)
        sut.processDailyBudgets(upTo: day(0))

        // 50%씩 갚으면 하루 상환액(base*0.5)이 남은 부채(base*0.1)보다 크다
        _ = sut.confirmDebtPlan(ratePercent: 50)

        XCTAssertEqual(sut.todayDebtRepaymentAmount(), threshold, "남은 금액만 차감한다")
        XCTAssertNil(sut.fetchActiveDebt(), "완납되면 활성 부채가 사라진다")
    }

    func test_상환중_재초과하면_부채에_합산되고_비율은_유지() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-2))
        // 그저께 크게 초과 → 어제 부채 생성
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-2),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: base * 2, date: day(-2)))
        sut.processDailyBudgets(upTo: day(-1))
        _ = sut.confirmDebtPlan(ratePercent: 30)
        let afterFirstDebt = sut.fetchActiveDebt()!

        // 어제도 크게 초과 → 오늘 부채에 합산
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출2", amount: base * 2, date: day(-1)))
        sut.processDailyBudgets(upTo: day(0))

        let debt = sut.fetchActiveDebt()
        XCTAssertNotNil(debt)
        XCTAssertEqual(debt?.repayRatePercent, 30, "재초과해도 비율은 유지된다")
        XCTAssertGreaterThan(debt!.originalAmount, afterFirstDebt.originalAmount, "발생 총액이 늘어난다")
        XCTAssertEqual(todayCarrySum(), -(base * 30 / 100), "오늘 이월은 상환액(음수)만 남는다")
    }

    // MARK: - 소급 처리 (앱 미실행일 backfill)

    func test_앱을_며칠_안_열어도_날짜별로_상환이_소급_적용된다() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-4))

        // 4일 전 크게 초과 → 3일 전에 부채 생성 + 계획 확정
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-4),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: base * 3, date: day(-4)))
        sut.processDailyBudgets(upTo: day(-3))
        _ = sut.confirmDebtPlan(ratePercent: 20)

        let perDay = base * 20 / 100
        let afterConfirm = sut.fetchActiveDebt()!.remainingAmount   // 확정일(-3) 1회 상환 반영됨

        // 3일간 앱 미실행 후 오늘 실행 → -2, -1, 0 세 날짜가 한 번에 생성되며 각각 상환
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, afterConfirm - perDay * 3,
                       "미실행 3일치 상환이 각각 소급 적용되어야 한다")
        for offset in -2...0 {
            let carry = sut.fetchDailyBudgetModel(date: day(offset))?
                .carryOverSources.filter { $0.amount < 0 && $0.date == $0.toDate }
                .map(\.amount).reduce(0, +) ?? 0
            XCTAssertEqual(carry, -perDay, "\(offset)일차에 상환 기록이 있어야 한다")
        }
    }

    func test_소급_처리를_반복_호출해도_중복_상환되지_않는다() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-3))
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-3),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: base * 3, date: day(-3)))
        sut.processDailyBudgets(upTo: day(-2))
        _ = sut.confirmDebtPlan(ratePercent: 20)

        sut.processDailyBudgets(upTo: day(0))
        let once = sut.fetchActiveDebt()?.remainingAmount

        sut.processDailyBudgets(upTo: day(0))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, once)
    }

    // MARK: - 조기 완납 / 기능 OFF

    func test_조기완납하면_남은부채가_오늘예산에서_한번에_차감() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * 2)
        sut.processDailyBudgets(upTo: day(0))
        let remaining = sut.fetchActiveDebt()!.remainingAmount

        XCTAssertTrue(sut.settleDebtImmediately())

        XCTAssertNil(sut.fetchActiveDebt())
        XCTAssertEqual(todayCarrySum(), -remaining)
    }

    func test_기능을_끄면_남은부채가_즉시_반영되고_종료() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * 2)
        sut.processDailyBudgets(upTo: day(0))
        let remaining = sut.fetchActiveDebt()!.remainingAmount

        XCTAssertTrue(sut.setDebtPlanEnabled(false))

        XCTAssertNil(sut.fetchActiveDebt())
        XCTAssertEqual(todayCarrySum(), -remaining)
        XCTAssertEqual(sut.fetchBudgetConfig()?.debtPlanEnabled, false)
    }

    // MARK: - 이월 방식과의 관계

    func test_분리모드에서도_초과분은_부채로_전환된다() {
        setup(carryOverMode: .separate)
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * 2)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(todayCarrySum(), 0)
        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, base)
    }

    func test_분리모드_양수잔액은_기존대로_풀로_적립() {
        setup(carryOverMode: .separate)
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: 0)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(todayCarrySum(), 0)
        XCTAssertEqual(sut.carryOverPoolBalance(), base)
        XCTAssertNil(sut.fetchActiveDebt())
    }

    // MARK: - 기존 적자 즉시 전환 (업데이트 직후)

    func test_이미_쌓여있던_음수이월이_앱_진입시_바로_부채로_전환된다() {
        setup(carryOverMode: .separate)
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(0))

        // 상환 계획이 없던 버전에서 넘어온 상태: 오늘 일자에 큰 음수 이월이 이미 박혀 있다
        _ = sut.createDailyBudget(DailyBudgetModel(
            availableAmount: base, date: day(0),
            carryOverSources: [CarryOverSourceModel(amount: -317_730, date: day(-1), toDate: day(0))],
            spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "오늘 소비", amount: 22_000, date: day(0)))

        XCTAssertLessThan(sut.fetchDailyBudgetModel(date: day(0))!.todayAvailable, 0)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, 317_730, "쌓인 적자가 부채로 전환된다")
        XCTAssertEqual(todayCarrySum(), 0, "음수 이월이 제거된다")
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable, base - 22_000,
                       "오늘 예산이 기본 예산 − 오늘 소비로 정상화된다")
    }

    func test_기존적자_전환은_오늘_발생한_크레딧을_건드리지_않는다() {
        setup(carryOverMode: .separate)
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(0))

        _ = sut.createDailyBudget(DailyBudgetModel(
            availableAmount: base, date: day(0),
            carryOverSources: [
                CarryOverSourceModel(amount: -200_000, date: day(-1), toDate: day(0)),  // 전날 이월(전환 대상)
                CarryOverSourceModel(amount: 30_000, date: day(0), toDate: day(0))      // 오늘 인출(보존)
            ],
            spendingRecords: []))

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, 200_000)
        XCTAssertEqual(todayCarrySum(), 30_000, "오늘 발생한 크레딧은 남아야 한다")
    }

    func test_기존적자가_임계값_미만이면_전환하지_않는다() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(0))
        let small = -(DebtRepaymentPlan.threshold(dailyBudget: base) - 1)

        _ = sut.createDailyBudget(DailyBudgetModel(
            availableAmount: base, date: day(0),
            carryOverSources: [CarryOverSourceModel(amount: small, date: day(-1), toDate: day(0))],
            spendingRecords: []))

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertNil(sut.fetchActiveDebt())
        XCTAssertEqual(todayCarrySum(), small, "소액은 기존대로 음수 이월로 남는다")
    }

    func test_기존적자_전환은_기능이_꺼져있으면_일어나지_않는다() {
        setup(debtPlanEnabled: false)
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(0))

        _ = sut.createDailyBudget(DailyBudgetModel(
            availableAmount: base, date: day(0),
            carryOverSources: [CarryOverSourceModel(amount: -317_730, date: day(-1), toDate: day(0))],
            spendingRecords: []))

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertNil(sut.fetchActiveDebt())
        XCTAssertEqual(todayCarrySum(), -317_730)
    }

    // MARK: - 급여일 흡수 (부채 무한 지속 차단)

    /// 최근 며칠 중 "실효 급여일이 정확히 그날"인 오프셋을 찾는다.
    /// 실효 급여일은 주말이면 금요일로 당겨지므로, 아무 날이나 급여일이 될 수 없다.
    private func recentPaydayOffset() -> Int? {
        for offset in stride(from: -3, through: -9, by: -1) {
            let d = day(offset)
            let c = cal.dateComponents([.year, .month, .day], from: d)
            let effective = DailyBudgetCalculator.effectivePayday(
                payday: c.day!, year: c.year!, month: c.month!)
            if cal.isDate(effective, inSameDayAs: d) { return offset }
        }
        return nil
    }

    /// 최근 급여일을 기준으로 config를 만들고, 그 전날 큰 초과를 심는다.
    /// - Returns: 급여일 오프셋
    private func seedOverspendBeforeRecentPayday(salary: Int, spendMultiplier: Int = 3) throws -> Int {
        let offset = try XCTUnwrap(recentPaydayOffset(), "최근 9일 내 평일 급여일을 찾지 못함")
        let paydayDom = cal.component(.day, from: day(offset))
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: salary, payday: paydayDom, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))

        let prevBase = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(offset - 1))
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: prevBase, date: day(offset - 1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출",
                                                         amount: prevBase * spendMultiplier,
                                                         date: day(offset - 1)))
        return offset
    }

    func test_급여일에_남은_부채가_새_급여기간_예산으로_흡수된다() throws {
        let paydayOffset = try seedOverspendBeforeRecentPayday(salary: 3_000_000)
        let beforeBase = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(paydayOffset))

        sut.processDailyBudgets(upTo: day(0))

        let config = sut.fetchBudgetConfig()!
        XCTAssertGreaterThan(config.absorbedDebtAmount, 0, "급여일에 부채가 흡수되어야 한다")
        XCTAssertEqual(config.absorbedDebtPeriodStart.map { cal.startOfDay(for: $0) }, day(paydayOffset))
        XCTAssertNil(sut.fetchActiveDebt(), "흡수되면 부채가 종료된다")

        let afterBase = DailyBudgetCalculator.calculate(from: config, for: day(paydayOffset))
        XCTAssertLessThan(afterBase, beforeBase, "흡수한 만큼 하루 예산이 줄어야 한다")
        XCTAssertGreaterThanOrEqual(afterBase, 0, "하루 예산이 음수가 되면 안 된다")
    }

    func test_흡수는_해당_급여기간에만_적용된다() {
        let todayDom = cal.component(.day, from: Date())
        let periodStart = DailyBudgetCalculator.payPeriod(payday: todayDom, containing: day(0)).start
        let config = BudgetConfigModel(
            salary: 3_000_000, payday: todayDom, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true,
            absorbedDebtAmount: 300_000,
            absorbedDebtPeriodStart: periodStart)

        let thisPeriod = DailyBudgetCalculator.calculate(from: config, for: day(0))

        // 다음 급여 기간에는 흡수가 적용되지 않아야 한다
        let nextPeriodDate = DailyBudgetCalculator.payPeriod(payday: todayDom, containing: day(0)).end
        let nextPeriod = DailyBudgetCalculator.calculate(from: config, for: nextPeriodDate)

        XCTAssertLessThan(thisPeriod, nextPeriod, "흡수는 해당 기간에만 적용된다")
    }

    func test_흡수는_기간당_한번만_일어난다_멱등성() throws {
        _ = try seedOverspendBeforeRecentPayday(salary: 3_000_000)

        sut.processDailyBudgets(upTo: day(0))
        let once = sut.fetchBudgetConfig()!.absorbedDebtAmount
        XCTAssertGreaterThan(once, 0)

        sut.processDailyBudgets(upTo: day(0))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchBudgetConfig()!.absorbedDebtAmount, once)
    }

    func test_부채가_한달치보다_크면_감당할_만큼만_흡수하고_나머지는_남긴다() throws {
        // 한 달 배분 가능액을 훨씬 넘는 초과 (기본 예산의 40배 소비)
        let paydayOffset = try seedOverspendBeforeRecentPayday(salary: 1_000_000, spendMultiplier: 40)

        sut.processDailyBudgets(upTo: day(0))

        let config = sut.fetchBudgetConfig()!
        let absorbable = DailyBudgetCalculator.absorbableSalary(from: config, for: day(paydayOffset))
        XCTAssertEqual(config.absorbedDebtAmount, absorbable, "감당 가능한 만큼만 흡수한다")
        XCTAssertNotNil(sut.fetchActiveDebt(), "남은 부채는 다음 급여일로 넘어간다")
        XCTAssertGreaterThanOrEqual(DailyBudgetCalculator.calculate(from: config, for: day(paydayOffset)), 0,
                                    "하루 예산이 음수가 되면 안 된다")
    }

    // MARK: - 모아둔 이월금으로 상환

    /// 풀 → 부채 상환. 오늘 예산은 건드리지 않는다.
    private func seedDebtWithPool(debtMultiplier: Int = 3, pool: Int) -> Int {
        setup(carryOverMode: .separate)
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))
        seedYesterday(available: base, spend: base * debtMultiplier)
        sut.processDailyBudgets(upTo: day(0))
        sut.depositToPool(amount: pool, date: day(0))
        return base
    }

    func test_모아둔_이월금으로_갚으면_풀과_부채가_함께_줄고_오늘예산은_그대로() {
        _ = seedDebtWithPool(pool: 25_760)
        let debtBefore = sut.fetchActiveDebt()!.remainingAmount
        let availableBefore = sut.fetchDailyBudgetModel(date: day(0))!.todayAvailable

        XCTAssertTrue(sut.repayDebtFromPool(amount: 25_760))

        XCTAssertEqual(sut.fetchActiveDebt()?.remainingAmount, debtBefore - 25_760)
        XCTAssertEqual(sut.carryOverPoolBalance(), 0)
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))!.todayAvailable, availableBefore,
                       "오늘 쓸 수 있는 금액은 변하지 않는다")
    }

    func test_풀_상환은_그날_매일상환을_막지_않는다() {
        let base = seedDebtWithPool(pool: 25_760)
        _ = sut.confirmDebtPlan(ratePercent: 20)          // 오늘 매일 상환 1회 발생
        let dailyRepaid = sut.todayDebtRepaymentAmount()
        XCTAssertEqual(dailyRepaid, base * 20 / 100)

        XCTAssertTrue(sut.repayDebtFromPool(amount: 25_760))

        XCTAssertEqual(sut.todayDebtRepaymentAmount(), dailyRepaid,
                       "풀 상환은 '오늘 예산에서 빠진 상환액'에 포함되지 않는다")
        XCTAssertEqual(sut.todayPoolRepaymentAmount(), 25_760)
    }

    func test_풀_잔액이나_남은_부채보다_많이_갚을_수_없다() {
        _ = seedDebtWithPool(pool: 10_000)
        XCTAssertFalse(sut.repayDebtFromPool(amount: 10_001), "풀 잔액 초과")

        let remaining = sut.fetchActiveDebt()!.remainingAmount
        _ = sut.depositToPool(amount: remaining * 2, date: day(0))
        XCTAssertFalse(sut.repayDebtFromPool(amount: remaining + 1), "남은 부채 초과")
    }

    func test_풀로_전액_갚으면_완납_처리된다() {
        _ = seedDebtWithPool(pool: 0)
        let remaining = sut.fetchActiveDebt()!.remainingAmount
        sut.depositToPool(amount: remaining, date: day(0))

        XCTAssertTrue(sut.repayDebtFromPool(amount: remaining))

        XCTAssertNil(sut.fetchActiveDebt(), "완납되면 활성 부채가 사라진다")
        XCTAssertEqual(sut.carryOverPoolBalance(), 0)
    }

    func test_maxRepayableFromPool은_풀과_부채중_작은쪽() {
        _ = seedDebtWithPool(pool: 10_000)
        XCTAssertEqual(sut.maxRepayableFromPool(), 10_000, "풀이 더 적으면 풀 잔액")

        let remaining = sut.fetchActiveDebt()!.remainingAmount
        sut.depositToPool(amount: remaining, date: day(0))
        XCTAssertEqual(sut.maxRepayableFromPool(), remaining, "부채가 더 적으면 남은 부채")
    }

    // MARK: - 급여일 이월금 사용 확인

    func test_풀이_있으면_급여일_흡수를_보류하고_물어본다() throws {
        let paydayOffset = try seedOverspendBeforeRecentPayday(salary: 3_000_000)
        sut.depositToPool(amount: 25_760, date: day(paydayOffset - 1))

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertEqual(sut.fetchBudgetConfig()?.absorbedDebtAmount, 0, "흡수가 보류된다")
        XCTAssertNotNil(sut.fetchActiveDebt(), "부채가 남아 있다")
        XCTAssertTrue(sut.needsPaydayAbsorptionPrompt(), "사용자에게 물어봐야 한다")
    }

    func test_급여일_프롬프트에서_이월금을_쓰면_풀로_먼저_갚고_나머지를_흡수한다() throws {
        let paydayOffset = try seedOverspendBeforeRecentPayday(salary: 3_000_000)
        sut.depositToPool(amount: 25_760, date: day(paydayOffset - 1))
        sut.processDailyBudgets(upTo: day(0))
        let debtBefore = sut.fetchActiveDebt()!.remainingAmount

        XCTAssertTrue(sut.resolvePaydayAbsorption(usingPool: true))

        XCTAssertEqual(sut.carryOverPoolBalance(), 0, "이월금이 상환에 쓰인다")
        XCTAssertEqual(sut.fetchBudgetConfig()?.absorbedDebtAmount, debtBefore - 25_760,
                       "남은 부채만 흡수된다")
        XCTAssertNil(sut.fetchActiveDebt())
        XCTAssertFalse(sut.needsPaydayAbsorptionPrompt())
    }

    func test_급여일_프롬프트에서_이월금을_안쓰면_풀은_보존되고_전액_흡수된다() throws {
        let paydayOffset = try seedOverspendBeforeRecentPayday(salary: 3_000_000)
        sut.depositToPool(amount: 25_760, date: day(paydayOffset - 1))
        sut.processDailyBudgets(upTo: day(0))
        let debtBefore = sut.fetchActiveDebt()!.remainingAmount

        XCTAssertTrue(sut.resolvePaydayAbsorption(usingPool: false))

        XCTAssertEqual(sut.carryOverPoolBalance(), 25_760, "모아둔 돈은 그대로 남는다")
        XCTAssertEqual(sut.fetchBudgetConfig()?.absorbedDebtAmount, debtBefore)
        XCTAssertNil(sut.fetchActiveDebt())
    }

    func test_풀이_없으면_급여일에_묻지_않고_바로_흡수한다() throws {
        _ = try seedOverspendBeforeRecentPayday(salary: 3_000_000)

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertGreaterThan(sut.fetchBudgetConfig()!.absorbedDebtAmount, 0)
        XCTAssertFalse(sut.needsPaydayAbsorptionPrompt())
    }

    // MARK: - 상환 속도 경고

    func test_상환중_쓸수있는_금액은_기본예산에서_상환액을_뺀_값() {
        XCTAssertEqual(DebtRepaymentPlan.spendableWhileRepaying(dailyBudget: 50_000, ratePercent: 20),
                       40_000)
        XCTAssertEqual(DebtRepaymentPlan.spendableWhileRepaying(dailyBudget: 50_000, ratePercent: 50),
                       25_000)
    }

    func test_최근_평균소비가_상환후_금액을_넘으면_경고대상() {
        // 5만원 예산 / 20% 상환 → 하루 4만원까지만 써야 부채가 준다
        XCTAssertFalse(DebtRepaymentPlan.isOffTrack(recentAverageSpending: 35_000,
                                                    dailyBudget: 50_000, ratePercent: 20))
        XCTAssertFalse(DebtRepaymentPlan.isOffTrack(recentAverageSpending: 40_000,
                                                    dailyBudget: 50_000, ratePercent: 20))
        XCTAssertTrue(DebtRepaymentPlan.isOffTrack(recentAverageSpending: 50_000,
                                                   dailyBudget: 50_000, ratePercent: 20),
                      "예산을 다 쓰면 상환액과 상쇄되어 부채가 줄지 않는다")
    }

    func test_얼마나_더_줄여야_하는지_계산() {
        XCTAssertEqual(DebtRepaymentPlan.dailyCutNeeded(recentAverageSpending: 50_000,
                                                        dailyBudget: 50_000, ratePercent: 20),
                       10_000)
        XCTAssertEqual(DebtRepaymentPlan.dailyCutNeeded(recentAverageSpending: 30_000,
                                                        dailyBudget: 50_000, ratePercent: 20),
                       0, "이미 줄고 있으면 0")
    }

    func test_최근_평균소비는_오늘을_제외하고_일수로_나눈다() {
        setup()
        // createSpendingRecord는 그날 DailyBudget이 있어야 저장된다
        for offset in -3...0 {
            _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 50_000, date: day(offset),
                                                       carryOverSources: [], spendingRecords: []))
        }
        for offset in -3...(-1) {
            XCTAssertTrue(sut.createSpendingRecord(
                SpendingRecordModel(title: "지출", amount: 21_000, date: day(offset))))
        }
        // 오늘 소비는 아직 진행 중이라 평균에 넣지 않는다
        XCTAssertTrue(sut.createSpendingRecord(
            SpendingRecordModel(title: "오늘", amount: 999_999, date: day(0))))

        XCTAssertEqual(sut.recentAverageDailySpending(days: 7), 63_000 / 7)
    }

    // MARK: - 팝업 노출 판정

    func test_needsPlanPrompt_미확정이면_true_오늘_미루면_false() {
        let debt = SpendingDebtModel(originalAmount: 100_000, remainingAmount: 100_000, isPlanned: false)
        XCTAssertTrue(debt.needsPlanPrompt())

        var deferred = debt
        deferred.deferredAt = Date()
        XCTAssertFalse(deferred.needsPlanPrompt(), "오늘 미뤘으면 다시 띄우지 않는다")
        XCTAssertTrue(deferred.needsPlanPrompt(on: cal.date(byAdding: .day, value: 1, to: Date())!),
                      "다음 날에는 다시 띄운다")

        var planned = debt
        planned.isPlanned = true
        XCTAssertFalse(planned.needsPlanPrompt())
    }
}
