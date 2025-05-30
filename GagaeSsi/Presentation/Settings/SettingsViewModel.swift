//
//  SettingsViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/30/25.
//

import Foundation

final class SettingsViewModel {
    var settingSections: [[SettingItem]] = []

    init(onSelect: @escaping (String) -> Void) {
        settingSections = [
            [
                SettingItem(title: "월급 및 월급일 수정", action: { onSelect("EditBudget") })
            ],
            [
                SettingItem(title: "고정비 등록 및 수정", action: { onSelect("ManageFixedExpenses") })
            ],
            [
                SettingItem(title: "데이터 초기화", action: { onSelect("ResetData") }),
                SettingItem(title: "데이터 백업", action: { onSelect("BackupData") })
            ],
            [
                SettingItem(title: "앱 버전 1.0.0", action: {}),
                SettingItem(title: "개발자: Jo Yeong Hyeon", action: {}),
                SettingItem(title: "피드백 보내기", action: { onSelect("SendFeedback") })
            ]
        ]
    }
}
