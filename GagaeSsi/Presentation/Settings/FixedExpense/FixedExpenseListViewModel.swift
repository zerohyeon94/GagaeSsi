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
    var fixedCosts = BehaviorRelay<[FixedCostModel]>(value: [])
    
    private let disposeBag = DisposeBag()
    
    func bind() {
        AppEventBus.shared.fixedExpenseChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.fetchFixedCosts()
            })
            .disposed(by: disposeBag)
    }

    func fetchFixedCosts() {
        let fixedCostList = CoreDataManager.shared.fetchFixedCosts()
        fixedCosts.accept(fixedCostList)
    }

    func deleteItem(at index: Int) {
        var current = fixedCosts.value
        let item = current[index]
        
        CoreDataManager.shared.deleteFixedCost(named: item.title)
        
        current.remove(at: index)
        fixedCosts.accept(current)
    }
}
