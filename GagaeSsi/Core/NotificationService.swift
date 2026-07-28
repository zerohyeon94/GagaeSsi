//
//  NotificationService.swift
//  GagaeSsi
//
//  변동 고정비 지출일 로컬 알림 (오전 + 오후 재알림)
//

import Foundation
import UserNotifications

/// 알림 시각 상수 및 다음 알림일 계산 (순수 로직 — 테스트 가능)
enum VariableCostReminder {
    static let morningHour = 9    // 오전 9시
    static let afternoonHour = 20 // 오후 8시

    /// 다음 "미확정" 지출일(자정 기준)을 계산한다.
    /// - 이번 달 지출일이 오늘 이후이고 이번 달이 미확정이면 → 이번 달 지출일
    /// - 지출일이 지났거나 이번 달이 이미 확정이면 → 다음 달 지출일
    /// - dueDay는 그 달 말일로 clamp
    static func nextDueDate(dueDay: Int,
                            from today: Date,
                            isCurrentMonthConfirmed: Bool,
                            calendar: Calendar = .current) -> Date? {
        guard dueDay >= 1, dueDay <= 31 else { return nil }
        let todayStart = calendar.startOfDay(for: today)

        func dueDate(monthsAhead: Int) -> Date {
            let base = calendar.date(byAdding: .month, value: monthsAhead, to: todayStart)!
            let c = calendar.dateComponents([.year, .month], from: base)
            let first = calendar.date(from: DateComponents(year: c.year, month: c.month, day: 1))!
            let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
            let day = min(dueDay, daysInMonth)
            return calendar.startOfDay(for:
                calendar.date(from: DateComponents(year: c.year, month: c.month, day: day))!)
        }

        let thisMonthDue = dueDate(monthsAhead: 0)
        if todayStart <= thisMonthDue && !isCurrentMonthConfirmed {
            return thisMonthDue
        }
        return dueDate(monthsAhead: 1)
    }
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "vcost-"

    // MARK: - 권한
    /// 아직 결정되지 않았으면 권한을 요청한다 (거부/허용 이미 결정 시 아무것도 안 함).
    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self?.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - 스케줄 갱신
    /// 모든 변동 고정비의 지출일 알림을 현재 상태 기준으로 재설정한다.
    /// 확정/추가/수정/삭제 후, 그리고 앱 활성화 시 호출한다.
    func refreshVariableCostReminders(costs: [FixedCostModel],
                                      isConfirmed: @escaping (UUID) -> Bool,
                                      now: Date = Date()) {
        // 기존 vcost 알림 제거
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            for cost in costs where cost.isVariable && cost.dueDay >= 1 {
                guard let due = VariableCostReminder.nextDueDate(
                    dueDay: cost.dueDay, from: now,
                    isCurrentMonthConfirmed: isConfirmed(cost.id)) else { continue }
                self.schedule(cost: cost, dueDate: due, hour: VariableCostReminder.morningHour, suffix: "am")
                self.schedule(cost: cost, dueDate: due, hour: VariableCostReminder.afternoonHour, suffix: "pm")
            }
        }
    }

    private func schedule(cost: FixedCostModel, dueDate: Date, hour: Int, suffix: String) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = hour
        comps.minute = 0

        // 이미 지난 시각이면 스케줄하지 않는다
        if let fireDate = Calendar.current.date(from: comps), fireDate <= Date() { return }

        let content = UNMutableNotificationContent()
        content.title = "가계씨 💳"
        content.body = suffix == "am"
            ? "오늘은 ‘\(cost.title)’ 지출일이에요. 확정 금액을 입력해주세요."
            : "‘\(cost.title)’ 확정 금액을 아직 입력하지 않았어요. 결제됐다면 지금 입력해요."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "\(idPrefix)\(cost.id.uuidString)-\(suffix)",
                                            content: content, trigger: trigger)
        center.add(request)
    }

    /// 모든 변동 고정비 알림 제거 (예: 데이터 초기화)
    func cancelAllVariableCostReminders() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
