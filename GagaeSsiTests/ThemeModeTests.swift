//
//  ThemeModeTests.swift
//  GagaeSsi
//
//  화면 테마 설정 테스트
//

import XCTest
import SwiftUI
@testable import GagaeSsi

final class ThemeModeTests: XCTestCase {
    var sut: CoreDataManager!

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
    }
    override func tearDownWithError() throws { sut = nil }

    /// nil이어야 SwiftUI가 기기 설정을 따른다 — 여기가 틀리면 다크 지원이 통째로 무의미해진다
    func test_기기설정은_colorScheme이_nil() {
        XCTAssertNil(ThemeMode.system.colorScheme)
        XCTAssertEqual(ThemeMode.light.colorScheme, .light)
        XCTAssertEqual(ThemeMode.dark.colorScheme, .dark)
    }

    func test_기본값은_기기설정() {
        XCTAssertEqual(sut.fetchBudgetConfig()?.themeMode, .system)
    }

    func test_테마_변경이_저장된다() {
        XCTAssertTrue(sut.updateThemeMode(.dark))
        XCTAssertEqual(sut.fetchBudgetConfig()?.themeMode, .dark)

        XCTAssertTrue(sut.updateThemeMode(.light))
        XCTAssertEqual(sut.fetchBudgetConfig()?.themeMode, .light)
    }

    func test_알_수_없는_값은_기기설정으로_해석한다() {
        XCTAssertEqual(ThemeMode.from(nil), .system)
        XCTAssertEqual(ThemeMode.from(""), .system)
        XCTAssertEqual(ThemeMode.from("이상한값"), .system)
        XCTAssertEqual(ThemeMode.from("dark"), .dark)
    }

    func test_모든_모드에_라벨과_이모지가_있다() {
        for mode in ThemeMode.allCases {
            XCTAssertFalse(mode.label.isEmpty)
            XCTAssertFalse(mode.emoji.isEmpty)
        }
        XCTAssertEqual(ThemeMode.allCases.count, 3)
    }

    /// 다른 설정을 바꿔도 테마가 초기화되면 안 된다
    func test_다른_설정_변경이_테마를_지우지_않는다() {
        _ = sut.updateThemeMode(.dark)

        var config = sut.fetchBudgetConfig()!
        config.salary = 4_000_000
        XCTAssertTrue(sut.updateBudgetConfig(config))

        XCTAssertEqual(sut.fetchBudgetConfig()?.themeMode, .dark)
        XCTAssertEqual(sut.fetchBudgetConfig()?.salary, 4_000_000)
    }
}
