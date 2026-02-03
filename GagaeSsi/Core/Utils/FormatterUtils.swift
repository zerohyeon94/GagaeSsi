//
//  FormatterUtils.swift
//  GagaeSsi
//
//  포맷팅 유틸리티
//

import Foundation

enum FormatterUtils {
    // MARK: - Currency Formatter
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    /// 금액을 통화 문자열로 변환
    static func currencyString(from amount: Int) -> String {
        let formattedNumber = amount.formatted(.number.locale(Locale(identifier: "ko_KR")))
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
    
    /// 고정비 text 표시용
    static func inputAmountString(from value: Int) -> String {
        return value == 0 ? "" : "\(currencyFormatter.string(from: NSNumber(value: value)) ?? "")"
    }
    
    // MARK: - Date Formatter
    /// "yyyy-MM-dd" 형식으로 날짜를 문자열로 변환
    static func formattedDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 상대적 날짜 표시 (오늘, 어제, 날짜)
    static func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "오늘"
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else {
            return formattedDate(date)
        }
    }
}
