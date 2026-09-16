//
//  AssetTransferTests.swift
//  GagaeSsi
//
//  저축·투자(이동) 기록 테스트 — 예산에서는 빠지되 소비로는 잡히지 않아야 한다
//

import XCTest
@testable import GagaeSsi

final class AssetTransferTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
    }
    override func tearDownWithError() throws { sut = nil }

    private func day(_ o: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: o, to: Date())!)
    }
    @discardableResult
    private func seedToday(available: Int = 50_000) -> DailyBudgetModel? {
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: available, date: day(0),
                                                   carryOverSources: [], spendingRecords: []))
        return sut.fetchDailyBudgetModel(date: day(0))
    }

    // MARK: - 집계 (순수 로직)

    func test_종류별로_합계를_낸다() {
        let summary = AssetTransferSummary.make(from: [
            AssetTransferModel(date: day(0), amount: 100_000, title: "S&P500", kind: .investment),
            AssetTransferModel(date: day(0), amount: 50_000, title: "청약", kind: .saving),
            AssetTransferModel(date: day(-1), amount: 30_000, title: "적금", kind: .saving),
        ])

        XCTAssertEqual(summary.investmentTotal, 100_000)
        XCTAssertEqual(summary.savingTotal, 80_000)
        XCTAssertEqual(summary.total, 180_000)
        XCTAssertEqual(summary.total(of: .investment), 100_000)
    }

    func test_기록이_없으면_합계는_0() {
        let summary = AssetTransferSummary.make(from: [])
        XCTAssertEqual(summary.total, 0)
    }

    func test_알_수_없는_종류는_투자로_해석한다() {
        XCTAssertEqual(AssetTransferKind.from(nil), .investment)
        XCTAssertEqual(AssetTransferKind.from("이상한값"), .investment)
        XCTAssertEqual(AssetTransferKind.from("저축"), .saving)
    }

    // MARK: - 예산 차감

    func test_저축투자는_오늘_예산에서_차감된다() {
        let before = seedToday()!.todayAvailable

        XCTAssertTrue(sut.createAssetTransfer(
            AssetTransferModel(date: day(0), amount: 20_000, title: "S&P500", kind: .investment)))

        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable, before - 20_000)
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.transferAmount, 20_000)
    }

    func test_금액이_0이하면_기록되지_않는다() {
        seedToday()
        XCTAssertFalse(sut.createAssetTransfer(
            AssetTransferModel(date: day(0), amount: 0, title: "빈 값")))
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.transferAmount, 0)
    }

    func test_삭제하면_예산이_되돌아온다() {
        let before = seedToday()!.todayAvailable
        let model = AssetTransferModel(date: day(0), amount: 30_000, title: "적금", kind: .saving)
        _ = sut.createAssetTransfer(model)

        XCTAssertTrue(sut.deleteAssetTransfer(id: model.id))

        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable, before)
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.transferAmount, 0)
    }

    // MARK: - 소비가 아님 (핵심)

    /// "투자는 소비가 아니라 이동" — 소비 기록을 만들지 않아야 한다
    func test_저축투자는_소비_기록을_만들지_않는다() {
        seedToday()
        _ = sut.createAssetTransfer(
            AssetTransferModel(date: day(0), amount: 500_000, title: "주식", kind: .investment))

        XCTAssertTrue(sut.fetchSpendingRecords(date: day(0)).isEmpty,
                      "소비로 잡히면 이번 달 소비가 부풀고 카테고리 통계가 왜곡된다")
        XCTAssertTrue(sut.fetchAllSpendingRecords().isEmpty)
    }

    /// 큰 금액을 투자해도 '초과한 날'로 잡히면 안 된다 (위시 저금과 같은 취급)
    func test_저축투자는_초과한_날_판정에_잡히지_않는다() {
        seedToday(available: 50_000)
        _ = sut.createAssetTransfer(
            AssetTransferModel(date: day(0), amount: 500_000, title: "주식", kind: .investment))

        let budget = sut.fetchDailyBudgetModel(date: day(0))!
        XCTAssertLessThan(budget.todayAvailable, 0, "잔액은 음수가 된다")

        let evaluation = OverspendAnalyzer.evaluate(budget)
        XCTAssertEqual(evaluation.outgoing, 0, "쓴 돈은 0")
        XCTAssertEqual(evaluation.overspent, 0, "과소비가 아니다")
        XCTAssertTrue(OverspendAnalyzer.overspendDays(from: [budget]).isEmpty)
    }

    func test_소비와_저축투자가_같은_날_있어도_소비만_초과로_센다() {
        seedToday(available: 50_000)
        _ = sut.createSpendingRecord(SpendingRecordModel(title: "쇼핑", amount: 70_000, date: day(0)))
        _ = sut.createAssetTransfer(
            AssetTransferModel(date: day(0), amount: 100_000, title: "적금", kind: .saving))

        let budget = sut.fetchDailyBudgetModel(date: day(0))!
        let evaluation = OverspendAnalyzer.evaluate(budget)

        XCTAssertEqual(evaluation.outgoing, 70_000)
        XCTAssertEqual(evaluation.overspent, 20_000, "70,000 − 50,000 (저축 100,000은 제외)")
    }

    // MARK: - 조회

    func test_날짜별_조회() {
        seedToday()
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 50_000, date: day(-1),
                                                   carryOverSources: [], spendingRecords: []))
        _ = sut.createAssetTransfer(AssetTransferModel(date: day(0), amount: 10_000, title: "오늘"))
        _ = sut.createAssetTransfer(AssetTransferModel(date: day(-1), amount: 20_000, title: "어제"))

        XCTAssertEqual(sut.fetchAssetTransfers(date: day(0)).map(\.title), ["오늘"])
        XCTAssertEqual(sut.todayAssetTransferAmount(), 10_000)
    }

    func test_월별_집계는_그_달만_센다() {
        seedToday()
        _ = sut.createAssetTransfer(
            AssetTransferModel(date: day(0), amount: 100_000, title: "이번 달", kind: .investment))

        let comps = cal.dateComponents([.year, .month], from: day(0))
        let thisMonth = sut.assetTransferSummary(year: comps.year!, month: comps.month!)
        XCTAssertEqual(thisMonth.investmentTotal, 100_000)

        let other = cal.date(byAdding: .month, value: -2, to: day(0))!
        let otherComps = cal.dateComponents([.year, .month], from: other)
        XCTAssertEqual(sut.assetTransferSummary(year: otherComps.year!, month: otherComps.month!).total, 0)
    }

    func test_데이터_초기화_시_함께_삭제된다() {
        seedToday()
        _ = sut.createAssetTransfer(AssetTransferModel(date: day(0), amount: 10_000, title: "투자"))

        sut.resetAllData()

        XCTAssertTrue(sut.fetchAssetTransfers(date: day(0)).isEmpty)
    }
}
