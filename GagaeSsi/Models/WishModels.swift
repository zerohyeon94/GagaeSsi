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
    /// 모은 돈 (저금 엔트리 합계)
    var savedAmount: Int
    /// 이 위시 지갑에서 쓴 소비 합계
    var spentAmount: Int
    /// 여행 정산으로 이 지갑에 돌아온 돈 합계 (`savedAmount`에 포함돼 있다 — 표시용 구분값)
    var returnedAmount: Int

    // MARK: - Computed
    /// 지갑에 남은 돈. 목표를 채운 뒤 여행 등에 쓰면 여기서 빠진다.
    /// 정산으로 돌아온 돈도 지갑이 실제로 들고 있는 돈이라 여기엔 포함한다 — 쓸 수 있는 돈이다.
    var balance: Int { max(0, savedAmount - spentAmount) }
    /// 지갑에서 쓴 적이 있는지 (있으면 목록에서 게이지 대신 잔액을 보여준다)
    var hasSpending: Bool { spentAmount > 0 }

    /// 목표를 향해 "내가 모은 돈" = `savedAmount − returnedAmount`.
    ///
    /// 여행 정산으로 돌아온 돈은 애초에 내가 대신 냈던 돈이 돌아온 것일 뿐, 목표를 향해 새로
    /// 모은 돈이 아니다. 지출이 `savedAmount`를 줄이지 않으므로 `savedAmount`에 그대로 더하면
    /// 쓴 돈이 돌아오기만 해도 목표 진행률이 오르는 이중 계산이 된다 — `progress`·
    /// `remainingAmount`·`daysLeft`는 반드시 이 값을 써야 한다. 지갑이 실제로 쥔 돈(`balance`)은
    /// 이 값과 다르다 — 정산금은 쓸 수는 있지만 목표 진행에는 세지 않는다.
    var goalContribution: Int { max(0, savedAmount - returnedAmount) }

    /// 목표 대비 저금 진행률 (0~1). 정산으로 돌아온 돈은 세지 않는다 — `goalContribution` 참고.
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return max(0, min(1, Double(goalContribution) / Double(targetAmount)))
    }

    /// 목표까지 남은 금액. 정산으로 돌아온 돈은 세지 않는다 — `goalContribution` 참고.
    var remainingAmount: Int { max(0, targetAmount - goalContribution) }

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
         savedAmount: Int = 0, spentAmount: Int = 0, returnedAmount: Int = 0) {
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
        self.spentAmount = spentAmount
        self.returnedAmount = returnedAmount
    }

    /// CoreData Entity -> Model 변환 생성자 (savedAmount·spentAmount·returnedAmount는 별도 주입)
    init(entity: WishItem, savedAmount: Int = 0, spentAmount: Int = 0, returnedAmount: Int = 0) {
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
        self.spentAmount = spentAmount
        self.returnedAmount = returnedAmount
    }
}

// MARK: - 저금 엔트리 출처
/// nil이면 매일 저금. 여행 정산으로 돌아온 돈은 저금이 아니라 회수라 구분해서 보여준다.
enum WishSavingSource: String, Codable {
    case tripSettlement

    static func from(_ raw: String?) -> WishSavingSource? {
        raw.flatMap(WishSavingSource.init(rawValue:))
    }
}

// MARK: - 위시 저금 엔트리 모델 (일자별)
struct WishSavingEntryModel: Identifiable {
    var id: UUID
    var date: Date
    var amount: Int
    var source: WishSavingSource?

    init(id: UUID = UUID(), date: Date, amount: Int, source: WishSavingSource? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.source = source
    }

    init(entity: WishSavingEntry) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.amount = Int(truncating: entity.amount ?? 0)
        self.source = WishSavingSource.from(entity.source)
    }
}
