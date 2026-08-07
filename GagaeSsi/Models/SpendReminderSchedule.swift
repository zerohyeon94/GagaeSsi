//
//  SpendReminderSchedule.swift
//  GagaeSsi
//
//  소비 기록 리마인더 예약 대상 날짜 계산 (순수 로직 — 테스트 가능)
//

import Foundation

enum SpendReminderSchedule {
    /// 기본 알림 시각 (오후 9시)
    static let defaultHour = 21
    static let defaultMinute = 0

    /// 한 번에 예약해두는 일수. iOS 로컬 알림은 발송 시점에 앱 데이터를 볼 수 없고
    /// `repeats: true`는 특정 날짜만 취소할 수 없으므로, 개별 예약 후 rolling 갱신한다.
    static let scheduleDays = 14

    /// `now`부터 `days`일 동안 실제로 예약할 발송 시각 목록을 계산한다.
    /// - 이미 지난 시각은 제외한다.
    /// - `hasRecord(날짜) == true`인 날은 제외한다 (그날 소비를 이미 기록함).
    ///   미래 날짜는 아직 기록이 있을 수 없으므로 사실상 오늘만 걸러진다.
    static func pendingDates(from now: Date,
                             hour: Int, minute: Int,
                             days: Int = scheduleDays,
                             hasRecord: (Date) -> Bool,
                             calendar: Calendar = .current) -> [Date] {
        guard days > 0, (0...23).contains(hour), (0...59).contains(minute) else { return [] }
        let todayStart = calendar.startOfDay(for: now)

        return (0..<days).compactMap { offset -> Date? in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: todayStart),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute,
                                               second: 0, of: dayStart) else { return nil }
            guard fireDate > now else { return nil }      // 이미 지난 시각은 예약하지 않음
            guard !hasRecord(dayStart) else { return nil } // 그날 이미 기록함
            return fireDate
        }
    }

    /// 알림 식별자 (`spend-YYYYMMDD`)
    static func identifier(for fireDate: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: fireDate)
        return String(format: "spend-%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
