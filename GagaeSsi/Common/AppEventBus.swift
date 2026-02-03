//
//  AppEventBus.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/9/25.
//

// TODO: RxSwift 의존성 제거 필요 (각 적용 후 최종적으로 제거)
import RxSwift
import Combine

final class AppEventBus {
    static let shared = AppEventBus()
    private init() {}

    // MARK: 기존 RxSwift (UIKit 화면용)
    let spendingAdded = PublishSubject<Void>() // 소비 기록
    let budgetChanged = PublishSubject<Void>() // 월급
    let fixedExpenseChanged = PublishSubject<Void>() // 고정비 목록
    
    // MARK: Combine (SwiftUI 화면용)
    let spendingAddedPublisher = PassthroughSubject<Void, Never>()
    let budgetChangedPublisher = PassthroughSubject<Void, Never>()
    let fixedExpenseChangedPublisher = PassthroughSubject<Void, Never>()
    
    // 통합 발행 메서드
    func notifySpendingAdded() {
        spendingAdded.onNext(())           // RxSwift
        spendingAddedPublisher.send(())    // Combine
    }
    
    func notifyBudgetChanged() {
        budgetChanged.onNext(())
        budgetChangedPublisher.send(())
    }
    
    func notifyFixedExpenseChanged() {
        fixedExpenseChanged.onNext(())
        fixedExpenseChangedPublisher.send(())
    }
}
