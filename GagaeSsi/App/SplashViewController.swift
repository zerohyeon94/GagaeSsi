//
//  SplashViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 7/24/25.
//

import UIKit

class SplashViewController: UIViewController {
    
    private let imageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "splashImage"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground  // 다크모드 대응
        setupImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 1~2초 정도 보여주고 메인 화면으로 전환
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.routeNext()
        }
    }

    private func setupImage() {
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func routeNext() {
        let nextVC: UIViewController
        if CoreDataManager.shared.fetchBudgetConfig() != nil {
            nextVC = MainTabBarController()
        } else {
            let viewModel = SetupViewModel()
            nextVC = UINavigationController(rootViewController: SetupSalaryViewController(viewModel: viewModel))
        }
        
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = nextVC
            window.makeKeyAndVisible()
        }
    }
}
