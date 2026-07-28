//
//  WishModels.swift
//  GagaeSsi
//
//  위시리스트 저금 모델 (v1.2 + 희망/필수 구분)
//

import Foundation

// MARK: - 위시 상태
enum WishStatus: String, Codable {
    case waiting = "대기"        // 목록에만 존재, 저금 안 함
    case saving = "저금중"       // 활성 — 매일 저금 차감
    case purchasable = "구매가능"  // 목표 도달, 저금 중지
    case completed = "완료"      // 구매 완료 처리됨

    static func from(_ raw: String?) -> WishStatus {
        WishStatus(rawValue: raw ?? "") ?? .waiting
    }
}

// MARK: - 위시 종류 (희망 vs 필수)
enum WishKind: String, Codable, CaseIterable, Identifiable {
    case want = "희망"   // 사고 싶은 것
    case need = "필수"   // 꼭 사야 하는 것

    var id: String { rawValue }
    var emoji: String { self == .want ? "💖" : "🎯" }
    var label: String { rawValue }

    static func from(_ raw: String?) -> WishKind {
        WishKind(rawValue: raw ?? "") ?? .want
    }
}

// MARK: - 위시 아이템 모델
struct WishItemModel: Identifiable {
    var id: UUID
    var title: String
    var targetAmount: Int
    var dailySaving: Int
    var status: WishStatus
    var kind: WishKind
    var createdAt: Date
    var activatedAt: Date?
    var completedAt: Date?
    /// 누적 저금액 (저금 엔트리 합계). fetch 시 매니저가 채운다.
    var savedAmount: Int

    // MARK: - Computed
    /// 목표 대비 저금 진행률 (0~1)
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return max(0, min(1, Double(savedAmount) / Double(targetAmount)))
    }

    /// 목표까지 남은 금액
    var remainingAmount: Int { max(0, targetAmount - savedAmount) }

    /// 남은 저금 일수 (올림). dailySaving이 0이면 nil.
    var daysLeft: Int? {
        guard dailySaving > 0 else { return nil }
        if remainingAmount <= 0 { return 0 }
        return Int((Double(remainingAmount) / Double(dailySaving)).rounded(.up))
    }

    // MARK: - Init
    init(id: UUID = UUID(), title: String, targetAmount: Int, dailySaving: Int = 0,
         status: WishStatus = .waiting, kind: WishKind = .want,
         createdAt: Date = Date(), activatedAt: Date? = nil, completedAt: Date? = nil,
         savedAmount: Int = 0) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.dailySaving = dailySaving
        self.status = status
        self.kind = kind
        self.createdAt = createdAt
        self.activatedAt = activatedAt
        self.completedAt = completedAt
        self.savedAmount = savedAmount
    }

    /// CoreData Entity -> Model 변환 생성자 (savedAmount는 별도 주입)
    init(entity: WishItem, savedAmount: Int = 0) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.targetAmount = Int(truncating: entity.targetAmount ?? 0)
        self.dailySaving = Int(truncating: entity.dailySaving ?? 0)
        self.status = WishStatus.from(entity.status)
        self.kind = WishKind.from(entity.kind)
        self.createdAt = entity.createdAt ?? Date()
        self.activatedAt = entity.activatedAt
        self.completedAt = entity.completedAt
        self.savedAmount = savedAmount
    }
}

// MARK: - 위시 저금 엔트리 모델 (일자별)
struct WishSavingEntryModel: Identifiable {
    var id: UUID
    var date: Date
    var amount: Int

    init(id: UUID = UUID(), date: Date, amount: Int) {
        self.id = id
        self.date = date
        self.amount = amount
    }

    init(entity: WishSavingEntry) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.amount = Int(truncating: entity.amount ?? 0)
    }
}
