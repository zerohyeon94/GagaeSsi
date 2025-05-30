//
//  BaseViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/21/25.
//

import UIKit

class BaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        logLifeCycle("viewDidLoad")
        setupTapToDismissKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logLifeCycle("viewWillAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logLifeCycle("viewDidAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        logLifeCycle("viewWillDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        logLifeCycle("viewDidDisappear")
    }

    private func logLifeCycle(_ methodName: String) {
        let className = String(describing: type(of: self))
        print("🌀 \(className) - \(methodName)")
    }

    // MARK: - Keyboard Dismiss
    private func setupTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
