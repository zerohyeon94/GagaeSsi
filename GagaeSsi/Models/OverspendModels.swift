//
//  OverspendModels.swift
//  GagaeSsi
//
//  "언제 초과했는지"를 일자별 예산 기록에서 역산한다.
//
//  부채(SpendingDebt)에는 누적 금액과 최초 발생일만 있고 날짜별 내역이 없다.
//  대신 일자별 DailyBudget이 보존되므로 그날의 과소비를 역산할 수 있다.
//
//  **과거 적자를 떠안고 있는 것과 그날 과소비한 것은 다르다.**
//  잔액(todayAvailable)이 음수인 날을 초과일로 잡으면, 한 번 적자에 빠진 뒤로는
//  6,200원만 쓴 날도 "258,036원 초과"가 되어 모든 날이 초과일로 표시된다.
//  그래서 **음수 이월은 그날의 잘못으로 치지 않는다.**
//
//  별도 원장을 두지 않은 이유: 원장은 앞으로 생기는 초과만 담을 수 있어
//  이미 쌓여 있는 부채의 출처를 보여주지 못한다.
//

import Foundation

/// 하루 배정액보다 많이 쓴 날
struct OverspendDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    /// 그날 초과한 금액 (양수)
    let overspentAmount: Int
    /// 그날 기본 일일 예산
    let baseBudget: Int
    /// 아껴서 넘어온 이월 (음수 이월은 제외)
    let savedCarryOver: Int
    /// 그날 발생한 크레딧·차감 (이월금 인출·환급 +, 초과분 상환 −)
    let sameDayAdjustment: Int
    /// 그날 소비 합계
    let spent: Int
    /// 그날 위시리스트 저금액
    let wishSaving: Int

    /// 그날 실제로 쓸 수 있었던 금액
    var availableThatDay: Int { baseBudget + savedCarryOver + sameDayAdjustment }
    /// 그날 빠져나간 금액 (소비 + 위시 저금)
    var outgoing: Int { spent + wishSaving }
}

enum OverspendAnalyzer {
    /// 하루치 판정 결과
    struct DayEvaluation {
        /// 그날 쓸 수 있었던 금액 (음수 이월은 제외 — 과거 적자는 그날의 잘못이 아니다)
        let allowance: Int
        /// 그날 빠져나간 금액 (소비 + 위시 저금)
        let outgoing: Int
        /// 초과액 (0이면 초과 아님)
        var overspent: Int { max(0, outgoing - allowance) }
        /// 배정액 대비 사용률 (배정액이 0 이하면 nil)
        var usageRatio: Double? {
            guard allowance > 0 else { return nil }
            return Double(outgoing) / Double(allowance)
        }
    }

    /// 하루의 배정액·지출을 계산한다. 초과 판정·캘린더 상태 색이 모두 이 값을 쓴다.
    static func evaluate(_ budget: DailyBudgetModel,
                         calendar: Calendar = .current) -> DayEvaluation {
        let day = calendar.startOfDay(for: budget.date)

        var savedCarryOver = 0      // 전날에서 넘어온 이월
        var sameDayAdjustment = 0   // 그날 발생한 크레딧·차감
        for source in budget.carryOverSources {
            if calendar.startOfDay(for: source.date) < day {
                savedCarryOver += source.amount
            } else {
                sameDayAdjustment += source.amount
            }
        }

        // 음수 이월(과거 적자)은 그날 과소비의 근거가 될 수 없다.
        // 포함하면 적자에 빠진 뒤 모든 날이 초과일로 표시된다.
        let allowance = budget.availableAmount + max(0, savedCarryOver) + sameDayAdjustment
        let outgoing = budget.spendingRecords.map(\.amount).reduce(0, +) + budget.wishSavingAmount
        return DayEvaluation(allowance: allowance, outgoing: outgoing)
    }

    /// 초과한 날을 최신순으로 뽑는다.
    /// - Parameter minimumAmount: 이 금액 미만의 초과는 무시한다 (1원 단위 잔돈 노이즈 제거)
    static func overspendDays(from budgets: [DailyBudgetModel],
                              minimumAmount: Int = 1,
                              calendar: Calendar = .current) -> [OverspendDay] {
        budgets
            .compactMap { budget -> OverspendDay? in
                let day = calendar.startOfDay(for: budget.date)
                let evaluation = evaluate(budget, calendar: calendar)
                guard evaluation.overspent >= minimumAmount else { return nil }

                var savedCarryOver = 0
                var sameDayAdjustment = 0
                for source in budget.carryOverSources {
                    if calendar.startOfDay(for: source.date) < day {
                        savedCarryOver += source.amount
                    } else {
                        sameDayAdjustment += source.amount
                    }
                }

                return OverspendDay(
                    date: budget.date,
                    overspentAmount: evaluation.overspent,
                    baseBudget: budget.availableAmount,
                    savedCarryOver: max(0, savedCarryOver),
                    sameDayAdjustment: sameDayAdjustment,
                    spent: budget.spendingRecords.map(\.amount).reduce(0, +),
                    wishSaving: budget.wishSavingAmount
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// 초과액 합계
    static func total(of days: [OverspendDay]) -> Int {
        days.reduce(0) { $0 + $1.overspentAmount }
    }

    /// 가장 크게 초과한 날 (반성 우선순위)
    static func worst(of days: [OverspendDay]) -> OverspendDay? {
        days.max { $0.overspentAmount < $1.overspentAmount }
    }
}
