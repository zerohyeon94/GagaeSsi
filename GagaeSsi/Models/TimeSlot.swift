//
//  TimeSlot.swift
//  GagaeSsi
//
//  결제 시간대 버킷 (오전/점심/저녁/심야) + 집계
//

import Foundation

// MARK: - 시간대 버킷
enum TimeSlot: String, CaseIterable, Identifiable {
    case morning   // 오전 06:00–11:59
    case lunch     // 점심 12:00–16:59
    case evening   // 저녁 17:00–20:59
    case night     // 심야 21:00–05:59

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: return "오전"
        case .lunch:   return "점심"
        case .evening: return "저녁"
        case .night:   return "심야"
        }
    }

    var emoji: String {
        switch self {
        case .morning: return "🌅"
        case .lunch:   return "☀️"
        case .evening: return "🌆"
        case .night:   return "🌙"
        }
    }

    var rangeLabel: String {
        switch self {
        case .morning: return "06–12시"
        case .lunch:   return "12–17시"
        case .evening: return "17–21시"
        case .night:   return "21–06시"
        }
    }

    /// 소비 시각을 시간대 버킷으로 변환한다.
    /// 시각이 정확히 00:00:00이면 "시간 정보 없음"으로 간주해 nil을 반환한다
    /// (기존 startOfDay 저장 기록을 리포트에서 제외하기 위함).
    static func from(date: Date, calendar: Calendar = .current) -> TimeSlot? {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let h = c.hour ?? 0, m = c.minute ?? 0, s = c.second ?? 0
        if h == 0 && m == 0 && s == 0 { return nil }   // 시간 정보 없음

        switch h {
        case 6..<12:  return .morning
        case 12..<17: return .lunch
        case 17..<21: return .evening
        default:      return .night   // 21..24, 0..6
        }
    }

    /// 소비 기록을 시간대별로 집계한다.
    /// - Returns: 4개 버킷(0원 포함, enum 순서) + 시간 정보가 있는 기록 수
    static func totals(from records: [SpendingRecordModel],
                       calendar: Calendar = .current) -> (totals: [TimeSlotTotal], timedCount: Int) {
        var bySlot: [TimeSlot: Int] = [:]
        var timedCount = 0

        for record in records {
            guard let slot = TimeSlot.from(date: record.date, calendar: calendar) else { continue }
            bySlot[slot, default: 0] += record.myShare
            timedCount += 1
        }

        let grand = bySlot.values.reduce(0, +)
        let totals = TimeSlot.allCases.map { slot -> TimeSlotTotal in
            let amount = bySlot[slot] ?? 0
            let pct = grand > 0 ? Double(amount) / Double(grand) : 0
            return TimeSlotTotal(slot: slot, amount: amount, percentage: pct)
        }
        return (totals, timedCount)
    }
}

// MARK: - 시간대별 합계
struct TimeSlotTotal: Identifiable {
    var id: String { slot.rawValue }
    let slot: TimeSlot
    let amount: Int
    let percentage: Double
}
