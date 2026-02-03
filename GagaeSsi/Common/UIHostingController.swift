//
//  UIHostingController.swift
//  GagaeSsi
//
//  Created by 조영현 on 2/3/26.
//

import UIKit
import SwiftUI

// SwiftUI View를 UIKit에서 쉽게 사용하기 위한 래퍼
final class SwiftUIHostingController<Content: View>: UIHostingController<Content> {
    
    override func viewDidLoad() {
        super.viewDidLoad( )
        // 네비게이션 바 숨기기 (SwiftUI가 자체 관리)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

extension UIViewController {
    /// SwiftUI View를 자식으로 임베드
    func embedSwiftUIView<Content: View>(_ swiftUIView: Content) {
        let hostingController = UIHostingController(rootView: swiftUIView)
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
}
