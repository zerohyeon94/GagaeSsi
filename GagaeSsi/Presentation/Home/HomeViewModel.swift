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
                self?.fetchTodayBudget()
            })
            .disposed(by: disposeBag)
        
        AppEventBus.shared.fixedExpenseChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.fetchTodayBudget()
            })
            .disposed(by: disposeBag)
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
        let spent = model.spendingRecords.map { $0.amount }.reduce(0, +)
        let carry = model.carryOverSources.map { $0.amount }.reduce(0, +)
        let total = model.todayAvailable

        baseBudget.accept(base)
        carryOverAmount.accept(carry)
        spentAmount.accept(spent)
        todayAvailableAmount.accept(total)
    }
}
