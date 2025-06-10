//
//  AppEventBus.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/9/25.
//

import RxSwift

final class AppEventBus {
    static let shared = AppEventBus()
    private init() {}

    // MARK: - 소비 기록
    let spendingAdded = PublishSubject<Void>()
    
    // MARK: - 월급
    let budgetChanged = PublishSubject<Void>()
    
    // MARK: - 고정비 목록
    let fixedExpenseChanged = PublishSubject<Void>()
}
