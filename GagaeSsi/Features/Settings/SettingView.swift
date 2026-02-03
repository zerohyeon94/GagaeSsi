//
//  SettingView.swift
//  GagaeSsi
//
//  Created by 조영현 on 2/3/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var showResetAlert = false
    
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
        .navigationTitle("설정")  // ← UINavigationController가 표시
        .alert("데이터 초기화", isPresented: $showResetAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                CoreDataManager.shared.resetAllData()
            }
        } message: {
            Text("모든 데이터가 삭제됩니다.")
        }
    }
    
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
            
        case .backupData, .sendFeedback:
            Text(item.title)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
