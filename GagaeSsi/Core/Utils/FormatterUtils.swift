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
    
    /// 차트 Y축용 축약 금액 표시 (1000 → 1k, 10000 → 1만)
    static func shortCurrencyString(from amount: Int) -> String {
        if amount == 0 { return "0" }
        if amount >= 10_000 {
            let man = amount / 10_000
            return "\(man)만"
        }
        if amount >= 1_000 {
            let k = amount / 1_000
            return "\(k)천"
        }
        return "\(amount)"
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

    /// 여행 기간 표시 (예: 9.12–9.14). 같은 날이면 한 번만.
    static func shortDateRange(_ from: Date, _ to: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M.d"
        let start = formatter.string(from: from)
        let end = formatter.string(from: to)
        return start == end ? start : "\(start)–\(end)"
    }
}
