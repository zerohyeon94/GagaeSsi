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

    private func setup(debtPlanEnabled: Bool = true, carryOverMode: CarryOverMode = .full) {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [],
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
