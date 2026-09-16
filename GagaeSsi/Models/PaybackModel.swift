//
//  PaybackModel.swift
//  GagaeSsi
//
//  미확정·기간형 페이백 (환급 건의 생명주기 관리)
//

import Foundation

// MARK: - 페이백 유형
enum PaybackType: String, CaseIterable, Identifiable, Codable {
    case transaction = "연결형"   // 특정 결제에 대한 캐시백/포인트
    case period = "기간형"        // K-패스처럼 기간 합산

    var id: String { rawValue }
    var label: String { rawValue }
    static func from(_ raw: String?) -> PaybackType { PaybackType(rawValue: raw ?? "") ?? .transaction }
}

// MARK: - 페이백 상태 (생명주기)
enum PaybackStatus: String, CaseIterable, Codable {
    case estimated = "예상"   // 예상값(또는 미확정)
    case confirmed = "확정"   // 기관에서 금액 확정
    case received = "수령"    // 실제 입금 완료
    case cancelled = "취소"   // 환급 대상 아님/취소

    var label: String { rawValue }
    var emoji: String {
        switch self {
        case .estimated: return "❓"
        case .confirmed: return "📩"
        case .received: return "✅"
        case .cancelled: return "🚫"
        }
    }
    static func from(_ raw: String?) -> PaybackStatus { PaybackStatus(rawValue: raw ?? "") ?? .estimated }
}

// MARK: - 페이백 모델
struct PaybackModel: Identifiable {
    var id: UUID
    var title: String
    var type: PaybackType
    var status: PaybackStatus
    var estimatedAmount: Int
    var confirmedAmount: Int
    var receivedAmount: Int
    var expectedDate: Date?
    var receivedDate: Date?
    var periodStart: Date?
    var periodEnd: Date?
    var createdAt: Date
    /// 기간형에서 자동으로 묶을 소비 카테고리 (nil이면 수동 입력)
    var linkedCategory: SpendingCategory?
    /// 환급률 % (0이면 미사용). 묶인 소비 합계 × 이 비율로 예상액을 계산한다.
    var refundRatePercent: Int

    /// 현재 대표 금액 (수령>확정>예상 순)
    var currentAmount: Int {
        if receivedAmount > 0 { return receivedAmount }
        if confirmedAmount > 0 { return confirmedAmount }
        return estimatedAmount
    }

    init(id: UUID = UUID(), title: String, type: PaybackType = .transaction,
         status: PaybackStatus = .estimated,
         estimatedAmount: Int = 0, confirmedAmount: Int = 0, receivedAmount: Int = 0,
         expectedDate: Date? = nil, receivedDate: Date? = nil,
         periodStart: Date? = nil, periodEnd: Date? = nil, createdAt: Date = Date(),
         linkedCategory: SpendingCategory? = nil, refundRatePercent: Int = 0) {
        self.id = id
        self.title = title
        self.type = type
        self.status = status
        self.estimatedAmount = estimatedAmount
        self.confirmedAmount = confirmedAmount
        self.receivedAmount = receivedAmount
        self.expectedDate = expectedDate
        self.receivedDate = receivedDate
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.createdAt = createdAt
        self.linkedCategory = linkedCategory
        self.refundRatePercent = refundRatePercent
    }

    init(entity: Payback) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.type = PaybackType.from(entity.type)
        self.status = PaybackStatus.from(entity.status)
        self.estimatedAmount = Int(entity.estimatedAmount)
        self.confirmedAmount = Int(entity.confirmedAmount)
        self.receivedAmount = Int(entity.receivedAmount)
        self.expectedDate = entity.expectedDate
        self.receivedDate = entity.receivedDate
        self.periodStart = entity.periodStart
        self.periodEnd = entity.periodEnd
        self.createdAt = entity.createdAt ?? Date()
        self.linkedCategory = entity.linkedCategory.flatMap { SpendingCategory(rawValue: $0) }
        self.refundRatePercent = Int(entity.refundRatePercent)
    }

    /// 기간 내 묶인 소비 합계로 예상 환급액을 계산한다 (원 단위 내림).
    /// 환급률이 0이면 자동 계산하지 않는다 — 사용자가 직접 적은 금액을 덮어쓰면 안 된다.
    func estimatedRefund(fromLinkedTotal total: Int) -> Int? {
        guard refundRatePercent > 0, total > 0 else { return nil }
        return total * refundRatePercent / 100
    }

    /// 소비를 자동으로 묶을 수 있는 상태인지 (기간형 + 카테고리 지정)
    var canLinkSpending: Bool {
        type == .period && linkedCategory != nil && periodStart != nil && periodEnd != nil
    }
}
