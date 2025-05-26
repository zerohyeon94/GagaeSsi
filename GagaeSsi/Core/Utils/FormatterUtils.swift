//
//  FormatterUtils.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/26/25.
//

import Foundation

struct FormatterUtils {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
}
