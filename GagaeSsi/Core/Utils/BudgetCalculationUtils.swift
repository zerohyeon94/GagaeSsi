//
//  BudgetCalculationUtils.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/19/25.
//

import Foundation

struct DailyBudgetCalculator {
    static func calculate(from config: BudgetConfigModel, for date: Date) -> Int {
        let fixedTotal = config.fixedCosts.map { $0.amount }.reduce(0, +)
        let usableSalary = config.salary - fixedTotal

        let periodStart = calculatePayPeriodStart(payday: config.payday, today: date)
        let periodEnd = Calendar.current.date(byAdding: .month, value: 1, to: periodStart)!
        let totalDays = Calendar.current.dateComponents([.day], from: periodStart, to: periodEnd).day!

        return usableSalary / totalDays
    }

    static func calculatePayPeriodStart(payday: Int, today: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let year = components.year, let month = components.month else { return today }

        let paydayThisMonth = calendar.date(from: DateComponents(year: year, month: month, day: payday))!
        return today >= paydayThisMonth ? paydayThisMonth : calendar.date(byAdding: .month, value: -1, to: paydayThisMonth)!
    }
}


func calculateDailyBudget(from config: BudgetConfigModel, for date: Date) -> Int {
    let fixedTotal = config.fixedCosts.map { $0.amount }.reduce(0, +)
    let usableSalary = config.salary - fixedTotal

    let periodStart = calculateCurrentPayPeriodStart(payday: config.payday, today: date)
    let periodEnd = Calendar.current.date(byAdding: .month, value: 1, to: periodStart)!
    let totalDays = Calendar.current.dateComponents([.day], from: periodStart, to: periodEnd).day!

    DebugLogger.print("usableSalary: \(usableSalary)")
    DebugLogger.printDate("periodStart: ", periodStart)
    DebugLogger.printDate("periodEnd: ", periodEnd)

    return usableSalary / totalDays
}

func calculateCurrentPayPeriodStart(payday: Int, today: Date) -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: today)
    guard let year = components.year, let month = components.month else { return today }

    let paydayThisMonth = calendar.date(from: DateComponents(year: year, month: month, day: payday))!
    return today >= paydayThisMonth ? paydayThisMonth : calendar.date(byAdding: .month, value: -1, to: paydayThisMonth)!
//        if today >= paydayThisMonth {
//            // 오늘이 이번 달 급여일 이후라면 → 이번 달 급여 시작
//            return paydayThisMonth
//        } else {
//            // 오늘이 이번 달 급여일 이전이라면 → 지난 달 급여 시작
//            let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: paydayThisMonth)!
//            return previousMonthDate
//        }
}
