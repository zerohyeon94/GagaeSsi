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
struct TripModel: Identifiable, Equatable {
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

    /// 소비 날짜가 여행 기간(시작일·종료일 포함) 안인지. 소비 입력의 여행 목록과 자동 선택이 이 판정을 쓴다.
    /// 이미 묶인 소비는 기간 밖이어도 연결을 유지한다 — 여행 기간을 줄여도 자동으로 풀지 않는다(#32).
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return calendar.startOfDay(for: startDate) <= day && day <= calendar.startOfDay(for: endDate)
    }

    /// 기간이 끝났는데 아직 정산하지 않은 여행 — 여행 목록에서 '정산 대기'로 따로 묶는다
    func isAwaitingSettlement(asOf today: Date = Date(), calendar: Calendar = .current) -> Bool {
        !isSettled && calendar.startOfDay(for: endDate) < calendar.startOfDay(for: today)
    }

    /// 소비 입력 화면은 여행을 고르기만 한다 — 기간·기본 인원·지갑은 여행 화면에서만 고친다 (#32)
    static let editHint = "여행 기간·기본 인원은 설정 › 여행에서 고쳐요"

    /// 이 소비 한 건의 인원이 여행 기본 인원과 다르면 그 차이를 한 줄로. 같으면 nil.
    /// 소비 입력에서 바꾼 인원이 여행 자체를 고친 것처럼 읽히지 않게 한다 (#32).
    func shareOverrideNote(participants: Int) -> String? {
        guard participants != defaultParticipants else { return nil }
        let mine = participants == 1 ? "이 소비는 나 혼자 쓴 거예요" : "이 소비만 \(participants)명이에요"
        return "\(mine) · 여행 기본 인원은 \(defaultParticipants)명"
    }

    /// 묶인 소비 중 여행 기간 밖 날짜의 건수. 기간을 줄여도 연결은 자동으로 풀지 않으므로
    /// (정산 금액이 조용히 바뀐다) 여행 수정·상세에서 눈에 띄게 알리는 데 쓴다 (#32).
    func outsidePeriodCount(of dates: [Date], calendar: Calendar = .current) -> Int {
        dates.filter { !contains($0, calendar: calendar) }.count
    }

    /// 소비 날짜에 고를 수 있는 여행.
    ///
    /// 기준은 '오늘'이 아니라 **소비 날짜**다 — 여행 다녀와서 며칠 뒤 영수증을 입력해도 그 여행이 떠야 한다.
    /// - 정산 안 했고 소비 날짜가 기간 안인 여행
    /// - 편집 중인 기록이 원래 묶여 있던 여행(`linkedId`)은 기간·정산과 무관하게 남긴다 (정산 완료면 잠긴 채로)
    static func selectable(from trips: [TripModel], on date: Date, keeping linkedId: UUID?,
                           calendar: Calendar = .current) -> [TripModel] {
        trips.filter { trip in
            trip.id == linkedId || (!trip.isSettled && trip.contains(date, calendar: calendar))
        }
    }

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date,
         defaultParticipants: Int = 2, status: TripStatus = .active,
         settledAt: Date? = nil, settledAmount: Int = 0, settlementEntryId: UUID? = nil,
         createdAt: Date = Date(), wishItemId: UUID? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        // 종료일이 시작일보다 앞서면 기간 판정이 모든 날짜에 대해 거짓이 된다 — 하루짜리로 접는다
        self.endDate = max(startDate, endDate)
        // 소비 기록의 인원 한계(999명)와 맞춘다 — 여행 기본값이 더 크면 항목마다 잘려 어긋난다
        self.defaultParticipants = min(999, max(1, defaultParticipants))
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
        // 종료일이 시작일보다 앞서면 기간 판정이 모든 날짜에 대해 거짓이 된다 — 하루짜리로 접는다
        self.endDate = max(self.startDate, entity.endDate ?? self.startDate)
        // 소비 기록의 인원 한계(999명)와 맞춘다 — 여행 기본값이 더 크면 항목마다 잘려 어긋난다
        self.defaultParticipants = min(999, max(1, Int(entity.defaultParticipants)))
        self.status = TripStatus.from(entity.status)
        self.settledAt = entity.settledAt
        self.settledAmount = Int(entity.settledAmount)
        self.settlementEntryId = entity.settlementEntryId
        self.createdAt = entity.createdAt ?? Date()
        self.wishItemId = entity.wishItem?.id
    }
}

// MARK: - 여행 선택이 채운 분담값

/// 여행을 골라 인원·결제자를 **자동으로** 채웠을 때 그 값을 기억한다 (#31).
///
/// "여행 아님"으로 풀 때 되돌릴지를 가르는 기준이다. 이 화면에서 여행 선택이 채운 값이면 되돌리고,
/// 사용자가 손댔거나 기록에서 불러온 값(예: 여행이 지워진 분담 기록)이면 그대로 둔다 —
/// 후자를 1/true로 되돌리면 화면엔 안 보이던 값이 저장 때 조용히 바뀐다.
/// (`walletManuallyPicked`가 지갑에 하는 것과 같은 방식)
struct TripShareAutofill: Equatable {
    let participants: Int
    let paidByMe: Bool

    /// 여행을 풀 때 쓸 분담값. 자동으로 채운 값 그대로면 개인 소비(1명·내가 냄)로, 손댔으면 지금 값 그대로.
    func released(participants: Int, paidByMe: Bool) -> (participants: Int, paidByMe: Bool) {
        guard participants == self.participants, paidByMe == self.paidByMe else { return (participants, paidByMe) }
        return (1, true)
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

    /// 이 여행이 예산·지갑에서 실제로 빼간 돈 (지갑 + 예산). 정산 화면의 "지갑에서 X · 예산에서 Y" 합계.
    var budgetTotal: Int { fromWallet + fromBudget }

    /// **표시용** 인당 소비액 (공용 합 ÷ 인원, 내림). 공용 소비가 없으면 nil.
    ///
    /// 받을 돈 계산에 쓰면 안 된다 — `perPersonSpending × (인원−1)`은 항목별 버림 나머지 때문에
    /// `receivable`과 어긋난다. 친구 개인별 채권은 이 앱의 범위 밖이다 (설계 9절).
    var perPersonSpending: Int? {
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
