//
//  AppEventBus.swift
//  GagaeSsi
//
//  앱 전역 이벤트 관리 (RxSwift → @Observable)
//

import SwiftUI
import Observation

/// 앱 전역에서 사용하는 이벤트 버스
/// RxSwift의 PublishSubject를 @Observable로 대체
@Observable
final class AppEventBus {
    // MARK: - Event Triggers
    /// 소비 기록이 추가되었을 때 트리거
    var spendingAddedTrigger: UUID = UUID()
    
    /// 예산 설정이 변경되었을 때 트리거
    var budgetChangedTrigger: UUID = UUID()
    
    /// 고정비가 변경되었을 때 트리거
    var fixedExpenseChangedTrigger: UUID = UUID()
    
    // MARK: - Event Methods
    func notifySpendingAdded() {
        spendingAddedTrigger = UUID()
    }
    
    func notifyBudgetChanged() {
        budgetChangedTrigger = UUID()
    }
    
    func notifyFixedExpenseChanged() {
        fixedExpenseChangedTrigger = UUID()
    }
}
