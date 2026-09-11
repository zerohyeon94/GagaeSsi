//
//  PastOverspendConversionTests.swift
//  GagaeSsi
//
//  여행 등으로 며칠 뒤 소비를 소급 입력했을 때, 그날 초과가 부채로 전환돼
//  상환 관리에 들어오는지 검증한다.
//
//  전에는 이월 체인만 다시 계산되고 전환은 일어나지 않아, 과거 초과가 음수 이월로만
//  남아 매일 예산을 갉아먹고 '초과분 상환' 화면에는 잡히지 않았다.
//

import XCTest
@testable import GagaeSsi

final class PastOverspendConversionTests: XCTestCase {
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

    /// 테스트 구간(day(-5) ~ day(0))에 급여일이 걸리면 부채가 새 기간 예산으로 흡수돼
    /// 실행일에 따라 단정이 깨진다. 오늘에서 13일 떨어뜨려 겹치지 않게 한다.
    private var safePayday: Int {
        ((cal.component(.day, from: Date()) + 13 - 1) % 28) + 1
    }

    private func setup(debtPlanEnabled: Bool = true) {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: safePayday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: debtPlanEnabled))
    }

    /// day(-5) ~ day(0)까지 일자를 만들어 둔다 (실제 앱에서 백필이 해두는 상태)
    private func seedDays() {
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 0, date: day(-5),
                                                   carryOverSources: [], spendingRecords: []))
        sut.processDailyBudgets(upTo: day(0))
    }

    private func addSpend(_ amount: Int, on date: Date) {
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: amount, date: date))
    }
    /// 그날 실제로 쓸 수 있었던 금액 (기본 예산 + 아껴서 넘어온 이월).
    /// `availableAmount`만 보면 이월분을 빠뜨려 "초과"를 만들지 못한다.
    private func allowance(_ date: Date) -> Int {
        guard let budget = sut.fetchDailyBudgetModel(date: date) else { return 0 }
        return OverspendAnalyzer.evaluate(budget).allowance
    }
    private func remainingDebt() -> Int { sut.fetchActiveDebt()?.remainingAmount ?? 0 }
    private func transferCredit(_ date: Date) -> Int {
        sut.fetchCarryOverSources(date: date)
            .filter { $0.reason == .debtTransfer }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - 전환

    // 과거 날짜에 크게 초과한 소비를 넣으면 부채로 전환된다
    func test_과거_날짜_초과가_부채로_전환된다() {
        setup()
        seedDays()
        XCTAssertNil(sut.fetchActiveDebt(), "처음엔 부채가 없다")

        let base = allowance(day(-3))
        XCTAssertGreaterThan(base, 0)
        addSpend(base + 40_000, on: day(-3))        // -3일 초과 40,000

        XCTAssertEqual(remainingDebt(), 40_000, "초과분이 부채로 잡힌다")
        XCTAssertEqual(transferCredit(day(-2)), 40_000, "전환 크레딧은 다음 날에 남는다")
    }

    // 새로 만들어진 부채의 시작일은 실제 전환일 (타임라인이 정직해야 한다)
    func test_새_부채의_시작일은_실제_전환일() {
        setup()
        seedDays()
        addSpend(allowance(day(-3)) + 40_000, on: day(-3))

        XCTAssertEqual(sut.fetchActiveDebt().map { cal.startOfDay(for: $0.startedAt) }, day(-2))
    }

    // 활성 부채가 있으면 새 부채를 만들지 않고 합산한다
    func test_활성_부채가_있으면_합산된다() {
        setup()
        seedDays()
        addSpend(allowance(day(-4)) + 30_000, on: day(-4))
        let debtId = sut.fetchActiveDebt()?.id
        XCTAssertEqual(remainingDebt(), 30_000)

        addSpend(allowance(day(-2)) + 20_000, on: day(-2))

        XCTAssertEqual(remainingDebt(), 50_000)
        XCTAssertEqual(sut.fetchActiveDebt()?.id, debtId, "부채는 하나로 유지된다")
    }

    // 임계값(하루 예산 10%) 미만 초과는 전환하지 않고 음수 이월로 남긴다
    func test_임계값_미만_초과는_전환하지_않는다() {
        setup()
        seedDays()
        // 임계값은 적자가 넘어가는 날(day(-2))의 기본 예산 기준이다
        let dayBase = sut.fetchDailyBudgetModel(date: day(-2))?.availableAmount ?? 0
        let small = DebtRepaymentPlan.threshold(dailyBudget: dayBase) - 1
        XCTAssertGreaterThan(small, 0)

        addSpend(allowance(day(-3)) + small, on: day(-3))

        XCTAssertNil(sut.fetchActiveDebt(), "작게 넘긴 날은 빚으로 잡지 않는다")
        XCTAssertEqual(transferCredit(day(-2)), 0)
    }

    // 상환 계획 기능이 꺼져 있으면 전환하지 않는다
    func test_기능이_꺼져_있으면_전환하지_않는다() {
        setup(debtPlanEnabled: false)
        seedDays()
        addSpend(allowance(day(-3)) + 40_000, on: day(-3))

        XCTAssertNil(sut.fetchActiveDebt())
    }

    // 저축·투자가 만든 적자는 초과가 아니므로 전환 대상이 아니다
    func test_저축이_만든_적자는_전환하지_않는다() {
        setup()
        seedDays()
        sut.createAssetTransfer(AssetTransferModel(date: day(-3), amount: allowance(day(-3)) + 40_000,
                                                   title: "적금"))
        sut.recalculateCarryOverChain(from: day(-3))

        XCTAssertNil(sut.fetchActiveDebt(), "모은 돈이 빚이 되면 안 된다")
    }

    // 여러 날을 한꺼번에 소급 입력하면 각 날짜별로 전환되고 합계가 맞는다
    func test_여러_날_소급_입력이_각각_전환된다() {
        setup()
        seedDays()
        addSpend(allowance(day(-4)) + 30_000, on: day(-4))
        addSpend(allowance(day(-3)) + 20_000, on: day(-3))
        addSpend(allowance(day(-2)) + 10_000, on: day(-2))

        XCTAssertEqual(remainingDebt(), 60_000)
    }

    // 같은 날을 여러 번 고쳐도 이중으로 합산되지 않는다 (크레딧 조정 경로)
    func test_반복_수정해도_이중_합산되지_않는다() {
        setup()
        seedDays()
        var record = SpendingRecordModel(title: "지출", amount: allowance(day(-3)) + 40_000,
                                         date: day(-3))
        _ = sut.createSpendingRecord(record)
        XCTAssertEqual(remainingDebt(), 40_000)

        record.amount += 10_000
        _ = sut.updateSpendingRecord(record)
        XCTAssertEqual(remainingDebt(), 50_000, "차액만 반영된다")

        record.amount -= 30_000
        _ = sut.updateSpendingRecord(record)
        XCTAssertEqual(remainingDebt(), 20_000)
    }

    // 소급 입력한 소비를 지우면 부채도 함께 사라진다
    func test_소비를_지우면_부채도_줄어든다() {
        setup()
        seedDays()
        let record = SpendingRecordModel(title: "지출", amount: allowance(day(-3)) + 40_000,
                                         date: day(-3))
        _ = sut.createSpendingRecord(record)
        XCTAssertEqual(remainingDebt(), 40_000)

        _ = sut.deleteSpendingRecord(id: record.id)

        XCTAssertEqual(remainingDebt(), 0)
    }

    // 이전 급여 기간의 초과는 이미 정산됐으므로 뒤늦게 넣어도 빚이 되지 않는다
    func test_이전_급여_기간의_초과는_전환하지_않는다() {
        // 어제가 급여일이 되도록 잡으면 day(-2)는 이전 기간이다
        let yesterday = cal.component(.day, from: day(-1))
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: yesterday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
        seedDays()

        addSpend(allowance(day(-3)) + 40_000, on: day(-3))   // 전환일 day(-2) = 이전 기간

        XCTAssertNil(sut.fetchActiveDebt(), "이미 정산된 기간은 다시 빚으로 만들지 않는다")
    }

    // 전환 후에도 부채 잔액과 원장 역산이 일치한다
    func test_전환_후_원장과_잔액이_일치한다() {
        setup()
        seedDays()
        addSpend(allowance(day(-3)) + 40_000, on: day(-3))

        XCTAssertEqual(sut.reconciledDebt()?.remaining, 40_000)
        XCTAssertFalse(sut.reconcileDebtNow(), "이미 맞으므로 보정할 것이 없다")
    }
}
