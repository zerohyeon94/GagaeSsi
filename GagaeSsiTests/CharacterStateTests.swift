//
//  CharacterStateTests.swift
//  GagaeSsi
//
//  캐릭터 소비 상태(사용률 기반) 테스트
//

import XCTest
@testable import GagaeSsi

final class CharacterStateTests: XCTestCase {
    func testStable_under70() {
        XCTAssertEqual(CharacterState.from(spent: 6_000, base: 10_000, coveredFromPool: false), .stable)
    }
    func testCaution_70to100() {
        XCTAssertEqual(CharacterState.from(spent: 7_000, base: 10_000, coveredFromPool: false), .caution)
        XCTAssertEqual(CharacterState.from(spent: 9_999, base: 10_000, coveredFromPool: false), .caution)
    }
    func testOver_atOrAbove100() {
        XCTAssertEqual(CharacterState.from(spent: 10_000, base: 10_000, coveredFromPool: false), .over)
        XCTAssertEqual(CharacterState.from(spent: 13_000, base: 10_000, coveredFromPool: false), .over)
    }
    func testCovered_takesPriority() {
        // 초과여도 이월금으로 채웠으면 회복
        XCTAssertEqual(CharacterState.from(spent: 13_000, base: 10_000, coveredFromPool: true), .covered)
    }
    func testZeroBase_stable() {
        XCTAssertEqual(CharacterState.from(spent: 0, base: 0, coveredFromPool: false), .stable)
    }

    // MARK: - 총 가용액(이월 포함) 반영

    /// 실제 제보 상황: 이월 −317,730 / 기본 예산 54,670 / 오늘 소비 22,000 → 잔액 −290,060.
    /// 사용률은 40%라 예전 로직은 "여유"를 띄웠다.
    func testNegativeAvailable_isOverEvenWhenTodaySpendingIsLow() {
        XCTAssertEqual(
            CharacterState.from(spent: 22_000, base: 54_670,
                                coveredFromPool: false, todayAvailable: -290_060),
            .over,
            "이월 때문에 총액이 음수면 오늘 소비가 적어도 '여유'가 아니다")
    }

    func testNegativeAvailable_beatsCoveredAndRepaying() {
        // 충당·상환했는데도 여전히 음수면 지금 상태를 먼저 알려야 한다
        XCTAssertEqual(
            CharacterState.from(spent: 1_000, base: 10_000,
                                coveredFromPool: true, todayAvailable: -5_000), .over)
        XCTAssertEqual(
            CharacterState.from(spent: 1_000, base: 10_000, coveredFromPool: false,
                                repayingDebt: true, todayAvailable: -5_000), .over)
    }

    func testPositiveAvailable_keepsExistingBehavior() {
        XCTAssertEqual(
            CharacterState.from(spent: 6_000, base: 10_000,
                                coveredFromPool: false, todayAvailable: 4_000), .stable)
        XCTAssertEqual(
            CharacterState.from(spent: 1_000, base: 10_000,
                                coveredFromPool: true, todayAvailable: 9_000), .covered)
    }

    func testNilAvailable_fallsBackToRatio() {
        XCTAssertEqual(CharacterState.from(spent: 6_000, base: 10_000,
                                           coveredFromPool: false, todayAvailable: nil), .stable)
    }
}
