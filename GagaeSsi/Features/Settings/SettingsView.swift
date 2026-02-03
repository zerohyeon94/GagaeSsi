//
//  SettingsView.swift
//  GagaeSsi
//
//  설정 화면 (SettingsViewController 대체)
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @Environment(AppState.self) private var appState
    @State private var showResetAlert = false
    
    // MARK: - Body
    var body: some View {
        List {
            ForEach(SettingSection.allCases) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.items) { item in
                        settingRow(for: item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("설정")
        .alert("데이터 초기화", isPresented: $showResetAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                // 데이터 초기화
                CoreDataManager.shared.resetAllData()
                // Setup 화면으로 전환
                appState.resetSetup()
            }
        } message: {
            Text("모든 데이터가 삭제되고 초기 설정 화면으로 이동합니다.\n계속하시겠습니까?")
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private func settingRow(for item: SettingItem) -> some View {
        switch item.action {
        case .editBudget:
            NavigationLink {
                EditBudgetView()
            } label: {
                Text(item.title)
            }
            
        case .manageFixedExpenses:
            NavigationLink {
                FixedExpenseListView()
            } label: {
                Text(item.title)
            }
            
        case .resetData:
            Button {
                showResetAlert = true
            } label: {
                Text(item.title)
                    .foregroundStyle(.red)
            }
            
        case .backupData:
            Button {
                // TODO: 백업 기능 구현
                DebugLogger.log("📦 데이터 백업")
            } label: {
                Text(item.title)
            }
            
        case .sendFeedback:
            Button {
                // TODO: 피드백 기능 구현
                DebugLogger.log("📧 피드백 전송")
            } label: {
                Text(item.title)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
    }
}
