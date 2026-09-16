//
//  SpendingTitleCleanupTests.swift
//  GagaeSsi
//
//  소비 항목 이름 정리 테스트
//

import XCTest
@testable import GagaeSsi

final class SpendingTitleCleanupTests: XCTestCase {
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
    private func record(_ title: String, _ amount: Int, _ offset: Int) -> SpendingRecordModel {
        SpendingRecordModel(title: title, amount: amount, date: day(offset), category: .cafe)
    }

    // MARK: - looseKey

    func test_looseKey는_공백과_기호와_대소문자를_무시한다() {
        XCTAssertEqual(SpendingTitleCleanup.looseKey("스타벅스 커피"),
                       SpendingTitleCleanup.looseKey("스타벅스커피"))
        XCTAssertEqual(SpendingTitleCleanup.looseKey("STARBUCKS-커피"),
                       SpendingTitleCleanup.looseKey("starbucks 커피"))
        XCTAssertEqual(SpendingTitleCleanup.looseKey("GS25 (편의점)"),
                       SpendingTitleCleanup.looseKey("gs25 편의점"))
    }

    func test_looseKey는_다른_이름을_같게_만들지_않는다() {
        XCTAssertNotEqual(SpendingTitleCleanup.looseKey("스타벅스"),
                          SpendingTitleCleanup.looseKey("스벅"))
        XCTAssertNotEqual(SpendingTitleCleanup.looseKey("커피"),
                          SpendingTitleCleanup.looseKey("케이크"))
    }

    // MARK: - 통계

