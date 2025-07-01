//
//  FixedExpenseEditViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/1/25.
//

import Foundation

final class FixedExpenseEditViewModel {
    // MARK: - Properties
    var fixedCost: FixedCostModel
    let isNew: Bool // init 시점에서 신규 or 수정 구분하는 Flag사용
    /// 실시간 유효성 체크용 임시 변수 (화면과 연결)
    var tempTitle: String = ""
    var tempAmount: Int = 0
    var tempDate: Date = Date()
    var onSave: ((FixedCostModel, FixedCost?) -> Void)? // 객체 함께 전달
    // MARK: - Computed
    var isValid: Bool {
        return tempTitle != "" && tempAmount > 0
    }
    
    // MARK: - Init
    init(fixedCost: FixedCostModel? = nil) {
        if let fixedCost = fixedCost {
            self.fixedCost = fixedCost
            self.isNew = false
        } else {
            // 신규 생성 시: id를 새로 부여하고, 값은 비워둠
            self.fixedCost = FixedCostModel(id: UUID(), title: "", amount: 0)
            self.isNew = true
        }
        self.tempTitle = self.fixedCost.title
        self.tempAmount = self.fixedCost.amount
    }
    
    // MARK: - Public Methods
    func saveFixedExpense() {
        let success: Bool

        if isNew {
            success = CoreDataManager.shared.createFixedCost(fixedCost)
        } else {
            success = CoreDataManager.shared.updateFixedCost(fixedCost)
        }

        if success {
            print("create or update success")
            AppEventBus.shared.fixedExpenseChanged.onNext(())
        } else {
            // 실패 시 에러 안내(알럿 등) 처리 가능
        }
    }
}
