//
//  OverspendModels.swift
//  GagaeSsi
//
//  "언제 초과했는지"를 일자별 예산 기록에서 역산한다.
//
//  부채(SpendingDebt)에는 누적 금액과 최초 발생일만 있고 날짜별 내역이 없다.
//  대신 일자별 DailyBudget이 그대로 보존되므로, 잔액이 음수였던 날을 찾으면
//  그날 얼마나 초과했는지 알 수 있다. 이 값(todayAvailable)은 부채 엔진이
//  초과분을 계산할 때 쓰는 바로 그 값이라 부채 금액과 정확히 맞아떨어진다.
//
//  별도 원장을 두지 않은 이유: 원장은 앞으로 생기는 초과만 담을 수 있어
//  이미 쌓여 있는 부채의 출처를 보여주지 못한다.
//

import Foundation

/// 하루 예산을 넘긴 날
struct OverspendDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    /// 그날 초과한 금액 (양수)
    let overspentAmount: Int
    /// 그날 기본 일일 예산
    let baseBudget: Int
    /// 그날 이월 금액 합계 (음수 이월·상환·인출 포함)
    let carryOver: Int
    /// 그날 소비 합계
    let spent: Int
    /// 그날 위시리스트 저금액
    let wishSaving: Int

    /// 그날 실제로 쓸 수 있었던 금액
    var availableThatDay: Int { baseBudget + carryOver }
}

enum OverspendAnalyzer {
    /// 초과한 날을 최신순으로 뽑는다.
    /// - Parameter minimumAmount: 이 금액 미만의 초과는 무시한다 (1원 단위 잔돈 노이즈 제거)
    static func overspendDays(from budgets: [DailyBudgetModel],
                              minimumAmount: Int = 1) -> [OverspendDay] {
        budgets
            .compactMap { budget -> OverspendDay? in
                let balance = budget.todayAvailable
                guard balance < 0, -balance >= minimumAmount else { return nil }
                return OverspendDay(
                    date: budget.date,
                    overspentAmount: -balance,
                    baseBudget: budget.availableAmount,
                    carryOver: budget.carryOverSources.map(\.amount).reduce(0, +),
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
