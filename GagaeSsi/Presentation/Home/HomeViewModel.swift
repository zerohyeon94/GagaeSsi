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
                self?.recalculateTodayBudget()
            })
            .disposed(by: disposeBag)
        
        AppEventBus.shared.fixedExpenseChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.recalculateTodayBudget()
            })
            .disposed(by: disposeBag)
    }
    
    func recalculateTodayBudget() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let config = CoreDataManager.shared.fetchBudgetConfig() else {
            DebugLogger.print("❌ BudgetConfig 없음 → Budget 설정 필요")
            return
        }
        let baseAmount = DailyBudgetCalculator.calculate(from: config, for: today)

        if var model = CoreDataManager.shared.fetchOrCreateTodayDailyBudget() {
            // 기존 carryOverSources, spendingRecords 유지
            let updatedModel = DailyBudgetModel(
                availableAmount: baseAmount,
                date: model.date,
                carryOverSources: model.carryOverSources,
                spendingRecords: model.spendingRecords
            )
            let success = CoreDataManager.shared.updateDailyBudget(updatedModel)
            if success {
                applyDailyBudgetModel(updatedModel)
            } else {
                DebugLogger.print("❌ DailyBudget 업데이트 실패")
            }
        }
    }
    
    func fetchTodayBudget() {
        if let model = CoreDataManager.shared.fetchOrCreateTodayDailyBudget() {
            applyDailyBudgetModel(model)
        }
    }

    private func applyDailyBudgetModel(_ model: DailyBudgetModel) {
        let base = model.availableAmount
        let spent = model.spendingRecords.map { $0.amount }.reduce(0, +)
        let carry = model.carryOverSources.map { $0.amount }.reduce(0, +)
        let total = model.todayAvailable

        baseBudget.accept(base)
        carryOverAmount.accept(carry)
        spentAmount.accept(spent)
        todayAvailableAmount.accept(total)
    }
}
