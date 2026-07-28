//
//  GagaeSsiApp.swift
//  GagaeSsi
//
//  SwiftUI App Entry Point
//  - BudgetConfig가 없으면 → Setup 화면
//  - BudgetConfig가 있으면 → 메인 탭 화면
//

import SwiftUI

@main
struct GagaeSsiApp: App {
    // MARK: - Properties
    @State private var eventBus = AppEventBus()
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(eventBus)
                .environment(appState)
        }
    }
}

// MARK: - App State
/// 앱 전체 상태 관리
@Observable
final class AppState {
    var isSetupCompleted: Bool = false
    /// 메인 탭 선택 (0: 홈, 1: 기록, 2: 통계, 3: 설정)
    var selectedTab: Int = 0
    
    init() {
        checkSetupStatus()
    }
    
    func checkSetupStatus() {
        // BudgetConfig가 존재하면 설정 완료된 것
        isSetupCompleted = CoreDataManager.shared.fetchBudgetConfig() != nil
    }
    
    func completeSetup() {
        isSetupCompleted = true
    }
    
    func resetSetup() {
        isSetupCompleted = false
    }
}

// MARK: - Root View
/// 앱 상태에 따라 Setup 또는 Main 화면 표시
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.isSetupCompleted {
                // 설정 완료 → 메인 탭 화면
                ContentView()
            } else {
                // 설정 필요 → Setup 화면
                NavigationStack {
                    SetupSalaryView()
                }
            }
        }
        .task {
            // 앱 실행 시 변동 고정비 지출일 알림을 현재 상태로 재설정
            CoreDataManager.shared.refreshVariableCostReminders()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                CoreDataManager.shared.refreshVariableCostReminders()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isSetupCompleted)
        // 디자인 시스템이 라이트 테마 고정이므로 다크모드에서도 라이트로 렌더링
        // (다크모드에서 TextField 글자가 흰색이 되어 보이지 않는 문제 방지)
        .preferredColorScheme(.light)
    }
}

#Preview("Setup Needed") {
    RootView()
        .environment(AppEventBus())
        .environment(AppState())
}
