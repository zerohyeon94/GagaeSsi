//
//  AssetTransferModels.swift
//  GagaeSsi
//
//  저축·투자 기록 — "투자는 소비가 아니라 이동"
//
//  주식을 사거나 적금에 넣은 돈은 예산에서 빠지지만 **쓴 돈이 아니다.**
//  소비로 기록하면 이번 달 소비가 부풀고 카테고리 통계가 왜곡된다.
//
//  그래서 위시리스트 저금과 같은 구조를 쓴다 — SpendingRecord를 만들지 않고
//  DailyBudget에 별도 관계로 달아 `todayAvailable`에서만 차감한다. 덕분에
//  소비 통계·초과한 날 판정에는 잡히지 않는다.
//

import Foundation
import SwiftUI

/// 이동의 종류
enum AssetTransferKind: String, Codable, CaseIterable, Identifiable {
    case saving = "저축"
    case investment = "투자"

    var id: String { rawValue }
    var label: String { rawValue }

    var emoji: String {
        switch self {
        case .saving: return "🐷"
        case .investment: return "📈"
        }
    }

    var color: Color {
        switch self {
        case .saving: return .gagaeGood
        case .investment: return Color(hex: "#5D65E8")
        }
    }

    var placeholder: String {
        switch self {
        case .saving: return "예: 청약, 비상금"
        case .investment: return "예: S&P500, 삼성전자"
        }
    }

    static func from(_ raw: String?) -> AssetTransferKind {
        AssetTransferKind(rawValue: raw ?? "") ?? .investment
    }
}

/// 저축·투자 기록
struct AssetTransferModel: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var amount: Int
    var title: String
    var kind: AssetTransferKind

    init(id: UUID = UUID(), date: Date, amount: Int,
         title: String, kind: AssetTransferKind = .investment) {
        self.id = id
        self.date = date
        self.amount = amount
        self.title = title
        self.kind = kind
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: AssetTransfer) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.amount = Int(truncating: entity.amount ?? 0)
        self.title = entity.title ?? ""
        self.kind = AssetTransferKind.from(entity.kind)
    }
}

/// 기간별 저축·투자 집계 (순수 로직)
struct AssetTransferSummary: Equatable {
    var savingTotal: Int = 0
    var investmentTotal: Int = 0

    var total: Int { savingTotal + investmentTotal }

    func total(of kind: AssetTransferKind) -> Int {
        switch kind {
        case .saving: return savingTotal
        case .investment: return investmentTotal
        }
    }

    static func make(from transfers: [AssetTransferModel]) -> AssetTransferSummary {
        var summary = AssetTransferSummary()
        for transfer in transfers {
            switch transfer.kind {
            case .saving: summary.savingTotal += transfer.amount
            case .investment: summary.investmentTotal += transfer.amount
            }
        }
        return summary
    }
}
