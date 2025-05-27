//
//  HomeViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation

final class HomeViewModel {
    var todayAvailableAmount: Int = 0
    var carryOverAmount: Int = 0
    var spentAmount: Int = 0
    var baseBudget: Int = 0
    
    func fetchTodayBudget() {
        let dailyBudget = CoreDataManager.shared.ensureTodayDailyBudgetExists()
        
        baseBudget = dailyBudget.availableAmount?.intValue ?? 0
        spentAmount = dailyBudget.spentAmount?.intValue ?? 0
        
        carryOverAmount = dailyBudget.carryOverSources?
            .compactMap { ($0 as? CarryOverSource)?.amount?.intValue }
            .reduce(0, +) ?? 0
        
        todayAvailableAmount = baseBudget + carryOverAmount - spentAmount
    }
}
