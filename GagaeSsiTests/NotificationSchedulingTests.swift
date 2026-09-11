//
//  NotificationSchedulingTests.swift
//  GagaeSsi
//
//  변동 고정비 지출일 알림 — 다음 알림일 계산(순수 로직) 테스트
//

import XCTest
@testable import GagaeSsi

final class NotificationSchedulingTests: XCTestCase {
    private let cal = Calendar.current
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.startOfDay(for: cal.date(from: DateComponents(year: y, month: m, day: d))!)
    }
    private func next(_ dueDay: Int, from: Date, confirmed: Bool) -> Date? {
        VariableCostReminder.nextDueDate(dueDay: dueDay, from: from, isCurrentMonthConfirmed: confirmed)
    }

    func testBeforeDue_unconfirmed_thisMonth() {
        XCTAssertEqual(next(15, from: day(2026, 5, 10), confirmed: false), day(2026, 5, 15))
    }

    func testOnDueDay_unconfirmed_thisMonth() {
        XCTAssertEqual(next(15, from: day(2026, 5, 15), confirmed: false), day(2026, 5, 15))
    }

    func testAfterDue_unconfirmed_nextMonth() {
        XCTAssertEqual(next(15, from: day(2026, 5, 20), confirmed: false), day(2026, 6, 15))
    }

    func testBeforeDue_confirmed_nextMonth() {
        XCTAssertEqual(next(15, from: day(2026, 5, 10), confirmed: true), day(2026, 6, 15))
    }

    func testMonthEndClamp_february() {
        // dueDay 31 + 2026년 2월(28일) → 2월 28일
        XCTAssertEqual(next(31, from: day(2026, 2, 10), confirmed: false), day(2026, 2, 28))
    }

    func testMonthEndClamp_nextMonthDifferentLength() {
        // dueDay 31, 4월(30일) 말일에 확정됨 → 다음 달 5월 31일
        XCTAssertEqual(next(31, from: day(2026, 4, 30), confirmed: true), day(2026, 5, 31))
    }

    func testInvalidDueDay_nil() {
        XCTAssertNil(next(0, from: day(2026, 5, 10), confirmed: false))
        XCTAssertNil(next(32, from: day(2026, 5, 10), confirmed: false))
    }
}
