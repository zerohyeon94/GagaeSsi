//
//  MainTabBarController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import UIKit
import SwiftUI

final class MainTabBarController: UITabBarController {
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }

    // MARK: - UI Setup
    private func setupTabs() {
        let homeVM = HomeViewModel()
        let homeVC = HomeViewController(viewModel: homeVM)
        homeVC.tabBarItem = UITabBarItem(title: "홈", image: UIImage(systemName: "house"), tag: 0)

        let spendVM = SpendViewModel()
        let spendVC = SpendViewController(viewModel: spendVM)
        spendVC.tabBarItem = UITabBarItem(title: "소비", image: UIImage(systemName: "creditcard"), tag: 1)

        let statsVC = StatsViewController()
        statsVC.tabBarItem = UITabBarItem(title: "통계", image: UIImage(systemName: "chart.bar"), tag: 2)

        let settingVM = setSettingViewModel()
        let settingsVC = SettingsViewController(viewModel: settingVM)
        settingsVC.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape"), tag: 3)

        let homeNav = UINavigationController(rootViewController: homeVC)
        let spendNav = UINavigationController(rootViewController: spendVC)
        let statsNav = UINavigationController(rootViewController: statsVC)
        let settingsNav = UINavigationController(rootViewController: settingsVC)

        viewControllers = [homeNav, spendNav, statsNav, settingsNav]
    }
    
    // MARK: - Private Methods
    private func setSettingViewModel() -> SettingsViewModel {
        let settingVM = SettingsViewModel { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .editBudget:
                print("➡️ 월급 수정 화면으로 이동")
                let editView = EditBudgetView()
                let hostingVC = UIHostingController(rootView: editView)
                hostingVC.title = "월급 수정 설정"
                
                if let nav = self.selectedViewController as? UINavigationController {
                    nav.pushViewController(hostingVC, animated: true)
                }
            case .manageFixedExpenses:
                print("➡️ 고정비 관리 화면으로 이동")
                let fixedListView = FixedExpenseListView()
                let hostingVC = UIHostingController(rootView: fixedListView)
                hostingVC.title = "고정비 관리"
                
                if let nav = self.selectedViewController as? UINavigationController {
                    nav.pushViewController(hostingVC, animated: true)
                }
            case .resetData:
                print("🗑 데이터 초기화")
            case .backupData:
                print("📦 데이터 백업")
            case .sendFeedback:
                print("📧 피드백 전송")
            }
        }
        
        return settingVM
    }
}
