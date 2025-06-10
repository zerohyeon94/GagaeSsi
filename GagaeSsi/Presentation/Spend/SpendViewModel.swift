//
//  SpendViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation
import RxSwift

final class SpendViewModel {
    var currentInput = SpendingInputModel() // 입력 중인 지출 모델
    var spendingRecords: [SpendingRecord] = [] // 금일 지출 목록
    
    func fetchSpending(on date: Date) {
        spendingRecords = CoreDataManager.shared.fetchSpending(on: date)
    }
    
    func saveSpending(completion: (() -> Void)? = nil) {
        guard !currentInput.title.isEmpty, currentInput.amount > 0 else { return }
        
        CoreDataManager.shared.saveSpending(
            title: currentInput.title,
            amount: currentInput.amount,
            date: currentInput.date
        )
        
        fetchSpending(on: currentInput.date)
        AppEventBus.shared.spendingAdded.onNext(())
        completion?()
    }
    
    // 실시간 유효성 체크용 임시 변수 (화면과 연결)
    var tempTitle: String = ""
    var tempAmount: Int = 0
    var tempDate: Date = Date()

    var isValid: Bool {
        return tempTitle != "" && tempAmount > 0
    }
}