    func test_항목별_건수와_합계를_건수순으로_낸다() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("커피", 4_000, -1), record("커피", 4_000, -2), record("커피", 4_000, -3),
            record("케이크", 8_000, -4),
        ])

        XCTAssertEqual(stats.map(\.title), ["커피", "케이크"])
        XCTAssertEqual(stats[0].count, 3)
        XCTAssertEqual(stats[0].total, 12_000)
    }

    func test_제목이_빈_기록은_통계에서_제외된다() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("", 1_000, -1), record("   ", 2_000, -2), record("커피", 4_000, -3),
        ])
        XCTAssertEqual(stats.map(\.title), ["커피"])
    }

    /// 항목 이름 정리도 소비 기록 화면이므로 내 몫으로 묶인다
    func test_항목_정리_합계도_내_몫으로_묶인다() {
        let shared = SpendingRecordModel(title: "저녁", amount: 80_000, date: Date(),
                                         tripId: UUID(), participants: 4, paidByMe: true)
        let stats = SpendingTitleCleanup.titleStats(from: [shared])
        XCTAssertEqual(stats.first?.total, 20_000)
    }

    /// 같은 항목이 두 건이면 병합 경로도 내 몫으로 더해야 한다.
    /// (초기 생성만 고치고 병합을 놓치면 그룹의 첫 건만 다른 렌즈로 세어진다)
    func test_같은_항목이_여러_건이어도_모두_내_몫으로_묶인다() {
        let trip = UUID()
        let stats = SpendingTitleCleanup.titleStats(from: [
            SpendingRecordModel(title: "저녁", amount: 80_000, date: day(-1),
                                tripId: trip, participants: 4, paidByMe: true),
            SpendingRecordModel(title: "저녁", amount: 40_000, date: day(-2),
                                tripId: trip, participants: 4, paidByMe: true),
        ])
        XCTAssertEqual(stats.first?.total, 30_000, "20,000 + 10,000")
        XCTAssertEqual(stats.first?.count, 2)
    }

    // MARK: - 확실한 중복

    func test_공백만_다른_표기를_중복으로_묶는다() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("스타벅스 커피", 6_500, -1),
            record("스타벅스커피", 6_500, -2),
            record("김밥", 4_000, -3),
        ])

        let groups = SpendingTitleCleanup.duplicateGroups(from: stats)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].stats.map(\.title)), ["스타벅스 커피", "스타벅스커피"])
        XCTAssertEqual(groups[0].totalCount, 2)
        XCTAssertEqual(groups[0].totalAmount, 13_000)
    }

    func test_중복_묶음의_기본_이름은_많이_쓴_표기() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("스타벅스커피", 6_500, -1),
            record("스타벅스 커피", 6_500, -2),
            record("스타벅스 커피", 6_500, -3),
        ])

        let groups = SpendingTitleCleanup.duplicateGroups(from: stats)
        XCTAssertEqual(groups[0].suggestedName, "스타벅스 커피", "2건 쓴 표기가 대표")
    }

    func test_갈라진_표기가_없으면_중복_묶음도_없다() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("커피", 4_000, -1), record("김밥", 4_000, -2),
        ])
        XCTAssertTrue(SpendingTitleCleanup.duplicateGroups(from: stats).isEmpty)
    }

    // MARK: - 비슷한 이름

    func test_한쪽으로_시작하는_이름을_비슷한_묶음으로_제안한다() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("스타벅스", 5_000, -1),
            record("스타벅스 라떼", 6_000, -2),
            record("김밥", 4_000, -3),
        ])

        let groups = SpendingTitleCleanup.similarGroups(from: stats)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].stats.map(\.title)), ["스타벅스", "스타벅스 라떼"])
    }

    func test_확실한_중복은_비슷한_묶음에서_빠진다() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("스타벅스 커피", 6_500, -1),
            record("스타벅스커피", 6_500, -2),
        ])

        XCTAssertEqual(SpendingTitleCleanup.duplicateGroups(from: stats).count, 1)
        XCTAssertTrue(SpendingTitleCleanup.similarGroups(from: stats).isEmpty,
                      "이미 중복으로 잡힌 건 다시 제안하지 않는다")
    }

    /// 줄임말은 규칙으로 못 잡는다 — 잡는 척하면 안 된다
    func test_줄임말은_자동으로_묶지_않는다() {
        let stats = SpendingTitleCleanup.titleStats(from: [
            record("스벅", 5_000, -1), record("스타벅스", 5_000, -2),
        ])

        XCTAssertTrue(SpendingTitleCleanup.duplicateGroups(from: stats).isEmpty)
        XCTAssertTrue(SpendingTitleCleanup.similarGroups(from: stats).isEmpty)
    }

    // MARK: - 일괄 변경

    private func seedRecords(_ titles: [String]) {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 50_000, date: day(0),
                                                   carryOverSources: [], spendingRecords: []))
        for title in titles {
            XCTAssertTrue(sut.createSpendingRecord(
                SpendingRecordModel(title: title, amount: 5_000, date: day(0), category: .cafe)))
        }
    }

    func test_여러_표기를_한_이름으로_합친다() {
        seedRecords(["스타벅스 커피", "스타벅스커피", "김밥"])

        let changed = sut.renameSpendingTitles(matching: ["스타벅스 커피", "스타벅스커피"],
                                               to: "스타벅스")

        XCTAssertEqual(changed, 2)
        let titles = Set(sut.fetchAllSpendingRecords().map(\.title))
        XCTAssertEqual(titles, ["스타벅스", "김밥"])
    }

    func test_이미_같은_이름인_기록은_세지_않는다() {
        seedRecords(["스타벅스", "스타벅스커피"])

        let changed = sut.renameSpendingTitles(matching: ["스타벅스", "스타벅스커피"], to: "스타벅스")

        XCTAssertEqual(changed, 1, "이미 '스타벅스'인 1건은 바꿀 필요가 없다")
    }

    func test_공백_표기_차이도_함께_잡힌다() {
        seedRecords(["  스타벅스   커피 "])

        let changed = sut.renameSpendingTitles(matching: ["스타벅스 커피"], to: "스타벅스")

        XCTAssertEqual(changed, 1, "정규화 기준으로 비교하므로 공백 차이는 무시된다")
    }

    func test_빈_이름으로는_바꿀_수_없다() {
        seedRecords(["커피"])
        XCTAssertEqual(sut.renameSpendingTitles(matching: ["커피"], to: "   "), 0)
        XCTAssertEqual(sut.fetchAllSpendingRecords().first?.title, "커피")
    }

    /// 이름만 바뀌어야 한다 — 예산 계산에 영향이 없어야 한다
    func test_이름을_바꿔도_금액과_날짜와_카테고리는_그대로다() {
        seedRecords(["커피"])
        let before = sut.fetchAllSpendingRecords()[0]
        let balanceBefore = sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable

        _ = sut.renameSpendingTitles(matching: ["커피"], to: "스타벅스")

        let after = sut.fetchAllSpendingRecords()[0]
        XCTAssertEqual(after.title, "스타벅스")
        XCTAssertEqual(after.amount, before.amount)
        XCTAssertEqual(after.date, before.date)
        XCTAssertEqual(after.category, before.category)
        XCTAssertEqual(after.id, before.id)
        XCTAssertEqual(sut.fetchDailyBudgetModel(date: day(0))?.todayAvailable, balanceBefore,
                       "오늘 예산 잔액이 변하면 안 된다")
    }

    func test_합친_뒤에는_한_항목으로_집계된다() {
        seedRecords(["스타벅스 커피", "스타벅스커피"])

        _ = sut.renameSpendingTitles(matching: ["스타벅스 커피", "스타벅스커피"], to: "스타벅스")

        let stats = SpendingTitleCleanup.titleStats(from: sut.fetchAllSpendingRecords())
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].title, "스타벅스")
        XCTAssertEqual(stats[0].count, 2)
        XCTAssertTrue(SpendingTitleCleanup.duplicateGroups(from: stats).isEmpty)
    }
}
