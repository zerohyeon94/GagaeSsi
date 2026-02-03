//
//  SpendViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation
import RxSwift

final class SpendViewModel {
    // MARK: - Properties
    var model: SpendingRecordModel
    var spendingRecords: [SpendingRecordModel] = [] // 금일 지출 목록
    /// 실시간 유효성 체크용 임시 변수 (화면과 연결)
    var tempTitle: String = ""
    var tempAmount: Int = 0
    var tempDate: Date = Date()
    
    // MARK: - Computed
    var isValid: Bool {
        return tempTitle != "" && tempAmount > 0
    }
    
    // MARK: - Init
    init() {
        self.model = SpendingRecordModel(id: UUID(), title: "", amount: 0, date: Date())
    }
    
    // MARK: - Public Methods
    func fetchSpending(on date: Date) {
        spendingRecords = CoreDataManager.shared.fetchSpendingRecords(date: date)
    }
    
    func saveSpending(completion: @escaping (Bool) -> Void) {
        guard !model.title.isEmpty, model.amount > 0 else {
            completion(false)
            return
        }
        
        let success = CoreDataManager.shared.createSpendingRecord(model)
        guard success else {
            completion(false)
            return
        }

        fetchSpending(on: model.date)
        AppEventBus.shared.notifySpendingAdded()
        completion(true)
    }
}
