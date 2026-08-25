//
//  OverspendHistoryTests.swift
//  GagaeSsi
//
//  "언제 초과했는지" 역산 테스트
//

import XCTest
@testable import GagaeSsi

final class OverspendHistoryTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
    }
    override func tearDownWithError() throws { sut = nil }

    private func day(_ o: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: o, to: Date())!)
    }

    // MARK: - 순수 역산 로직

    func test_배정액을_넘긴_날만_초과일로_잡는다() {
        let budgets = [
            DailyBudgetModel(availableAmount: 50_000, date: day(-3),
                             carryOverSources: [], spendingRecords: [
                                SpendingRecordModel(title: "점심", amount: 20_000, date: day(-3))]),
            DailyBudgetModel(availableAmount: 50_000, date: day(-2),
                             carryOverSources: [], spendingRecords: [
                                SpendingRecordModel(title: "쇼핑", amount: 80_000, date: day(-2))]),
        ]

        let days = OverspendAnalyzer.overspendDays(from: budgets)

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].date, day(-2))
        XCTAssertEqual(days[0].overspentAmount, 30_000)
        XCTAssertEqual(days[0].spent, 80_000)
        XCTAssertEqual(days[0].availableThatDay, 50_000)
    }

    func test_아껴서_넘어온_이월은_그날_쓸_수_있는_돈에_포함된다() {
        // 소비가 기본 예산보다 많아도 아껴둔 이월이 넉넉하면 초과가 아니다
        let budget = DailyBudgetModel(
            availableAmount: 50_000, date: day(-1),
            carryOverSources: [CarryOverSourceModel(amount: 100_000, date: day(-2), toDate: day(-1))],
            spendingRecords: [SpendingRecordModel(title: "큰 지출", amount: 120_000, date: day(-1))])

        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget]).isEmpty)
        XCTAssertEqual(OverspendAnalyzer.evaluate(budget).allowance, 150_000)
    }

    /// 핵심 회귀: 적자에 빠진 뒤 조금만 써도 초과일로 잡히면 안 된다.
    /// (실제 제보 — 6,200원 쓴 날이 "258,036원 초과"로 표시됨)
    func test_음수_이월은_그날_과소비로_치지_않는다() {
        let budget = DailyBudgetModel(
            availableAmount: 54_670, date: day(-1),
            carryOverSources: [CarryOverSourceModel(amount: -301_506, date: day(-2), toDate: day(-1))],
            spendingRecords: [SpendingRecordModel(title: "편의점", amount: 6_200, date: day(-1))])

        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget]).isEmpty,
                      "과거 적자를 떠안았을 뿐 그날 과소비한 게 아니다")
        XCTAssertEqual(OverspendAnalyzer.evaluate(budget).allowance, 54_670,
                       "음수 이월은 배정액에서 제외한다")
        XCTAssertEqual(OverspendAnalyzer.evaluate(budget).overspent, 0)
    }

    func test_적자_상태에서도_배정액을_넘기면_초과로_잡힌다() {
        let budget = DailyBudgetModel(
            availableAmount: 54_670, date: day(-1),
            carryOverSources: [CarryOverSourceModel(amount: -258_034, date: day(-2), toDate: day(-1))],
            spendingRecords: [SpendingRecordModel(title: "쇼핑", amount: 131_310, date: day(-1))])

        let days = OverspendAnalyzer.overspendDays(from: [budget])

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].overspentAmount, 131_310 - 54_670)
    }

    /// 인출·환급은 그날 더 쓸 수 있게 된 돈이라 배정액에 더한다.
    /// 초과분 상환은 과거 초과의 결과일 뿐이라 배정액에서 빼지 않는다 —
    /// 빼면 갚는 날마다 이미 목록에 있는 초과를 새 초과로 다시 세게 된다.
    func test_인출은_배정액에_더하고_상환차감은_빼지_않는다() {
        let budget = DailyBudgetModel(
            availableAmount: 50_000, date: day(-1),
            carryOverSources: [
                CarryOverSourceModel(amount: 20_000, date: day(-1), toDate: day(-1),
                                     reason: .poolWithdraw),
                CarryOverSourceModel(amount: -10_000, date: day(-1), toDate: day(-1),
                                     reason: .debtRepay)
            ],
            spendingRecords: [SpendingRecordModel(title: "지출", amount: 55_000, date: day(-1))])

        let evaluation = OverspendAnalyzer.evaluate(budget)
        XCTAssertEqual(evaluation.allowance, 70_000, "50,000 + 인출 20,000 (상환 10,000은 제외)")
        XCTAssertEqual(evaluation.overspent, 0)
    }

    /// 부채로 옮긴 적자는 음수 이월 + 상쇄 크레딧으로 남지만, 둘 다 배정액을 건드리지 않는다.
    func test_부채로_옮긴_적자는_배정액을_건드리지_않는다() {
        let budget = DailyBudgetModel(
            availableAmount: 50_000, date: day(-1),
            carryOverSources: [
                CarryOverSourceModel(amount: -80_000, date: day(-2), toDate: day(-1),
                                     reason: .carryOver),
                CarryOverSourceModel(amount: 80_000, date: day(-1), toDate: day(-1),
                                     reason: .debtTransfer)
            ],
            spendingRecords: [SpendingRecordModel(title: "지출", amount: 55_000, date: day(-1))])

        let evaluation = OverspendAnalyzer.evaluate(budget)
        XCTAssertEqual(evaluation.allowance, 50_000, "기본 예산 그대로")
        XCTAssertEqual(evaluation.overspent, 5_000)
    }

    /// 저금은 쓴 돈이 아니라 모은 돈이라 과소비로 치지 않는다
    func test_위시저금은_초과액에_포함하지_않는다() {
        let budget = DailyBudgetModel(
            availableAmount: 50_000, date: day(-1), carryOverSources: [],
            spendingRecords: [SpendingRecordModel(title: "점심", amount: 48_000, date: day(-1))],
            wishSavingAmount: 5_000)

        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget]).isEmpty,
                      "소비 48,000 < 배정 50,000 — 저금 5,000을 더해 초과로 잡으면 안 된다")
        XCTAssertEqual(OverspendAnalyzer.evaluate(budget).outgoing, 48_000)
    }

    func test_위시저금이_있어도_소비만으로_초과를_판정한다() {
        let budget = DailyBudgetModel(
            availableAmount: 50_000, date: day(-1), carryOverSources: [],
            spendingRecords: [SpendingRecordModel(title: "쇼핑", amount: 70_000, date: day(-1))],
            wishSavingAmount: 5_000)

        let days = OverspendAnalyzer.overspendDays(from: [budget])

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].overspentAmount, 20_000, "70,000 − 50,000 (저금 제외)")
        XCTAssertEqual(days[0].wishSaving, 5_000, "저금액은 참고용으로 함께 보여준다")
    }

    func test_최신순_정렬되고_합계와_최악의날을_구한다() {
        let budgets = (1...3).map { offset in
            DailyBudgetModel(availableAmount: 10_000, date: day(-offset),
                             carryOverSources: [], spendingRecords: [
                                SpendingRecordModel(title: "지출", amount: 10_000 + offset * 1_000,
                                                    date: day(-offset))])
        }

        let days = OverspendAnalyzer.overspendDays(from: budgets)

        XCTAssertEqual(days.map(\.date), [day(-1), day(-2), day(-3)], "최신순")
        XCTAssertEqual(OverspendAnalyzer.total(of: days), 1_000 + 2_000 + 3_000)
        XCTAssertEqual(OverspendAnalyzer.worst(of: days)?.date, day(-3), "가장 크게 넘긴 날")
    }

    func test_임계금액_미만은_무시한다() {
        let budget = DailyBudgetModel(availableAmount: 10_000, date: day(-1),
                                      carryOverSources: [], spendingRecords: [
                                        SpendingRecordModel(title: "지출", amount: 10_050, date: day(-1))])

        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget], minimumAmount: 100).isEmpty)
        XCTAssertEqual(OverspendAnalyzer.overspendDays(from: [budget], minimumAmount: 1).count, 1)
    }

    func test_초과가_없으면_빈배열() {
        let budget = DailyBudgetModel(availableAmount: 50_000, date: day(-1),
                                      carryOverSources: [], spendingRecords: [])
        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget]).isEmpty)
    }

    // MARK: - CoreData 조회

    func test_fetchOverspendDays는_실제_기록에서_초과일을_뽑는다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-5))

        for offset in [-5, -4, -3] {
            _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(offset),
                                                       carryOverSources: [], spendingRecords: []))
        }
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "작은 지출", amount: base / 2, date: day(-5)))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: base * 2, date: day(-4)))

        let days = sut.fetchOverspendDays(months: 3)

        XCTAssertEqual(days.map(\.date), [day(-4)])
        // -5일에 절반만 썼으므로 남은 절반이 -4일로 이월된다 (배정액 = base + base/2).
        // 따라서 base*2를 쓴 -4일의 초과분은 base가 아니라 base/2다.
        XCTAssertEqual(days[0].overspentAmount, base / 2)
    }

    func test_조회_기간_밖의_초과는_제외된다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        let old = cal.date(byAdding: .month, value: -5, to: day(0))!
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 10_000, date: old,
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "옛날 지출", amount: 50_000, date: old))

        XCTAssertTrue(sut.fetchOverspendDays(months: 3).isEmpty)
        XCTAssertEqual(sut.fetchOverspendDays(months: 6).count, 1)
    }

    /// 실제 제보 화면(8일 연속 초과 표시) 재현 — 진짜 넘긴 날만 남아야 한다
    func test_적자가_이어져도_진짜_넘긴_날만_잡힌다() {
        let base = 54_670
        // 7/31에 크게 초과 → 이후 적자가 계속 이월되는 상황
        let spends = [351_180, 6_200, 131_310, 2_480, 4_300, 74_170, 4_100, 141_362]
        var carry = 0
        var budgets: [DailyBudgetModel] = []

        for (index, spend) in spends.enumerated() {
            let date = day(-(spends.count - index))
            let sources = carry == 0 ? []
                : [CarryOverSourceModel(amount: carry,
                                        date: cal.date(byAdding: .day, value: -1, to: date)!,
                                        toDate: date)]
            let budget = DailyBudgetModel(
                availableAmount: base, date: date,
                carryOverSources: sources,
                spendingRecords: [SpendingRecordModel(title: "지출", amount: spend, date: date)])
            budgets.append(budget)
            carry = budget.todayAvailable   // 다음 날로 적자 이월
        }

        let days = OverspendAnalyzer.overspendDays(from: budgets)
        let overspentSpends = days
            .sorted { $0.date < $1.date }
            .map(\.spent)

        XCTAssertEqual(overspentSpends, [351_180, 131_310, 74_170, 141_362],
                       "기본 예산을 넘긴 4일만 잡혀야 한다 (8일 전부가 아니라)")
        XCTAssertEqual(days.count, 4)
    }

    // MARK: - 갚은 내역

    func test_상환내역은_출처별로_최신순_조회된다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [],
            carryOverMode: .separate, debtPlanEnabled: true))
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))

        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: base * 3, date: day(-1)))
        sut.processDailyBudgets(upTo: day(0))
        _ = sut.confirmDebtPlan(ratePercent: 20)      // 오늘 daily 상환 1건
        sut.depositToPool(amount: 10_000, date: day(0))
        _ = sut.repayDebtFromPool(amount: 10_000)     // pool 상환 1건

        let repayments = sut.fetchDebtRepayments(months: 3)

        XCTAssertEqual(repayments.count, 2)
        XCTAssertEqual(Set(repayments.map(\.source)), [.daily, .pool])
        XCTAssertEqual(repayments.first(where: { $0.source == .pool })?.amount, 10_000)
        XCTAssertEqual(repayments.first(where: { $0.source == .daily })?.amount, base * 20 / 100)
    }

    func test_상환내역이_없으면_빈배열() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        XCTAssertTrue(sut.fetchDebtRepayments(months: 3).isEmpty)
    }

    func test_상환_출처_라벨이_모두_정의되어_있다() {
        for source in [DebtRepaymentSource.daily, .pool, .absorbed, .settle] {
            XCTAssertFalse(source.label.isEmpty)
            XCTAssertFalse(source.emoji.isEmpty)
        }
    }

    func test_부채로_전환돼도_초과한_날_기록은_남는다() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: 25, fixedCosts: [], debtPlanEnabled: true))
        let base = DailyBudgetCalculator.calculate(from: sut.fetchBudgetConfig()!, for: day(-1))

        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: base, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "큰 지출", amount: base * 3, date: day(-1)))
        sut.processDailyBudgets(upTo: day(0))

        XCTAssertNotNil(sut.fetchActiveDebt(), "부채로 전환됐다")

        let days = sut.fetchOverspendDays(months: 3)
        XCTAssertEqual(days.map(\.date), [day(-1)], "전환돼도 초과한 날은 되짚을 수 있어야 한다")
        XCTAssertEqual(days[0].overspentAmount, sut.fetchActiveDebt()?.remainingAmount,
                       "초과액이 부채 금액과 일치한다")
    }
}
