//
//  FixedExpenseEditViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/1/25.
//

import Foundation

final class FixedExpenseEditViewModel {
    var fixedCost: FixedCostModel
    
    var originalObject: FixedCost?  // CoreData 객체를 참조

    var onSave: ((FixedCostModel, FixedCost?) -> Void)? // 객체 함께 전달

    init(title: String = "", amount: Int = 0, object: FixedCost? = nil) {
        self.fixedCost = FixedCostModel(title: title, amount: amount)
        self.originalObject = object
        
        self.tempTitle = title
        self.tempAmount = amount
    }
    
    func saveFixedExpense() {
        if let existing = originalObject {
            CoreDataManager.shared.updateFixedCost(fixedCost, target: existing)
        } else {
            CoreDataManager.shared.insertFixedCost(fixedCost)
        }
        
        AppEventBus.shared.fixedExpenseChanged.onNext(())
    }
    
    // 실시간 유효성 체크용 임시 변수 (화면과 연결)
    var tempTitle: String = ""
    var tempAmount: Int = 0
    var tempDate: Date = Date()

    var isValid: Bool {
        return tempTitle != "" && tempAmount > 0
    }
}
