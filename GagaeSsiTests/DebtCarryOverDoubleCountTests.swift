//
//  DebtCarryOverDoubleCountTests.swift
//  GagaeSsi
//
//  부채(초과분)와 이월 체인이 같은 적자를 이중으로 들고 있지 않은지 검증한다.
//  "아직 갚는 중" 금액이 '초과한 날' 합계와 어긋나던 문제의 회귀 테스트.
//

import XCTest
@testable import GagaeSsi

final class DebtCarryOverDoubleCountTests: XCTestCase {
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
    private func setup() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
    }
    private func seedDay(_ date: Date, available: Int) {
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: available, date: date,
                                                   carryOverSources: [], spendingRecords: []))
    }
    private func addSpend(_ amount: Int, on date: Date) {
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "지출", amount: amount, date: date))
    }
    private func carrySum(_ date: Date) -> Int {
        sut.fetchDailyBudgetModel(date: date)?.carryOverSources.map(\.amount).reduce(0, +) ?? 0
    }
    private func remainingDebt() -> Int { sut.fetchActiveDebt()?.remainingAmount ?? 0 }
    private func overspendTotal() -> Int { OverspendAnalyzer.total(of: sut.fetchOverspendDays(months: 3)) }

    // MARK: - 재현

    /// 부채로 옮긴 적자는 상쇄 크레딧으로 남아, 체인을 다시 계산해도 되살아나지 않는다.
    func test_체인재계산해도_부채로_옮긴_적자가_되살아나지_않는다() {
        setup()
        seedDay(day(-2), available: 20_000)
        addSpend(50_000, on: day(-2))               // -2일 잔액 −30,000

        sut.processDailyBudgets(upTo: day(-1))      // −30,000이 부채로 전환됨
        XCTAssertEqual(remainingDebt(), 30_000)
        XCTAssertEqual(carrySum(day(-1)), 0, "음수 이월과 상쇄 크레딧이 맞물려 순액은 0")

        // 과거 소비를 편집/삭제하면 호출되는 경로
        sut.recalculateCarryOverChain(from: day(-2))

        XCTAssertEqual(remainingDebt(), 30_000, "부채는 그대로")
        XCTAssertEqual(carrySum(day(-1)), 0, "재계산 후에도 적자가 이중으로 잡히지 않는다")
    }

    /// 편집 → 재계산 → 앱 재진입을 반복해도 부채가 불어나지 않는다.
    func test_편집과_재진입을_반복해도_부채가_불어나지_않는다() {
        setup()
        seedDay(day(-2), available: 20_000)
        addSpend(50_000, on: day(-2))               // -2일 잔액 −30,000

        sut.processDailyBudgets(upTo: day(-1))      // 부채 30,000
        let base = sut.fetchDailyBudgetModel(date: day(-1))?.availableAmount ?? 0
        addSpend(base + 50_000, on: day(-1))        // -1일 잔액 −50,000

        sut.processDailyBudgets(upTo: day(0))       // 부채 80,000
        XCTAssertEqual(remainingDebt(), 80_000)
        XCTAssertEqual(overspendTotal(), 80_000, "초과한 날 합계와 부채가 일치해야 한다")

        // 과거 소비 편집 → 체인 재계산 → 앱 재진입 (2회 반복)
        for _ in 0..<2 {
            sut.recalculateCarryOverChain(from: day(-2))
            sut.processDailyBudgets(upTo: day(0))
        }

        XCTAssertEqual(overspendTotal(), 80_000)
        XCTAssertEqual(remainingDebt(), 80_000,
                       "'아직 갚는 중'이 '초과한 날' 합계와 계속 일치해야 한다")
    }

    /// 과거 소비를 줄이면 그날 적자도 줄어야 하고, 부채도 함께 줄어야 한다.
    func test_과거소비를_줄이면_부채도_함께_줄어든다() {
        setup()
        seedDay(day(-2), available: 20_000)
        let record = SpendingRecordModel(title: "지출", amount: 50_000, date: day(-2))
        _ = sut.createSpendingRecord(record)

        sut.processDailyBudgets(upTo: day(-1))      // 부채 30,000
        XCTAssertEqual(remainingDebt(), 30_000)

        var edited = record
        edited.amount = 40_000                      // 적자 −30,000 → −20,000
        _ = sut.updateSpendingRecord(edited)
        sut.recalculateCarryOverChain(from: day(-2))

        XCTAssertEqual(remainingDebt(), 20_000, "부채가 줄어든 적자에 맞춰 조정돼야 한다")
        XCTAssertEqual(overspendTotal(), 20_000)
        XCTAssertEqual(carrySum(day(-1)), 0)
    }

    /// 하루 상환 차감분은 '그날 배정'을 깎지 않는다 — 과거 초과를 갚는 날이
    /// 새 초과일로 다시 잡히면 같은 초과를 두 번 세게 된다.
    func test_상환차감은_초과액에_넣지_않는다() {
        setup()
        seedDay(day(-1), available: 20_000)
        addSpend(50_000, on: day(-1))               // 잔액 −30,000 → 부채 30,000
        sut.processDailyBudgets(upTo: day(0))
        _ = sut.confirmDebtPlan(ratePercent: 20)    // 오늘 상환 차감 발생

        let base = sut.fetchDailyBudgetModel(date: day(0))?.availableAmount ?? 0
        addSpend(base, on: day(0))                  // 기본 예산만큼만 씀 (초과 아님)

        let today = sut.fetchOverspendDays(months: 3).first { cal.isDate($0.date, inSameDayAs: day(0)) }
        XCTAssertNil(today, "기본 예산 안에서 썼으므로 초과한 날이 아니어야 한다")
    }

    /// 저축·투자는 소비가 아니라 '이동'이라 갚아야 할 빚이 되지 않는다.
    func test_저축투자로는_부채가_생기지_않는다() {
        setup()
        seedDay(day(-1), available: 20_000)
        sut.createAssetTransfer(AssetTransferModel(date: day(-1), amount: 50_000, title: "적금"))

        sut.processDailyBudgets(upTo: day(0))

        XCTAssertNil(sut.fetchActiveDebt(), "투자한 날이 빚이 되면 안 된다")
        XCTAssertEqual(overspendTotal(), 0)
        XCTAssertEqual(carrySum(day(0)), -30_000, "다만 음수 이월로는 남아 다음 날 예산을 줄인다")
    }

    /// 같은 날 저축과 과소비가 섞여 있으면 소비 초과분만 부채가 된다.
    func test_저축과_과소비가_섞이면_소비초과분만_부채가_된다() {
        setup()
        seedDay(day(-1), available: 20_000)
        addSpend(35_000, on: day(-1))               // 소비 초과 15,000
        sut.createAssetTransfer(AssetTransferModel(date: day(-1), amount: 50_000, title: "적금"))

        sut.processDailyBudgets(upTo: day(0))       // 잔액 −65,000

        XCTAssertEqual(remainingDebt(), 15_000, "저축 50,000은 빼고 소비 초과분만")
        XCTAssertEqual(overspendTotal(), 15_000, "'초과한 날' 합계와 일치")
        XCTAssertEqual(carrySum(day(0)), -50_000, "저축분은 음수 이월로 남는다")
    }

    /// 저축이 만든 적자는 다음 날에도 부채로 넘어가지 않는다 (시차를 두고 새는지 확인).
    func test_저축이_만든_적자는_다음날에도_부채가_되지_않는다() {
        setup()
        seedDay(day(-2), available: 20_000)
        sut.createAssetTransfer(AssetTransferModel(date: day(-2), amount: 50_000, title: "적금"))

        sut.processDailyBudgets(upTo: day(-1))
        let base = sut.fetchDailyBudgetModel(date: day(-1))?.availableAmount ?? 0
        addSpend(base - 30_000, on: day(-1))        // 배정 안에서 씀 (초과 아님)

        sut.processDailyBudgets(upTo: day(0))
        sut.processDailyBudgets(upTo: day(0))       // 앱 재진입

        XCTAssertNil(sut.fetchActiveDebt(), "이월된 저축 적자가 뒤늦게 빚이 되면 안 된다")
    }

    /// 체인 재계산은 저축이 만든 적자를 빚으로 바꾸지 않는다.
    /// 적자 전액을 부채 크레딧에 맞추면, 과거 소비를 고칠 때마다 저축분이 빚으로 불어난다.
    func test_체인재계산이_저축_적자를_빚으로_만들지_않는다() {
        setup()
        seedDay(day(-2), available: 20_000)
        addSpend(35_000, on: day(-2))               // 소비 초과 15,000
        sut.createAssetTransfer(AssetTransferModel(date: day(-2), amount: 50_000, title: "적금"))

        sut.processDailyBudgets(upTo: day(-1))      // 잔액 −65,000 중 15,000만 부채로
        XCTAssertEqual(remainingDebt(), 15_000)

        sut.recalculateCarryOverChain(from: day(-2))

        XCTAssertEqual(remainingDebt(), 15_000, "저축 50,000이 빚에 얹히면 안 된다")
        XCTAssertEqual(overspendTotal(), 15_000)
    }

    // MARK: - 잔액 보정 (원장 기준 재계산)

    /// 부채 잔액이 원장과 어긋나면 보정이 원장 값으로 덮어쓴다.
    func test_보정이_부채잔액을_원장기준으로_맞춘다() {
        setup()
        seedDay(day(-3), available: 20_000)
        addSpend(50_000, on: day(-3))               // -3일 초과 30,000

        sut.processDailyBudgets(upTo: day(-2))      // 30,000이 부채로 전환됨
        XCTAssertEqual(remainingDebt(), 30_000)

        // -2일은 이미 부채 전환 판정을 지난 날이다. 그 날 초과를 뒤늦게 입력하면
        // 원장의 초과 합계만 늘고 누적값인 부채는 그대로라 둘이 어긋난다.
        let allowance = sut.fetchDailyBudgetModel(date: day(-2))?.availableAmount ?? 0
        XCTAssertGreaterThan(allowance, 0)
        addSpend(allowance + 30_000, on: day(-2))

        XCTAssertEqual(overspendTotal(), 60_000, "초과한 날 합계는 60,000")
        XCTAssertEqual(remainingDebt(), 30_000, "부채는 예전 값 그대로")

        XCTAssertEqual(sut.reconciledDebt()?.remaining, 60_000)
        XCTAssertTrue(sut.reconcileDebtNow())
        XCTAssertEqual(remainingDebt(), 60_000, "보정 후 두 숫자가 일치한다")
    }

    /// 보정은 홈 진입(processDailyBudgets)마다 돌아 어긋난 채로 남지 않는다.
    func test_홈진입만으로_부채잔액이_스스로_맞춰진다() {
        setup()
        seedDay(day(-2), available: 20_000)
        let record = SpendingRecordModel(title: "지출", amount: 50_000, date: day(-2))
        _ = sut.createSpendingRecord(record)

        sut.processDailyBudgets(upTo: day(-1))
        XCTAssertEqual(remainingDebt(), 30_000)

        var edited = record
        edited.amount = 80_000
        _ = sut.updateSpendingRecord(edited)       // 과거 소비 수정 (체인은 여기서 함께 재계산된다)

        sut.processDailyBudgets(upTo: day(0))      // 홈 진입

        XCTAssertEqual(remainingDebt(), 60_000, "보정 호출 없이도 원장 값으로 맞춰진다")
        XCTAssertEqual(overspendTotal(), 60_000)
    }

    /// 이미 갚은 금액은 보정에서 빠진다.
    func test_보정은_이미_갚은_금액을_뺀다() {
        setup()
        seedDay(day(-1), available: 20_000)
        addSpend(50_000, on: day(-1))               // 초과 30,000
        sut.processDailyBudgets(upTo: day(0))
        _ = sut.confirmDebtPlan(ratePercent: 20)    // 오늘 상환 발생

        let repaid = sut.todayDebtRepaymentAmount()
        XCTAssertGreaterThan(repaid, 0)

        XCTAssertEqual(sut.reconciledDebt()?.remaining, 30_000 - repaid,
                       "초과 합계 − 갚은 금액")
        XCTAssertEqual(remainingDebt(), 30_000 - repaid, "이미 맞으므로 보정할 게 없다")
        XCTAssertFalse(sut.reconcileDebtNow(), "값이 같으면 건드리지 않는다")
    }

    /// 부채를 만든 날의 기록이 없으면(예전 버전 적자) 근거가 없어 보정하지 않는다.
    func test_근거가_없으면_보정하지_않는다() {
        setup()
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(0))
        _ = sut.createDailyBudget(DailyBudgetModel(
            availableAmount: base, date: day(0),
            carryOverSources: [CarryOverSourceModel(amount: -300_000, date: day(-1), toDate: day(0))],
            spendingRecords: []))

        sut.processDailyBudgets(upTo: day(0))       // 기존 적자가 부채로 전환된다

        XCTAssertEqual(remainingDebt(), 300_000)
        XCTAssertNil(sut.reconciledDebt(), "전날 기록이 없어 역산 불가")
        XCTAssertEqual(remainingDebt(), 300_000, "함부로 지우지 않는다")
    }

    /// 이월금 인출·환급은 그날 더 쓸 수 있게 된 돈이므로 배정액에 그대로 반영된다.
    func test_이월금_인출은_배정액에_반영된다() {
        setup()
        seedDay(day(-1), available: 20_000)
        _ = sut.fetchOrCreateTodayDailyBudget()
        sut.depositToPool(amount: 100_000, date: day(-1))
        XCTAssertTrue(sut.withdrawFromPool(amount: 30_000))

        let base = sut.fetchDailyBudgetModel(date: day(0))?.availableAmount ?? 0
        addSpend(base + 10_000, on: day(0))         // 인출분 30,000 안에서 씀

        let today = sut.fetchOverspendDays(months: 3).first { cal.isDate($0.date, inSameDayAs: day(0)) }
        XCTAssertNil(today, "인출한 이월금 범위 안에서 썼으므로 초과가 아니다")
    }
}
