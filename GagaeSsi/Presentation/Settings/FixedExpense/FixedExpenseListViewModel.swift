//
//  FixedExpenseListViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/31/25.
//

import Foundation
import RxSwift
import RxRelay

final class FixedExpenseListViewModel {
    // MARK: - Output State
    var fixedCosts = BehaviorRelay<[FixedCostModel]>(value: [])
    
    // MARK: - Private
    private let disposeBag = DisposeBag()
    
    // MARK: - Init/Bind
    func bind() {
        AppEventBus.shared.fixedExpenseChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.fetchFixedCosts()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Public Methods
    func fetchFixedCosts() {
        let fixedCostList = CoreDataManager.shared.fetchFixedCosts()
        fixedCosts.accept(fixedCostList)
    }
    
    func fetchFixedCostEntity(id: UUID) -> FixedCost? {
        return CoreDataManager.shared.fetchFixedCostEntity(id: id)
    }

    func deleteFixedCost(at index: Int) {
        var current = fixedCosts.value
        let fixedCost = current[index]
        
        CoreDataManager.shared.deleteFixedCost(id: fixedCost.id)
        
        current.remove(at: index)
        fixedCosts.accept(current)
    }
}
