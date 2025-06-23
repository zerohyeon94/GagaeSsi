//
//  AlertHelper.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/23/25.
//

import UIKit

struct AlertHelper {
    static func showAlert(on vc: UIViewController, title: String, message: String, button: String = "확인", completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: button, style: .default) { _ in
            completion?()
        })
        vc.present(alert, animated: true)
    }

    static func showError(on vc: UIViewController, message: String, completion: (() -> Void)? = nil) {
        showAlert(on: vc, title: "오류", message: message, completion: completion)
    }

    static func showConfirm(on vc: UIViewController, title: String, message: String, okTitle: String = "확인", cancelTitle: String = "취소", okHandler: (() -> Void)? = nil, cancelHandler: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            cancelHandler?()
        })
        alert.addAction(UIAlertAction(title: okTitle, style: .default) { _ in
            okHandler?()
        })
        vc.present(alert, animated: true)
    }
}
