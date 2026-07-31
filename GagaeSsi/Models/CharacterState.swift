//
//  CharacterState.swift
//  GagaeSsi
//
//  캐릭터(가게씨) 소비 상태 — 절대액이 아닌 하루 예산 사용률 기반.
//  죄책감을 강하게 유발하기보다 여유·조심·걱정·회복의 순한 감정으로 안내한다.
//

import SwiftUI

enum CharacterState {
    case stable    // 안정: 하루 예산의 70% 미만 사용
    case caution   // 주의: 70% 이상 100% 미만
    case over      // 초과: 100% 이상 (이월금 충당 안 함)
    case covered   // 회복: 초과했지만 모아둔 이월금으로 채움

    var label: String {
        switch self {
        case .stable: return "여유"
        case .caution: return "조심"
        case .over: return "걱정"
        case .covered: return "회복"
        }
    }

    var emoji: String {
        switch self {
        case .stable: return "🐷"
        case .caution: return "🤔"
        case .over: return "😟"
        case .covered: return "😌"
        }
    }

    var message: String {
        switch self {
        case .stable: return "여유로워요. 가게씨가 지켜볼게요!"
        case .caution: return "슬슬 조심할 때예요."
        case .over: return "오늘 예산을 넘었어요. 내일 조금 아껴봐요."
        case .covered: return "모아둔 이월금에서 채웠어요. 괜찮아요."
        }
    }

    var color: Color {
        switch self {
        case .stable: return .gagaeGood
        case .caution: return .gagaeWarning
        case .over: return .gagaeDanger
        case .covered: return .gagaePinkDark
        }
    }

    /// 예산 카드 그라데이션
    var gradientColors: [Color] {
        switch self {
        case .stable: return [.gagaeBudgetCardTop, .gagaeBudgetCardBottom]
        case .caution: return [Color(hex: "#FFA94D"), Color(hex: "#FB8B1A")]
        case .over: return [Color(hex: "#F26666"), Color(hex: "#E13F47")]
        case .covered: return [.gagaePink, .gagaePinkDark]
        }
    }

    /// 하루 예산(base) 대비 소비(spent)와 오늘 이월금 충당 여부로 상태 결정
    static func from(spent: Int, base: Int, coveredFromPool: Bool) -> CharacterState {
        if coveredFromPool { return .covered }
        guard base > 0 else { return .stable }
        let ratio = Double(spent) / Double(base)
        if ratio >= 1.0 { return .over }
        if ratio >= 0.7 { return .caution }
        return .stable
    }
}
