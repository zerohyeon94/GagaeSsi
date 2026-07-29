//
//  InstallmentModel.swift
//  GagaeSsi
//
//  할부 — 총액을 개월수로 나눠 매월 예산에서 미리 차감
//

import Foundation

struct InstallmentModel: Identifiable, Equatable {
    var id: UUID
    var title: String
    var totalAmount: Int
    var months: Int
    var startYear: Int
    var startMonth: Int
    var createdAt: Date

    // MARK: - 계산
    /// 월 납입액 (정수 나눗셈). 이자는 총액에 포함된 것으로 간주.
    var monthlyAmount: Int { months > 0 ? totalAmount / months : 0 }

    /// 시작월로부터 경과 개월 (음수면 시작 전)
    func monthsSinceStart(for date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month], from: date)
        return ((c.year ?? 0) - startYear) * 12 + ((c.month ?? 0) - startMonth)
    }

    /// 해당 월에 납입이 진행 중인지 (0 ≤ 경과 < 개월수)
    func isActive(for date: Date, calendar: Calendar = .current) -> Bool {
        let m = monthsSinceStart(for: date, calendar: calendar)
        return m >= 0 && m < months
    }

    /// 이번 달 포함 남은 회차. 시작 전 → 전체, 완료 → 0.
    func remainingMonths(for date: Date, calendar: Calendar = .current) -> Int {
        let m = monthsSinceStart(for: date, calendar: calendar)
        if m < 0 { return months }
        if m >= months { return 0 }
        return months - m
    }

    /// 완료 여부 (개월수 경과)
    func isCompleted(for date: Date, calendar: Calendar = .current) -> Bool {
        monthsSinceStart(for: date, calendar: calendar) >= months
    }

    // MARK: - Init
    init(id: UUID = UUID(), title: String, totalAmount: Int, months: Int,
         startYear: Int, startMonth: Int, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.totalAmount = totalAmount
        self.months = months
        self.startYear = startYear
        self.startMonth = startMonth
        self.createdAt = createdAt
    }

    init(entity: Installment) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.totalAmount = Int(truncating: entity.totalAmount ?? 0)
        self.months = Int(entity.months)
        self.startYear = Int(entity.startYear)
        self.startMonth = Int(entity.startMonth)
        self.createdAt = entity.createdAt ?? Date()
    }

    // MARK: - 집계 (순수)
    /// 해당 월에 활성인 할부들의 월 납입액 합
    static func activeMonthlyTotal(_ items: [InstallmentModel], for date: Date, calendar: Calendar = .current) -> Int {
        items.filter { $0.isActive(for: date, calendar: calendar) }
            .reduce(0) { $0 + $1.monthlyAmount }
    }
}
