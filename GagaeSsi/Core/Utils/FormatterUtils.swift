//
//  FormatterUtils.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/26/25.
//

import Foundation

enum FormatterUtils {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    static func currencyString(from amount: Int) -> String {
        let formattedNumber = amount.formatted(.number.locale(Locale(identifier: "ko_KR"))) // ex) "50,000"
        return "₩\(formattedNumber)"
    }

    /// 문자열을 숫자로 파싱하고 쉼표 포맷 문자열로 반환
    static func formatCurrencyInput(_ rawText: String?) -> (plainNumber: Int, formatted: String)? {
        guard let rawText = rawText else { return nil }
        
        let plain = rawText.replacingOccurrences(of: ",", with: "")
        let number = Int(plain) ?? 0
        let formatted = currencyFormatter.string(from: NSNumber(value: number)) ?? ""
        
        return (number, formatted)
    }
    
    // MARK: - 고정비 text 표시용
    static func inputAmountString(from value: Int) -> String {
        return value == 0 ? "" : "\(currencyFormatter.string(from: NSNumber(value: value)) ?? "")"
    }
}
