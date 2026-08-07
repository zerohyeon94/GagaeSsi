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
    case repaying  // 회복 중: 초과분을 나눠 갚는 중

    var label: String {
        switch self {
        case .stable: return "여유"
        case .caution: return "조심"
        case .over: return "걱정"
        case .covered: return "회복"
        case .repaying: return "회복 중"
        }
    }

    var emoji: String {
        switch self {
        case .stable: return "🐷"
        case .caution: return "🤔"
        case .over: return "😟"
        case .covered: return "😌"
        case .repaying: return "💪"
        }
    }

    var message: String {
        switch self {
        case .stable: return "여유로워요. 가게씨가 지켜볼게요!"
        case .caution: return "슬슬 조심할 때예요."
        case .over: return "오늘 예산을 넘었어요. 내일 조금 아껴봐요."
        case .covered: return "모아둔 이월금에서 채웠어요. 괜찮아요."
        case .repaying: return "초과분을 조금씩 갚는 중이에요. 잘 하고 있어요!"
        }
    }

    var color: Color {
        switch self {
        case .stable: return .gagaeGood
        case .caution: return .gagaeWarning
        case .over: return .gagaeDanger
        case .covered: return .gagaePinkDark
        case .repaying: return .gagaePinkDark
        }
    }

    /// 예산 카드 그라데이션
    var gradientColors: [Color] {
        switch self {
        case .stable: return [.gagaeBudgetCardTop, .gagaeBudgetCardBottom]
        case .caution: return [Color(hex: "#FFA94D"), Color(hex: "#FB8B1A")]
        case .over: return [Color(hex: "#F26666"), Color(hex: "#E13F47")]
        case .covered: return [.gagaePink, .gagaePinkDark]
        case .repaying: return [.gagaePink, .gagaePinkDark]
        }
    }

    /// 하루 예산(base) 대비 소비(spent)와 오늘 이월금 충당·초과분 상환 여부로 상태 결정.
    ///
    /// - Parameter todayAvailable: 오늘 실제로 쓸 수 있는 총액(이월 포함). 음수면 사용률과 무관하게
    ///   `over`다. 이 값을 보지 않으면 이월이 −29만원인데 오늘 소비가 적다는 이유로
    ///   "여유"가 뜨는 문제가 생긴다. `nil`이면 사용률만으로 판단한다.
    /// - 상환 중이더라도 오늘 예산을 또 넘겼으면 `over`가 우선한다 (지금 상태를 먼저 알려야 하므로).
    static func from(spent: Int, base: Int,
                     coveredFromPool: Bool,
                     repayingDebt: Bool = false,
                     todayAvailable: Int? = nil) -> CharacterState {
        // 총 가용액이 음수면 무엇보다 그 사실을 먼저 알려야 한다
        if let todayAvailable, todayAvailable < 0 { return .over }

        if coveredFromPool { return .covered }
        guard base > 0 else { return repayingDebt ? .repaying : .stable }

        let ratio = Double(spent) / Double(base)
        if ratio >= 1.0 { return .over }
        if repayingDebt { return .repaying }
        if ratio >= 0.7 { return .caution }
        return .stable
    }
}
