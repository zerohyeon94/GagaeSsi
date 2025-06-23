//
//  FixedExpenseEditViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/1/25.
//

import Foundation

final class FixedExpenseEditViewModel {
    var fixedCost: FixedCostModel
    var onSave: ((FixedCostModel, FixedCost?) -> Void)? // 객체 함께 전달

    init(fixedCost: FixedCostModel? = nil) {
        if let fixedCost = fixedCost {
            self.fixedCost = fixedCost
        } else {
            // 신규 생성 시: id를 새로 부여하고, 값은 비워둠
            self.fixedCost = FixedCostModel(id: UUID(), title: "", amount: 0)
        }
        self.tempTitle = self.fixedCost.title
        self.tempAmount = self.fixedCost.amount
    }
    
    func saveFixedExpense() {
        let success: Bool

        if fixedCost.id == nil {
            // 새로 생성
            success = CoreDataManager.shared.createFixedCost(fixedCost)
        } else {
            // 기존 엔티티 수정
            success = CoreDataManager.shared.updateFixedCost(fixedCost)
        }

        if success {
            AppEventBus.shared.fixedExpenseChanged.onNext(())
        } else {
            // 실패 시 에러 안내(알럿 등) 처리 가능
        }
    }
    
    // 실시간 유효성 체크용 임시 변수 (화면과 연결)
    var tempTitle: String = ""
    var tempAmount: Int = 0
    var tempDate: Date = Date()

    var isValid: Bool {
        return tempTitle != "" && tempAmount > 0
    }
}
