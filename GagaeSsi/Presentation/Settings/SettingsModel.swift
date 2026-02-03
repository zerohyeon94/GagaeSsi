//
//  SettingsModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/30/25.
//

import Foundation

enum SettingSection: Int, CaseIterable, Identifiable {
    case budget
    case fixedExpense
    case data
    case appInfo

    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .budget: return "예산 설정"
        case .fixedExpense: return "고정비 관리"
        case .data: return "데이터 관리"
        case .appInfo: return "앱 정보"
        }
    }
    
    var items: [SettingItem] {
        switch self {
        case .budget:
            return [SettingItem(title: "월급 및 급여일 수정", action: .editBudget)]
        case .fixedExpense:
            return [SettingItem(title: "고정비 관리", action: .manageFixedExpenses)]
        case .data:
            return [
                SettingItem(title: "데이터 초기화", action: .resetData),
                SettingItem(title: "데이터 백업", action: .backupData)
            ]
        case .appInfo:
            return [SettingItem(title: "피드백 보내기", action: .sendFeedback)]
        }
    }
}

// MARK: - 설정 항목
struct SettingItem: Identifiable {
    let id = UUID()
    let title: String
    let action: SettingsAction
}

// MARK: - 설정 액션
enum SettingsAction: String {
    case editBudget = "EditBudget"
    case manageFixedExpenses = "ManageFixedExpenses"
    case resetData = "ResetData"
    case backupData = "BackupData"
    case sendFeedback = "SendFeedback"
}
