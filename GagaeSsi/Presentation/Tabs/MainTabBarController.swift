//
//  MainTabBarController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }

    private func setupTabs() {
        let homeVC = HomeViewController()
        homeVC.tabBarItem = UITabBarItem(title: "홈", image: UIImage(systemName: "house"), tag: 0)

        let spendVC = SpendViewController()
        spendVC.tabBarItem = UITabBarItem(title: "소비", image: UIImage(systemName: "creditcard"), tag: 1)

        let statsVC = StatsViewController()
        statsVC.tabBarItem = UITabBarItem(title: "통계", image: UIImage(systemName: "chart.bar"), tag: 2)

        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape"), tag: 3)

        let homeNav = UINavigationController(rootViewController: homeVC)
        let spendNav = UINavigationController(rootViewController: spendVC)
        let statsNav = UINavigationController(rootViewController: statsVC)
        let settingsNav = UINavigationController(rootViewController: settingsVC)

        viewControllers = [homeNav, spendNav, statsNav, settingsNav]
    }
}
