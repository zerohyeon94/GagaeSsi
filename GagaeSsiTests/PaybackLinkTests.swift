//
//  PaybackLinkTests.swift
//  GagaeSsi
//
//  페이백 소비 자동 묶기 · 수령 예정일 경과 판정 테스트
//

import XCTest
@testable import GagaeSsi

final class PaybackLinkTests: XCTestCase {
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
    /// 그날 예산을 만들고 소비를 기록한다 (createSpendingRecord는 DailyBudget이 있어야 한다)
    private func spend(_ amount: Int, _ offset: Int, _ category: SpendingCategory) {
        if sut.fetchDailyBudgetModel(date: day(offset)) == nil {
            _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 50_000, date: day(offset),
                                                       carryOverSources: [], spendingRecords: []))
        }
        XCTAssertTrue(sut.createSpendingRecord(
            SpendingRecordModel(title: "지출", amount: amount, date: day(offset), category: category)))
    }

    private func periodPayback(category: SpendingCategory?, rate: Int = 0,
                               from: Int = -10, to: Int = 0) -> PaybackModel {
        PaybackModel(title: "K-패스", type: .period, status: .estimated,
                     periodStart: day(from), periodEnd: day(to),
                     linkedCategory: category, refundRatePercent: rate)
    }

    // MARK: - 자동 묶기

    func test_기간과_카테고리로_소비를_자동_합산한다() {
        spend(21_000, -5, .transport)
        spend(9_000, -3, .transport)
        spend(50_000, -4, .food)          // 다른 카테고리 → 제외
        spend(7_000, -20, .transport)     // 기간 밖 → 제외

        let payback = periodPayback(category: .transport)
        _ = sut.createPayback(payback)

        let linked = sut.linkedSpendingTotal(for: payback)
        XCTAssertEqual(linked.count, 2)
        XCTAssertEqual(linked.total, 30_000)
    }

    /// periodEnd는 사용자가 고른 '마지막 날'이라 그날 전체가 포함돼야 한다
    func test_종료일_당일_소비도_포함된다() {
        spend(5_000, 0, .transport)
        let payback = periodPayback(category: .transport, from: -3, to: 0)
        XCTAssertEqual(sut.linkedSpendingTotal(for: payback).total, 5_000)
    }

    func test_카테고리를_안_고르면_묶지_않는다() {
        spend(21_000, -3, .transport)
        let payback = periodPayback(category: nil)

        XCTAssertFalse(payback.canLinkSpending)
        XCTAssertTrue(sut.linkedSpending(for: payback).isEmpty)
    }

    func test_연결형은_묶지_않는다() {
        spend(21_000, -3, .transport)
        let payback = PaybackModel(title: "카드 캐시백", type: .transaction,
                                   linkedCategory: .transport, refundRatePercent: 20)

        XCTAssertFalse(payback.canLinkSpending, "기간이 없으면 묶을 수 없다")
        XCTAssertTrue(sut.linkedSpending(for: payback).isEmpty)
    }

    // MARK: - 예상액 계산

    func test_환급률로_예상액을_계산한다() {
        let payback = periodPayback(category: .transport, rate: 20)
        XCTAssertEqual(payback.estimatedRefund(fromLinkedTotal: 210_000), 42_000)
    }

    func test_환급률은_원_단위_내림() {
        let payback = periodPayback(category: .transport, rate: 53)
        XCTAssertEqual(payback.estimatedRefund(fromLinkedTotal: 21_111), 11_188)
    }

    /// 환급률 0이면 자동 계산하지 않는다 — 사용자가 직접 적은 금액을 덮어쓰면 안 된다
    func test_환급률이_0이면_계산하지_않는다() {
        let payback = periodPayback(category: .transport, rate: 0)
        XCTAssertNil(payback.estimatedRefund(fromLinkedTotal: 210_000))
    }

    func test_묶인_소비가_없으면_계산하지_않는다() {
        let payback = periodPayback(category: .transport, rate: 20)
        XCTAssertNil(payback.estimatedRefund(fromLinkedTotal: 0))
    }

    // MARK: - 저장·조회

    func test_카테고리와_환급률이_저장된다() {
        let payback = periodPayback(category: .transport, rate: 30)
        XCTAssertTrue(sut.createPayback(payback))

        let loaded = sut.fetchPaybacks().first { $0.id == payback.id }
        XCTAssertEqual(loaded?.linkedCategory, .transport)
        XCTAssertEqual(loaded?.refundRatePercent, 30)
    }

    // MARK: - 수령 예정일 경과

    func test_예정일이_지났고_아직_안_받았으면_경과로_잡는다() {
        var overdue = periodPayback(category: nil)
        overdue.expectedDate = day(-1)
        _ = sut.createPayback(overdue)

        XCTAssertEqual(sut.overduePaybacks().map(\.id), [overdue.id])
    }

    func test_예정일이_오늘이면_경과로_잡는다() {
        var today = periodPayback(category: nil)
        today.expectedDate = day(0)
        _ = sut.createPayback(today)

        XCTAssertEqual(sut.overduePaybacks().count, 1)
    }

    func test_아직_예정일_전이면_경과가_아니다() {
        var future = periodPayback(category: nil)
        future.expectedDate = day(3)
        _ = sut.createPayback(future)

        XCTAssertTrue(sut.overduePaybacks().isEmpty)
    }

    func test_이미_받았거나_취소한_건은_경과에서_제외된다() {
        var received = periodPayback(category: nil)
        received.expectedDate = day(-5)
        received.status = .received
        _ = sut.createPayback(received)

        var cancelled = periodPayback(category: nil)
        cancelled.expectedDate = day(-5)
        cancelled.status = .cancelled
        _ = sut.createPayback(cancelled)

        XCTAssertTrue(sut.overduePaybacks().isEmpty)
    }

    func test_예정일이_없으면_경과가_아니다() {
        _ = sut.createPayback(periodPayback(category: nil))
        XCTAssertTrue(sut.overduePaybacks().isEmpty)
    }
}
