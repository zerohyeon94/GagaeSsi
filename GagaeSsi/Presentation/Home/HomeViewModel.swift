//
//  HomeViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation
import RxSwift
import RxRelay

final class HomeViewModel {
    var todayAvailableAmount = BehaviorRelay<Int>(value: 0)
    let baseBudget = BehaviorRelay<Int>(value: 0)
    let carryOverAmount = BehaviorRelay<Int>(value: 0)
    let spentAmount = BehaviorRelay<Int>(value: 0)
    
    private let disposeBag = DisposeBag()
    
    func bind() {
        AppEventBus.shared.spendingAdded
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.fetchTodayBudget()
            })
            .disposed(by: disposeBag)
        
        AppEventBus.shared.budgetChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.updateTodayBudget()
                self?.fetchTodayBudget()
            })
            .disposed(by: disposeBag)
        
        AppEventBus.shared.fixedExpenseChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.updateTodayBudget()
                self?.fetchTodayBudget()
            })
            .disposed(by: disposeBag)
    }
    
    func fetchTodayBudget() {
        let dailyBudget = CoreDataManager.shared.ensureTodayDailyBudgetExists()
        
        let base = dailyBudget.availableAmount?.intValue ?? 0
        let spent = dailyBudget.spentAmount?.intValue ?? 0
        let carry = dailyBudget.carryOverSources?
            .compactMap { ($0 as? CarryOverSource)?.amount?.intValue }
            .reduce(0, +) ?? 0
        let total = base + carry - spent
        
        baseBudget.accept(base)
        carryOverAmount.accept(carry)
        spentAmount.accept(spent)
        
        todayAvailableAmount.accept(total)
        
        print("오늘 Budget")
        print("base : \(base)")
        print("spent : \(spent)")
        print("carry : \(carry)")
        print("total : \(total)")
    }
    
    func updateTodayBudget() {
        CoreDataManager.shared.updateTodayBudget()
    }
}
