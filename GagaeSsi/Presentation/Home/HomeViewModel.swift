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
    
    func fetchTodayBudget() {
        let today = Calendar.current.startOfDay(for: Date())

        // 1. 오늘 데이터 조회
        if let model = CoreDataManager.shared.fetchDailyBudgetModel(date: today) {
            applyDailyBudgetModel(model)
        } else {
            // 2. BudgetConfig 가져오기
            guard let config = CoreDataManager.shared.fetchBudgetConfig() else {
                DebugLogger.print("❌ BudgetConfig 없음 → Budget 설정 필요")
                return
            }

            // 3. 계산
            let baseAmount = DailyBudgetCalculator.calculate(from: config, for: today)

            // 4. 모델 생성
            let newModel = DailyBudgetModel(
                availableAmount: baseAmount,
                date: today,
                spendAmount: 0,
                carryOverSources: [],
                spendingRecords: []
            )

            // 5. CoreData에 저장
            let success = CoreDataManager.shared.createDailyBudget(newModel)
            if success {
                applyDailyBudgetModel(newModel)
            } else {
                DebugLogger.print("❌ DailyBudget 생성 실패")
            }
        }
    }

    private func applyDailyBudgetModel(_ model: DailyBudgetModel) {
        let base = model.availableAmount
        let spent = model.spendAmount
        let carry = model.carryOverSources.map { $0.amount }.reduce(0, +)
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
