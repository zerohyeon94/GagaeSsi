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
}
