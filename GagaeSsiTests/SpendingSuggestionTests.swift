//
//  SpendingSuggestionTests.swift
//  GagaeSsi
//
//  소비 항목 자동완성 엔진(순수) 테스트
//

import XCTest
@testable import GagaeSsi

final class SpendingSuggestionTests: XCTestCase {
    private let cal = Calendar.current
    private func date(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: Date())!
    }
    private func rec(_ title: String, _ amount: Int, _ dateOffset: Int, _ cat: SpendingCategory = .other) -> SpendingRecordModel {
        SpendingRecordModel(title: title, amount: amount, date: date(dateOffset), category: cat)
    }

    // MARK: - normalize
    func testNormalize_trimsAndCollapsesSpaces() {
        XCTAssertEqual(SpendingSuggestionEngine.normalize("  점심   식사 "), "점심 식사")
    }

    // MARK: - build
    func testBuild_dedupesByNormalizedTitle_andCounts() {
        let items = [
            rec("스타벅스", 4500, -3),
            rec(" 스타벅스 ", 5000, -1),   // 정규화하면 같은 항목
            rec("버스", 1500, -2),
        ]
        let suggestions = SpendingSuggestionEngine.build(from: items)
        XCTAssertEqual(suggestions.count, 2)   // 스타벅스(2건 집계) + 버스
        let sb = suggestions.first { $0.title == "스타벅스" }!
        XCTAssertEqual(sb.count, 2)
        XCTAssertEqual(sb.lastAmount, 5000)     // 더 최근(-1) 금액
    }

    func testBuild_usesMostRecentCategory() {
        let items = [
            rec("점심", 8000, -5, .food),
            rec("점심", 9000, -1, .cafe),   // 최근
        ]
        let s = SpendingSuggestionEngine.build(from: items).first { $0.title == "점심" }!
        XCTAssertEqual(s.category, .cafe)
        XCTAssertEqual(s.lastAmount, 9000)
    }

    func testBuild_ignoresEmptyTitles() {
        let items = [rec("   ", 1000, -1), rec("커피", 3000, -1)]
        XCTAssertEqual(SpendingSuggestionEngine.build(from: items).map(\.title), ["커피"])
    }

    // MARK: - filter
    func testFilter_emptyQuery_sortsByRecency() {
        let s = SpendingSuggestionEngine.build(from: [
            rec("옛날", 1000, -10),
            rec("최근", 2000, -1),
            rec("중간", 1500, -5),
        ])
        let out = SpendingSuggestionEngine.filter(s, query: "")
        XCTAssertEqual(out.map(\.title), ["최근", "중간", "옛날"])
    }

    func testFilter_prefixBeatsContains() {
        let s = SpendingSuggestionEngine.build(from: [
            rec("아메리카노", 4000, -1),   // "메" 포함
            rec("메가커피", 2000, -2),     // "메"로 시작
        ])
        let out = SpendingSuggestionEngine.filter(s, query: "메")
        XCTAssertEqual(out.first?.title, "메가커피")   // prefix 우선
        XCTAssertEqual(out.count, 2)
    }

    func testFilter_excludesNonMatching() {
        let s = SpendingSuggestionEngine.build(from: [
            rec("버스", 1500, -1),
            rec("택시", 8000, -1),
        ])
        XCTAssertEqual(SpendingSuggestionEngine.filter(s, query: "버").map(\.title), ["버스"])
    }

    func testFilter_respectsLimit() {
        let items = (0..<20).map { rec("item\($0)", 1000, -$0) }
        let s = SpendingSuggestionEngine.build(from: items)
        XCTAssertEqual(SpendingSuggestionEngine.filter(s, query: "", limit: 5).count, 5)
    }
}
