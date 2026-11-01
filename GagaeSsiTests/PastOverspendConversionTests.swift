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

// MARK: - 날짜 의존성 없는 입력 계산

/// 실행 날짜와 무관하게 같은 경계를 겨누도록 테스트 입력을 만든다.
///
/// 명목 급여일을 곧바로 기간 경계로 가정하면 안 된다 — 주말이면 실효 급여일이 앞으로 당겨져
/// 기간 길이(→ 하루 예산·임계값)와 시작일이 달라진다. 그래서 앱과 같은 `DailyBudgetCalculator`로
/// 실효 급여일을 읽어 입력을 만든다. `today`를 인자로 받아 고정 날짜로도 검증할 수 있다.
enum PastOverspendFixture {
    static let salary = 3_000_000

    static func day(_ offset: Int, from today: Date) -> Date {
        let cal = Calendar.current
        return cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: today)!)
    }

    /// 테스트 구간(day(-5) ~ day(0))에 실효 급여일이 걸리면 부채가 새 기간 예산으로 흡수돼
    /// 실행일에 따라 단정이 깨진다. 오늘에서 13일 떨어뜨려 겹치지 않게 한다
    /// (주말 보정으로 최대 2일 당겨져도 구간과 겹치지 않는다).
    static func safePayday(today: Date) -> Int {
        ((Calendar.current.component(.day, from: today) + 13 - 1) % 28) + 1
    }

    /// '이전 급여 기간' 테스트 입력. 명목 급여일을 어제로 잡되, 경계는 **주말 보정 후 실제 기간 시작일**로 읽는다.
    /// - periodStart: 실효 시작일 (어제가 주말이면 day(-2)·day(-3)으로 당겨진다)
    /// - spendDay: 시작일 −2일 (day(-5) 이상이라 시드 범위 안)
    /// - transferDay: 시작일 −1일 — 초과가 부채로 넘어가는 날, 항상 이전 기간
    static func previousPeriodCase(today: Date) -> (payday: Int, periodStart: Date,
                                                     spendDay: Date, transferDay: Date) {
        let cal = Calendar.current
        let payday = cal.component(.day, from: day(-1, from: today))
        let start = DailyBudgetCalculator.payPeriod(payday: payday, containing: day(0, from: today)).start
        return (payday, start,
                cal.date(byAdding: .day, value: -2, to: start)!,
                cal.date(byAdding: .day, value: -1, to: start)!)
    }

    /// 해당 날짜가 속한 실효 급여 기간의 기본 일일 예산 (고정비·흡수 없음)
    static func dailyBase(payday: Int, on date: Date) -> Int {
        DailyBudgetCalculator.calculate(
            from: BudgetConfigModel(salary: salary, payday: payday, fixedCosts: [],
                                    carryOverMode: .full, debtPlanEnabled: true),
            for: date)
    }
}

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
        PastOverspendFixture.day(offset, from: Date())
    }

    private var safePayday: Int { PastOverspendFixture.safePayday(today: Date()) }

    private func setup(debtPlanEnabled: Bool = true) {
        // 전제: 테스트 구간 전체가 같은 (주말 보정 후) 급여 기간이어야 한다.
        // 깨지면 금액 불일치 대신 '구간에 급여일이 걸렸다'로 바로 드러난다.
        XCTAssertEqual(DailyBudgetCalculator.payPeriod(payday: safePayday, containing: day(-5)).start,
                       DailyBudgetCalculator.payPeriod(payday: safePayday, containing: day(0)).start,
                       "테스트 구간(day(-5)~day(0))에 실효 급여일이 걸렸다")
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
    /// 전환 최소 금액. 적자가 넘어가는 날(`transferDay`)의 기본 예산 기준이다 — 앱의 전환 판정과 같다.
    /// 급여 기간 길이(주말 보정 포함)에 따라 달라지므로 고정 금액으로 가정하지 않는다.
    private func minimumConvertible(transferDay: Date) -> Int {
        let base = sut.fetchDailyBudgetModel(date: transferDay)?.availableAmount ?? 0
        return DebtRepaymentPlan.threshold(dailyBudget: base)
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
        let small = minimumConvertible(transferDay: day(-2)) - 1
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
        // 세 번째는 '작게 넘겼지만 임계값 이상'. 급여 기간이 짧으면 임계값이 1만 원을 넘으므로 고정 금액을 쓰지 않는다.
        let third = max(10_000, minimumConvertible(transferDay: day(-1)))
        addSpend(allowance(day(-4)) + 30_000, on: day(-4))
        addSpend(allowance(day(-3)) + 20_000, on: day(-3))
        addSpend(allowance(day(-2)) + third, on: day(-2))

        XCTAssertEqual(remainingDebt(), 50_000 + third)
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
        // 어제를 명목 급여일로 잡되, 경계는 주말 보정 후 실제 기간 시작일로 읽는다
        let c = PastOverspendFixture.previousPeriodCase(today: Date())
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: c.payday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
        seedDays()
        XCTAssertLessThan(c.transferDay, c.periodStart, "전제: 전환일은 현재 기간 이전이어야 한다")

        addSpend(allowance(c.spendDay) + 40_000, on: c.spendDay)   // 전환일 = 이전 기간

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

// MARK: - 입력 계산의 날짜 경계 회귀 (순수 계산, 고정 날짜)

/// CoreData 테스트는 내부에서 `Date()`를 써서 날짜를 주입할 수 없다.
/// 대신 테스트 입력을 만드는 `PastOverspendFixture`를 고정 날짜로 검증해, 주말·월말 경계에서
/// 입력이 다시 날짜에 의존하지 않는지 확인한다.
final class PastOverspendFixtureBoundaryTests: XCTestCase {
    private let cal = Calendar.current
    private typealias F = PastOverspendFixture

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func label(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// 어느 날짜에 실행하든 지켜져야 하는 입력 불변식
    private func assertInvariants(today: Date, file: StaticString = #filePath, line: UInt = #line) {
        let name = label(today)
        let day0 = F.day(0, from: today)

        // 이전 기간 입력
        let c = F.previousPeriodCase(today: today)
        XCTAssertGreaterThanOrEqual(c.periodStart, F.day(-3, from: today), name, file: file, line: line)
        XCTAssertLessThanOrEqual(c.periodStart, F.day(-1, from: today), name, file: file, line: line)
        XCTAssertGreaterThanOrEqual(c.spendDay, F.day(-5, from: today), "시드 범위 밖 \(name)", file: file, line: line)
        XCTAssertLessThan(c.transferDay, c.periodStart, name, file: file, line: line)
        XCTAssertEqual(c.periodStart,
                       DailyBudgetCalculator.payPeriod(payday: c.payday, containing: day0).start,
                       name, file: file, line: line)

        // safePayday: 테스트 구간이 한 급여 기간 안이고, 임계값이 고정 초과분(2만 원)보다 작다
        let sp = F.safePayday(today: today)
        XCTAssertEqual(DailyBudgetCalculator.payPeriod(payday: sp, containing: F.day(-5, from: today)).start,
                       DailyBudgetCalculator.payPeriod(payday: sp, containing: day0).start,
                       "구간에 급여일이 걸림 \(name)", file: file, line: line)
        for offset in -3...(-1) {
            let base = F.dailyBase(payday: sp, on: F.day(offset, from: today))
            XCTAssertLessThan(DebtRepaymentPlan.threshold(dailyBudget: base), 20_000,
                              name, file: file, line: line)
        }
    }

    // 2026-10-11(일)에 실제로 깨졌던 입력이 왜 깨졌는지 숫자로 남긴다
    func test_2026_10_11_재현_옛_입력이_왜_깨졌나() {
        let today = date(2026, 10, 11)

        // ① 급여일 24(토) → 10/23으로 당겨져 29일 기간, 임계값이 옛 고정 초과분 10,000을 넘는다
        XCTAssertEqual(F.safePayday(today: today), 24)
        let period = DailyBudgetCalculator.payPeriod(payday: 24, containing: today)
        XCTAssertEqual(period.start, date(2026, 9, 24))
        XCTAssertEqual(period.end, date(2026, 10, 23))
        XCTAssertEqual(cal.dateComponents([.day], from: period.start, to: period.end).day, 29)
        let threshold = DebtRepaymentPlan.threshold(dailyBudget: F.dailyBase(payday: 24, on: today))
        XCTAssertEqual(threshold, 10_344)
        XCTAssertGreaterThan(threshold, 10_000)

        // ② 어제 10/10(토)을 급여일로 잡으면 실효 시작일은 10/9 — day(-1)이 아니다
        let c = F.previousPeriodCase(today: today)
        XCTAssertEqual(c.payday, 10)
        XCTAssertEqual(c.periodStart, date(2026, 10, 9))
        XCTAssertNotEqual(c.periodStart, F.day(-1, from: today))
        XCTAssertEqual(c.spendDay, date(2026, 10, 7))
        XCTAssertEqual(c.transferDay, date(2026, 10, 8))
    }

    // 주말·월말 경계 — 기대 시작일을 하드코딩해 계산기와 독립적으로도 확인한다
    func test_주말_월말_경계_사례() {
        let cases: [(today: Date, start: Date)] = [
            (date(2026, 10, 11), date(2026, 10, 9)),   // 어제 토 → day(-2)
            (date(2026, 10, 12), date(2026, 10, 9)),   // 어제 일 → day(-3)
            (date(2026, 11, 2), date(2026, 10, 30)),   // 어제 11/1(일) → 달을 거슬러 당겨짐
            (date(2026, 3, 1), date(2026, 2, 27)),     // 어제 2/28(토): 2월 말일 + 주말
            (date(2026, 8, 1), date(2026, 7, 31)),     // 어제 7/31(금): 보정 없음
        ]
        for c in cases {
            XCTAssertEqual(F.previousPeriodCase(today: c.today).periodStart, c.start, label(c.today))
            assertInvariants(today: c.today)
        }
    }

    // 2년 치 매일 — 어느 날 깨졌는지 메시지에 날짜가 남는다
    func test_2년_전수_스윕() {
        var today = date(2026, 1, 1)
        let end = date(2027, 12, 31)
        while today <= end {
            assertInvariants(today: today)
            today = cal.date(byAdding: .day, value: 1, to: today)!
        }
    }
}
