//
//  StatsViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import UIKit
import SwiftUI

final class StatsViewController: BaseViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupStatsView()
    }
    
    private func setupStatsView() {
//        // SwiftUI View를 UIKit에 임베드
//        let statsView = StatsView()
//        let hostingController = UIHostingController(rootView: statsView)
//        
//        // 자식 뷰컨트롤러로 추가
//        addChild(hostingController)
//        view.addSubview(hostingController.view)
//        
//        // Auto Layout 설정
//        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
//            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
//        ])
//        
//        hostingController.didMove(toParent: self)
        embedSwiftUIView(StatsView())
    }
}
