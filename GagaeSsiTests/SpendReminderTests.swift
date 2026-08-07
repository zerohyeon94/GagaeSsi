//
//  SpendReminderTests.swift
//  GagaeSsi
//
//  소비 기록 리마인더 예약 대상 날짜 계산 테스트 (순수 로직)
//

import XCTest
@testable import GagaeSsi

final class SpendReminderTests: XCTestCase {
    private let cal = Calendar.current

    /// 오늘 지정 시각의 Date
    private func today(hour: Int, minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    private func dates(from now: Date, hour: Int = 21, minute: Int = 0,
                       days: Int = SpendReminderSchedule.scheduleDays,
                       recordedDays: Set<Int> = []) -> [Date] {
        let todayStart = cal.startOfDay(for: now)
        return SpendReminderSchedule.pendingDates(
            from: now, hour: hour, minute: minute, days: days,
            hasRecord: { date in
                let offset = self.cal.dateComponents([.day], from: todayStart, to: date).day ?? 0
                return recordedDays.contains(offset)
            })
    }

    // MARK: - 오늘 포함 여부

    func test_알림시각_전이고_기록없으면_오늘_포함() {
        let result = dates(from: today(hour: 10), hour: 21)
        XCTAssertEqual(result.count, SpendReminderSchedule.scheduleDays)
        XCTAssertTrue(cal.isDateInToday(result.first!))
        XCTAssertEqual(cal.component(.hour, from: result.first!), 21)
    }

    func test_알림시각이_이미_지났으면_오늘_제외() {
        let result = dates(from: today(hour: 22), hour: 21)
        XCTAssertEqual(result.count, SpendReminderSchedule.scheduleDays - 1)
        XCTAssertFalse(result.contains { cal.isDateInToday($0) })
    }

    func test_오늘_기록이_있으면_오늘_제외() {
        let result = dates(from: today(hour: 10), hour: 21, recordedDays: [0])
        XCTAssertEqual(result.count, SpendReminderSchedule.scheduleDays - 1)
        XCTAssertFalse(result.contains { cal.isDateInToday($0) })
    }

    func test_미래날짜는_기록여부와_무관하게_포함() {
        // 미래에는 기록이 있을 수 없지만, 방어적으로 true를 돌려줘도 필터가 동작하는지 확인
        let all = dates(from: today(hour: 10), hour: 21)
        let filtered = dates(from: today(hour: 10), hour: 21, recordedDays: [3])
        XCTAssertEqual(filtered.count, all.count - 1)
    }

    // MARK: - 개수·경계

    func test_기본_14일치를_넘지_않는다() {
        let result = dates(from: today(hour: 0), hour: 21)
        XCTAssertLessThanOrEqual(result.count, SpendReminderSchedule.scheduleDays)
        XCTAssertEqual(SpendReminderSchedule.scheduleDays, 14)
    }

    func test_정확히_알림시각이면_오늘_제외() {
        // fireDate > now 조건이므로 같은 시각은 예약하지 않는다
        let now = today(hour: 21, minute: 0)
        let result = dates(from: now, hour: 21, minute: 0)
        XCTAssertFalse(result.contains { cal.isDateInToday($0) })
    }

    func test_잘못된_시각이나_일수는_빈배열() {
        XCTAssertTrue(dates(from: Date(), hour: 24).isEmpty)
        XCTAssertTrue(dates(from: Date(), hour: -1).isEmpty)
        XCTAssertTrue(dates(from: Date(), minute: 60).isEmpty)
        XCTAssertTrue(dates(from: Date(), days: 0).isEmpty)
    }

    // MARK: - 식별자

    func test_식별자는_spend_날짜형식() {
        let date = cal.date(from: DateComponents(year: 2026, month: 8, day: 7, hour: 21))!
        XCTAssertEqual(SpendReminderSchedule.identifier(for: date), "spend-20260807")
    }

    func test_식별자는_날짜마다_고유() {
        let result = dates(from: today(hour: 10))
        let ids = Set(result.map { SpendReminderSchedule.identifier(for: $0) })
        XCTAssertEqual(ids.count, result.count)
    }

    // MARK: - 설정 저장

    func test_기본값은_꺼짐_오후9시() {
        let sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))

        let config = sut.fetchBudgetConfig()
        XCTAssertEqual(config?.spendReminderEnabled, false)
        XCTAssertEqual(config?.spendReminderHour, 21)
        XCTAssertEqual(config?.spendReminderMinute, 0)
    }

    func test_설정_변경이_저장된다() {
        let sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))

        XCTAssertTrue(sut.updateSpendReminder(enabled: true, hour: 18, minute: 30))

        let config = sut.fetchBudgetConfig()
        XCTAssertEqual(config?.spendReminderEnabled, true)
        XCTAssertEqual(config?.spendReminderHour, 18)
        XCTAssertEqual(config?.spendReminderMinute, 30)
    }
}
