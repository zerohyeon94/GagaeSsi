//
//  BudgetCalculationUtils.swift
//  GagaeSsi
//
//  예산 계산 유틸리티
//

import Foundation

struct DailyBudgetCalculator {
    /// 일일 예산 계산
    static func calculate(from config: BudgetConfigModel, for date: Date) -> Int {
        let fixedTotal = config.fixedCosts.map { $0.amount }.reduce(0, +)
        let usableSalary = config.salary - fixedTotal

        let periodStart = calculatePayPeriodStart(payday: config.payday, today: date)
        let periodEnd = Calendar.current.date(byAdding: .month, value: 1, to: periodStart)!
        let totalDays = Calendar.current.dateComponents([.day], from: periodStart, to: periodEnd).day!

        return usableSalary / totalDays
    }

    /// 급여 기간 시작일 계산
    static func calculatePayPeriodStart(payday: Int, today: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let year = components.year, let month = components.month else { return today }

        let paydayThisMonth = calendar.date(from: DateComponents(year: year, month: month, day: payday))!
        return today >= paydayThisMonth ? paydayThisMonth : calendar.date(byAdding: .month, value: -1, to: paydayThisMonth)!
    }
    
    /// 급여 기간 종료일까지 남은 일수
    static func daysUntilNextPayday(payday: Int, from date: Date = Date()) -> Int {
        let periodStart = calculatePayPeriodStart(payday: payday, today: date)
        let periodEnd = Calendar.current.date(byAdding: .month, value: 1, to: periodStart)!
        return Calendar.current.dateComponents([.day], from: date, to: periodEnd).day ?? 0
    }
}
