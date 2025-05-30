//
//  SettingsModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/30/25.
//

import Foundation

enum SettingSection: Int, CaseIterable {
    case budget
    case fixedExpense
    case data
    case appInfo

    var title: String {
        switch self {
        case .budget: return "예산 설정"
        case .fixedExpense: return "고정비 관리"
        case .data: return "데이터 관리"
        case .appInfo: return "앱 정보"
        }
    }
}

struct SettingItem {
    let title: String
    let action: () -> Void
}

