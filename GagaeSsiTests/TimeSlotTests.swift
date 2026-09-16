//
//  TimeSlotTests.swift
//  GagaeSsi
//
//  결제 시간대 버킷/집계 테스트
//

import XCTest
@testable import GagaeSsi

final class TimeSlotTests: XCTestCase {

    private let cal = Calendar.current

    /// 오늘 날짜의 특정 시:분:초 Date
    private func at(_ h: Int, _ m: Int = 0, _ s: Int = 0) -> Date {
        cal.date(bySettingHour: h, minute: m, second: s, of: Date())!
    }

    // MARK: - from: 경계값
    func testFrom_boundaries() {
        XCTAssertEqual(TimeSlot.from(date: at(6, 0)), .morning)
        XCTAssertEqual(TimeSlot.from(date: at(11, 59)), .morning)
        XCTAssertEqual(TimeSlot.from(date: at(12, 0)), .lunch)
        XCTAssertEqual(TimeSlot.from(date: at(16, 59)), .lunch)
        XCTAssertEqual(TimeSlot.from(date: at(17, 0)), .evening)
        XCTAssertEqual(TimeSlot.from(date: at(20, 59)), .evening)
        XCTAssertEqual(TimeSlot.from(date: at(21, 0)), .night)
        XCTAssertEqual(TimeSlot.from(date: at(5, 59)), .night)
        XCTAssertEqual(TimeSlot.from(date: at(0, 30)), .night)   // 실제 새벽 소비는 심야
    }

    func testFrom_exactMidnight_isNil() {
        // 정확히 00:00:00 = 시간 정보 없음 → 제외
        XCTAssertNil(TimeSlot.from(date: at(0, 0, 0)))
    }

    func testFrom_midnightWithSeconds_isNight() {
        // 00:00:01 은 실제 소비로 간주 → 심야
        XCTAssertEqual(TimeSlot.from(date: at(0, 0, 1)), .night)
    }

    // MARK: - totals
    private func record(_ amount: Int, at date: Date) -> SpendingRecordModel {
        SpendingRecordModel(title: "t", amount: amount, date: date)
    }

    func testTotals_bucketsAndPercentages() {
        let records = [
            record(1000, at: at(9)),    // 오전
            record(3000, at: at(13)),   // 점심
            record(2000, at: at(19)),   // 저녁
            record(4000, at: at(23)),   // 심야
        ]
        let (totals, timed) = TimeSlot.totals(from: records)

        XCTAssertEqual(timed, 4)
        XCTAssertEqual(totals.count, 4)   // 항상 4개 버킷
        func amount(_ s: TimeSlot) -> Int { totals.first { $0.slot == s }!.amount }
        XCTAssertEqual(amount(.morning), 1000)
        XCTAssertEqual(amount(.lunch), 3000)
        XCTAssertEqual(amount(.evening), 2000)
        XCTAssertEqual(amount(.night), 4000)

        let nightPct = totals.first { $0.slot == .night }!.percentage
        XCTAssertEqual(nightPct, 4000.0 / 10000.0, accuracy: 0.0001)
    }

    func testTotals_excludesExactMidnightRecords() {
        let records = [
            record(1000, at: at(9)),        // 오전 (집계)
            record(5000, at: at(0, 0, 0)),  // 시간 정보 없음 (제외)
        ]
        let (totals, timed) = TimeSlot.totals(from: records)
        XCTAssertEqual(timed, 1)
        XCTAssertEqual(totals.first { $0.slot == .morning }!.amount, 1000)
        // 제외된 기록은 어느 버킷에도 없음
        let sum = totals.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(sum, 1000)
    }

    func testTotals_empty() {
        let (totals, timed) = TimeSlot.totals(from: [])
        XCTAssertEqual(timed, 0)
        XCTAssertEqual(totals.count, 4)
        XCTAssertTrue(totals.allSatisfy { $0.amount == 0 && $0.percentage == 0 })
    }
}
