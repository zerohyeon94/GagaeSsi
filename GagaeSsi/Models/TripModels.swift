//
//  TripModels.swift
//  GagaeSsi
//
//  여행 — 같이 쓴 돈을 묶고, 내 몫만 예산에서 빼고, 나중에 정산한다.
//  정산 단위는 소비 건이 아니라 여행이다. 소비에는 인원·결제자만 표시하고 나머지는 여기서 계산한다.
//

import Foundation

// MARK: - 여행 상태
enum TripStatus: String, Codable {
    case active = "진행중"
    case settled = "정산완료"

    static func from(_ raw: String?) -> TripStatus { TripStatus(rawValue: raw ?? "") ?? .active }
}

// MARK: - 여행 모델
struct TripModel: Identifiable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    /// 소비 입력 시 인원 기본값. 항목마다 바꿀 수 있다.
    var defaultParticipants: Int
    var status: TripStatus
    var settledAt: Date?
    /// 정산 때 실제로 돌려받은(되돌린) 금액
    var settledAmount: Int
    /// 정산 때 만든 크레딧(지갑 저금 엔트리 또는 이월 항목)의 id. 다시 열 때 이걸로 찾아 지운다.
    var settlementEntryId: UUID?
    var createdAt: Date
    /// 연결된 위시 지갑. 있으면 내가 내는 소비는 여기서 먼저 빠지고 정산 회수도 여기로 돌아온다.
    var wishItemId: UUID?

    var isSettled: Bool { status == .settled }

    /// 소비 날짜가 여행 기간(시작일·종료일 포함) 안인지. 자동 선택 판단에만 쓴다 — 기간 밖 소비도 묶을 수 있다.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return calendar.startOfDay(for: startDate) <= day && day <= calendar.startOfDay(for: endDate)
    }

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date,
         defaultParticipants: Int = 2, status: TripStatus = .active,
         settledAt: Date? = nil, settledAmount: Int = 0, settlementEntryId: UUID? = nil,
         createdAt: Date = Date(), wishItemId: UUID? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.defaultParticipants = max(1, defaultParticipants)
        self.status = status
        self.settledAt = settledAt
        self.settledAmount = settledAmount
        self.settlementEntryId = settlementEntryId
        self.createdAt = createdAt
        self.wishItemId = wishItemId
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: Trip) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.startDate = entity.startDate ?? Date()
        self.endDate = entity.endDate ?? self.startDate
        self.defaultParticipants = max(1, Int(entity.defaultParticipants))
        self.status = TripStatus.from(entity.status)
        self.settledAt = entity.settledAt
        self.settledAmount = Int(entity.settledAmount)
        self.settlementEntryId = entity.settlementEntryId
        self.createdAt = entity.createdAt ?? Date()
        self.wishItemId = entity.wishItem?.id
    }
}

// MARK: - 정산 집계 (순수 계산)

/// 여행에 묶인 소비들을 한 번에 집계한다. 정산 화면·목록 요약이 이 값을 그대로 보여준다.
struct TripSettlementModel: Equatable {
    /// 여행 소비 전액 합 (내가 낸 것 + 남이 낸 것)
    let totalPaid: Int
    /// 공용(인원 > 1) 소비의 전액 합
    let sharedTotal: Int
    /// Σ myShare — 내가 소비한 돈. 통계와 같은 값.
    let myShareTotal: Int
    /// 내가 실제로 낸 돈
    let paidByMeTotal: Int
    /// Σ receivable — 정산 때 돌아올 남의 몫
    let receivable: Int
    /// 지갑에 연결된 소비의 예산 반영액 합
    let fromWallet: Int
    /// 예산에서 빠진 소비의 예산 반영액 합
    let fromBudget: Int
    /// 공용 소비의 인원이 전부 같으면 그 값. 섞여 있으면 nil ("인당" 줄을 보여줄지 판단)
    let uniformParticipants: Int?

    /// 인원이 하나로 통일돼 있을 때의 인당 금액 (공용 합 ÷ 인원, 내림)
    var perPerson: Int? {
        guard let n = uniformParticipants, n > 0 else { return nil }
        return sharedTotal / n
    }

    /// 항목별로 계산해 더한다 — 합계를 한 번에 나누지 않는다.
    ///
    /// 통계·내역도 소비 건마다 `myShare`를 더하므로, 여기서 합계를 나누면 같은 소비가
    /// 화면마다 다른 금액으로 보인다. 항목별 합산이라야 `Σ budgetAmount − receivable`이
    /// 통계와 정확히 맞아떨어진다 (나머지 원은 돈을 돌려줄 친구 쪽에 붙는다).
    static func compute(records: [SpendingRecordModel]) -> TripSettlementModel {
        var totalPaid = 0, sharedTotal = 0, myShareTotal = 0, paidByMeTotal = 0
        var receivable = 0, fromWallet = 0, fromBudget = 0
        var participantSet = Set<Int>()

        for r in records {
            totalPaid += r.amount
            myShareTotal += r.myShare
            receivable += r.receivable
            if r.isShared {
                sharedTotal += r.amount
                participantSet.insert(r.participants)
            }
            if r.paidByMe { paidByMeTotal += r.amount }
            if r.wishItemId != nil { fromWallet += r.budgetAmount } else { fromBudget += r.budgetAmount }
        }

        return TripSettlementModel(totalPaid: totalPaid, sharedTotal: sharedTotal,
                                   myShareTotal: myShareTotal, paidByMeTotal: paidByMeTotal,
                                   receivable: receivable, fromWallet: fromWallet, fromBudget: fromBudget,
                                   uniformParticipants: participantSet.count == 1 ? participantSet.first : nil)
    }
}
