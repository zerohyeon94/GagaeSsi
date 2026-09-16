//
//  CategorySpendingTests.swift
//  GagaeSsi
//
//  카테고리 안 항목별 집계 테스트
//

import XCTest
@testable import GagaeSsi

final class CategorySpendingTests: XCTestCase {
    private let cal = Calendar.current

    private func day(_ o: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: o, to: Date())!)
    }
    private func record(_ title: String, _ amount: Int, _ offset: Int,
                        _ category: SpendingCategory = .cafe) -> SpendingRecordModel {
        SpendingRecordModel(title: title, amount: amount, date: day(offset), category: category)
    }

    func test_같은_항목명끼리_묶어_합계와_건수를_낸다() {
        let items = CategorySpendingAnalyzer.itemSummaries(from: [
            record("스타벅스 커피", 6_500, -1),
            record("스타벅스 커피", 6_500, -3),
            record("편의점 커피", 1_500, -2),
        ])

        XCTAssertEqual(items.count, 2)
        let starbucks = items.first { $0.title == "스타벅스 커피" }
        XCTAssertEqual(starbucks?.total, 13_000)
        XCTAssertEqual(starbucks?.count, 2)
        XCTAssertEqual(starbucks?.average, 6_500)
    }

    func test_금액_큰_순으로_정렬된다() {
        let items = CategorySpendingAnalyzer.itemSummaries(from: [
            record("작은 것", 1_000, -1),
            record("큰 것", 50_000, -2),
            record("중간 것", 10_000, -3),
        ])

        XCTAssertEqual(items.map(\.title), ["큰 것", "중간 것", "작은 것"])
    }

    /// 자동완성과 같은 규칙으로 묶여야 화면과 추천이 어긋나지 않는다
    func test_공백과_대소문자를_자동완성과_같은_기준으로_정규화한다() {
        let items = CategorySpendingAnalyzer.itemSummaries(from: [
            record("  스타벅스   커피 ", 6_500, -1),
            record("스타벅스 커피", 6_500, -2),
            record("STARBUCKS", 5_000, -3),
            record("starbucks", 5_000, -4),
        ])

        XCTAssertEqual(items.count, 2, "공백·대소문자 차이는 같은 항목으로 묶인다")
        XCTAssertEqual(items.first(where: { $0.title.lowercased() == "starbucks" })?.total, 10_000)
    }

    func test_대표_표기는_가장_최근_기록을_따른다() {
        let items = CategorySpendingAnalyzer.itemSummaries(from: [
            record("STARBUCKS", 5_000, -3),
            record("Starbucks", 5_000, -1),
        ])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Starbucks")
        XCTAssertEqual(items[0].lastDate, day(-1))
    }

    func test_제목이_없으면_기본_라벨로_묶는다() {
        let items = CategorySpendingAnalyzer.itemSummaries(from: [
            record("", 3_000, -1),
            record("   ", 2_000, -2),
        ])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, CategorySpendingAnalyzer.untitledLabel)
        XCTAssertEqual(items[0].total, 5_000)
    }

    func test_반복_구매_항목만_추린다() {
        let items = CategorySpendingAnalyzer.itemSummaries(from: [
            record("매일 커피", 4_000, -1),
            record("매일 커피", 4_000, -2),
            record("한 번뿐", 30_000, -3),
        ])

        let repeated = CategorySpendingAnalyzer.repeatedItems(from: items)

        XCTAssertEqual(repeated.map(\.title), ["매일 커피"])
    }

    func test_기록이_없으면_빈배열() {
        XCTAssertTrue(CategorySpendingAnalyzer.itemSummaries(from: []).isEmpty)
    }

    func test_1건짜리_항목의_평균은_그_금액() {
        let items = CategorySpendingAnalyzer.itemSummaries(from: [record("한 번", 7_777, -1)])
        XCTAssertEqual(items[0].average, 7_777)
        XCTAssertEqual(items[0].count, 1)
    }

    /// 8만을 결제했어도 4명이 나눴으면 내가 쓴 건 2만이다
    func test_공용_소비는_내_몫으로_묶인다() {
        let shared = SpendingRecordModel(title: "저녁", amount: 80_000, date: Date(),
                                         tripId: UUID(), participants: 4, paidByMe: true)
        let items = CategorySpendingAnalyzer.itemSummaries(from: [shared])
        XCTAssertEqual(items.first?.total, 20_000)
    }

    /// 같은 항목이 두 건이면 병합 경로도 내 몫으로 더해야 한다.
    /// (초기 생성만 고치고 병합을 놓치면 그룹의 첫 건만 다른 렌즈로 세어진다)
    func test_같은_항목이_여러_건이어도_모두_내_몫으로_묶인다() {
        let trip = UUID()
        let items = CategorySpendingAnalyzer.itemSummaries(from: [
            SpendingRecordModel(title: "저녁", amount: 80_000, date: day(-1),
                                tripId: trip, participants: 4, paidByMe: true),
            SpendingRecordModel(title: "저녁", amount: 40_000, date: day(-2),
                                tripId: trip, participants: 4, paidByMe: true),
        ])
        XCTAssertEqual(items.first?.total, 30_000, "20,000 + 10,000")
        XCTAssertEqual(items.first?.count, 2)
    }
}
