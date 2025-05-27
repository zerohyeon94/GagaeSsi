//
//  SpendViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation

final class SpendViewModel {

    // 입력 중인 지출 모델
       var currentInput = SpendingInputModel()
       var spendingRecords: [SpendingRecord] = []

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
           completion?()
       }
}
