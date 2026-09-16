//
//  FixedCostGroupingTests.swift
//  GagaeSsi
//
//  고정비 그룹핑(종류·고정/변동·정렬·합계) 테스트
//

import XCTest
@testable import GagaeSsi

final class FixedCostGroupingTests: XCTestCase {

    private func cost(_ title: String, _ amount: Int, kind: FixedCostKind = .spending,
                      variable: Bool = false, dueDay: Int = 0) -> FixedCostModel {
        FixedCostModel(title: title, amount: amount, isVariable: variable, dueDay: dueDay, kind: kind)
    }

    func testGroup_splitsByKindAndVariability() {
        let g = FixedCostGrouping.group([
            cost("월세", 500_000),                                   // 지출·고정
            cost("관리비", 100_000, variable: true, dueDay: 25),     // 지출·변동
            cost("적금", 300_000, kind: .saving),                    // 저축
            cost("ETF", 200_000, kind: .investment),                 // 투자
        ])
        XCTAssertEqual(g.fixedSpending.map(\.title), ["월세"])
        XCTAssertEqual(g.variableSpending.map(\.title), ["관리비"])
        XCTAssertEqual(Set(g.savingInvestment.map(\.title)), ["적금", "ETF"])
    }

    func testGroup_variableSpendingSortedByDueDay() {
        let g = FixedCostGrouping.group([
            cost("C", 1, variable: true, dueDay: 28),
            cost("A", 1, variable: true, dueDay: 5),
            cost("B", 1, variable: true, dueDay: 15),
        ])
        XCTAssertEqual(g.variableSpending.map(\.title), ["A", "B", "C"])
    }

    func testGroup_totalsByKind() {
        let g = FixedCostGrouping.group([
            cost("월세", 500_000),
            cost("관리비", 100_000, variable: true, dueDay: 25),
            cost("적금", 300_000, kind: .saving),
            cost("ETF", 200_000, kind: .investment),
        ])
        XCTAssertEqual(g.spendingTotal, 600_000)   // 월세 + 관리비
        XCTAssertEqual(g.savingTotal, 300_000)
        XCTAssertEqual(g.investmentTotal, 200_000)
        XCTAssertEqual(g.total, 1_100_000)
    }

    func testGroup_savingInvestment_includesVariable() {
        // 종류 우선: 변동이어도 저축/투자 그룹에
        let g = FixedCostGrouping.group([
            cost("변동적금", 100_000, kind: .saving, variable: true, dueDay: 10),
        ])
        XCTAssertTrue(g.variableSpending.isEmpty)
        XCTAssertEqual(g.savingInvestment.map(\.title), ["변동적금"])
        XCTAssertEqual(g.savingTotal, 100_000)
    }

    func testDefaultKind_isSpending() {
        XCTAssertEqual(FixedCostModel(title: "x", amount: 1).kind, .spending)
        XCTAssertEqual(FixedCostKind.from(nil), .spending)
        XCTAssertEqual(FixedCostKind.from("저축"), .saving)
    }
}
