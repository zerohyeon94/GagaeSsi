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
         periodStart: Date? = nil, periodEnd: Date? = nil, createdAt: Date = Date()) {
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
    }
}
