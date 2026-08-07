//
//  DebtModels.swift
//  GagaeSsi
//
//  초과 소비 상환 계획 모델 (초과분을 부채로 분리해 하루 예산의 %씩 분할 상환)
//

import Foundation

// MARK: - 상환 계획 계산 (순수 로직)

enum DebtRepaymentPlan {
    /// 선택 가능한 상환 비율 (하루 예산 대비 %). 5% 단위.
    static let rateOptions: [Int] = Array(stride(from: 10, through: 50, by: 5))

    /// 기본 추천 비율. 50/30/20 법칙(세후 소득의 20%를 저축·부채 상환에 배정)에서 따왔다.
    static let defaultRate = 20

    /// 초과분을 부채로 전환할 임계 비율. 이보다 작은 초과는 기존대로 음수 이월된다.
    static let thresholdRate = 10

    /// 한국 DSR 규제 상한(은행권 40%). 이상을 고르면 경고를 노출한다.
    static let aggressiveRate = 40

    /// 부채 전환 임계값 = 기본 일일 예산의 10% (원 단위 내림)
    static func threshold(dailyBudget: Int) -> Int {
        guard dailyBudget > 0 else { return 0 }
        return dailyBudget * thresholdRate / 100
    }

    /// 하루 상환액과 예상 소요 일수.
    /// - perDay: 기본 일일 예산 × ratePercent% (원 단위 내림)
    /// - days: 남은 부채를 다 갚는 데 걸리는 일수 (올림). 마지막 날은 남은 금액만 갚으므로 perDay보다 적을 수 있다.
    /// - perDay가 0이면 계획을 세울 수 없으므로 days도 0을 반환한다.
    static func calculate(debt: Int, dailyBudget: Int, ratePercent: Int) -> (perDay: Int, days: Int) {
        guard debt > 0, dailyBudget > 0, ratePercent > 0 else { return (0, 0) }
        let perDay = dailyBudget * ratePercent / 100
        guard perDay > 0 else { return (0, 0) }
        let days = (debt + perDay - 1) / perDay   // 올림
        return (perDay, days)
    }

    /// DSR 규제 상한(40%) 이상이라 경고가 필요한 비율인지
    static func isAggressive(ratePercent: Int) -> Bool {
        ratePercent >= aggressiveRate
    }

    // MARK: - 상환 속도 점검

    /// 상환 중 실제로 쓸 수 있는 하루 금액 (기본 예산 − 하루 상환액)
    static func spendableWhileRepaying(dailyBudget: Int, ratePercent: Int) -> Int {
        guard dailyBudget > 0, ratePercent > 0 else { return max(0, dailyBudget) }
        return max(0, dailyBudget - dailyBudget * ratePercent / 100)
    }

    /// 최근 평균 소비가 상환 중 쓸 수 있는 금액을 넘으면 부채가 줄지 않는다.
    /// (넘긴 만큼이 다음 날 다시 부채로 합산되어 상환액과 상쇄되기 때문)
    static func isOffTrack(recentAverageSpending: Int, dailyBudget: Int, ratePercent: Int) -> Bool {
        guard dailyBudget > 0, recentAverageSpending > 0 else { return false }
        return recentAverageSpending > spendableWhileRepaying(dailyBudget: dailyBudget,
                                                              ratePercent: ratePercent)
    }

    /// 부채를 줄이려면 하루에 얼마를 더 줄여야 하는지 (0이면 이미 줄고 있음)
    static func dailyCutNeeded(recentAverageSpending: Int, dailyBudget: Int, ratePercent: Int) -> Int {
        let spendable = spendableWhileRepaying(dailyBudget: dailyBudget, ratePercent: ratePercent)
        return max(0, recentAverageSpending - spendable)
    }
}

// MARK: - 부채 모델

struct SpendingDebtModel: Identifiable, Equatable {
    var id: UUID
    /// 누적 발생 총액 (재초과 시 증가). 진행 게이지의 분모.
    var originalAmount: Int
    /// 남은 부채
    var remainingAmount: Int
    /// 상환 비율 (하루 예산 대비 %)
    var repayRatePercent: Int
    /// 계획 확정 여부. false면 상환이 시작되지 않는다.
    var isPlanned: Bool
    var startedAt: Date
    /// 완납일. nil이면 활성 부채.
    var completedAt: Date?
    /// 계획 설정을 "나중에"로 미룬 날. 그날은 팝업을 다시 띄우지 않는다.
    var deferredAt: Date?

    var isActive: Bool { completedAt == nil }

    /// 오늘 계획 설정 팝업을 띄워야 하는지 (미확정 + 오늘 미루지 않음)
    func needsPlanPrompt(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isActive, !isPlanned, remainingAmount > 0 else { return false }
        guard let deferredAt else { return true }
        return !calendar.isDate(deferredAt, inSameDayAs: date)
    }

    /// 지금까지 갚은 금액
    var repaidAmount: Int { max(0, originalAmount - remainingAmount) }

    /// 진행률 (0.0 ~ 1.0)
    var progress: Double {
        guard originalAmount > 0 else { return 0 }
        return min(1.0, Double(repaidAmount) / Double(originalAmount))
    }

    init(id: UUID = UUID(), originalAmount: Int, remainingAmount: Int,
         repayRatePercent: Int = DebtRepaymentPlan.defaultRate,
         isPlanned: Bool = false, startedAt: Date = Date(),
         completedAt: Date? = nil, deferredAt: Date? = nil) {
        self.id = id
        self.originalAmount = originalAmount
        self.remainingAmount = remainingAmount
        self.repayRatePercent = repayRatePercent
        self.isPlanned = isPlanned
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.deferredAt = deferredAt
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: SpendingDebt) {
        self.id = entity.id ?? UUID()
        self.originalAmount = Int(truncating: entity.originalAmount ?? 0)
        self.remainingAmount = Int(truncating: entity.remainingAmount ?? 0)
        self.repayRatePercent = Int(entity.repayRatePercent)
        self.isPlanned = entity.isPlanned
        self.startedAt = entity.startedAt ?? Date()
        self.completedAt = entity.completedAt
        self.deferredAt = entity.deferredAt
    }
}

// MARK: - 상환 원장 모델

struct DebtRepaymentEntryModel: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var amount: Int

    init(id: UUID = UUID(), date: Date, amount: Int) {
        self.id = id
        self.date = date
        self.amount = amount
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: DebtRepaymentEntry) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.amount = Int(truncating: entity.amount ?? 0)
    }
}
