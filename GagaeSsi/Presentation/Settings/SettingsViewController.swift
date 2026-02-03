//
//  SettingsViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import UIKit
import SwiftUI

final class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // SwiftUI로 교체
        let settingsView = SettingsView()
        embedSwiftUIView(
            NavigationStack { settingsView }  // NavigationStack 포함
        )
    }
}
