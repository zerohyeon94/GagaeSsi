//
//  CarryOverPoolModels.swift
//  GagaeSsi
//
//  모아둔 이월금 사용 원장 — 언제 왜 쌓이고 빠져나갔는지 남긴다.
//
//  기존에는 `CarryOverPoolEntry`가 금액과 날짜만 갖고 있어 잔액은 맞아도
//  "이 25,760원이 어디서 왔고 어디로 갔는지"를 알 수 없었다.
//  부채 상환 원장(`DebtRepaymentEntry.source`)과 같은 방식으로 사유를 남긴다.
//

import Foundation
import SwiftUI

/// 모아둔 이월금이 늘거나 준 이유
enum CarryOverPoolReason: String, Codable, CaseIterable {
    /// 하루가 지나며 남은 돈이 쌓임 (분리 모드 기본 동작)
    case deposit
    /// 이월 방식을 분리로 바꾸며 오늘 양수 이월을 옮김
    case sweep
    /// 사용자가 직접 오늘 예산으로 꺼냄
    case withdraw
    /// 소비 저장 후 부족액을 충당
    case shortfall
    /// 초과분(부채)을 갚는 데 씀
    case debtRepay

    static func from(_ raw: String?) -> CarryOverPoolReason {
        // 사유가 없던 기존 기록은 부호로 추정한다 (양수=적립, 음수=꺼내 쓰기)
        CarryOverPoolReason(rawValue: raw ?? "") ?? .deposit
    }

    /// 사유가 없는 옛 기록을 부호로 해석
    static func inferred(from raw: String?, amount: Int) -> CarryOverPoolReason {
        if let raw, let reason = CarryOverPoolReason(rawValue: raw) { return reason }
        return amount >= 0 ? .deposit : .withdraw
    }

    var label: String {
        switch self {
        case .deposit: return "아껴서 모임"
        case .sweep: return "이월 방식 전환"
        case .withdraw: return "꺼내 씀"
        case .shortfall: return "부족액 충당"
        case .debtRepay: return "초과분 갚기"
        }
    }

    var emoji: String {
        switch self {
        case .deposit: return "🐷"
        case .sweep: return "🔁"
        case .withdraw: return "✋"
        case .shortfall: return "🩹"
        case .debtRepay: return "💪"
        }
    }

    /// 풀에 들어오는 방향인지
    var isIncoming: Bool {
        switch self {
        case .deposit, .sweep: return true
        case .withdraw, .shortfall, .debtRepay: return false
        }
    }
}

/// 모아둔 이월금 원장 한 줄
struct CarryOverPoolEntryModel: Identifiable, Equatable {
    var id: UUID
    var date: Date
    /// 양수면 적립, 음수면 사용
    var amount: Int
    var reason: CarryOverPoolReason

    var isIncoming: Bool { amount >= 0 }

    init(id: UUID = UUID(), date: Date, amount: Int, reason: CarryOverPoolReason) {
        self.id = id
        self.date = date
        self.amount = amount
        self.reason = reason
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: CarryOverPoolEntry) {
        let value = Int(truncating: entity.amount ?? 0)
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.amount = value
        self.reason = CarryOverPoolReason.inferred(from: entity.reason, amount: value)
    }
}

/// 기간 집계 (순수 로직)
struct CarryOverPoolSummary: Equatable {
    var depositTotal: Int = 0
    var usedTotal: Int = 0

    var net: Int { depositTotal - usedTotal }

    static func make(from entries: [CarryOverPoolEntryModel]) -> CarryOverPoolSummary {
        var summary = CarryOverPoolSummary()
        for entry in entries {
            if entry.amount >= 0 {
                summary.depositTotal += entry.amount
            } else {
                summary.usedTotal += -entry.amount
            }
        }
        return summary
    }

    /// 사유별 사용액 (많이 쓴 순)
    static func usageByReason(from entries: [CarryOverPoolEntryModel]) -> [(reason: CarryOverPoolReason, amount: Int)] {
        var map: [CarryOverPoolReason: Int] = [:]
        for entry in entries where entry.amount < 0 {
            map[entry.reason, default: 0] += -entry.amount
        }
        return map.map { (reason: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
