//
//  DebugLogger.swift
//  GagaeSsi
//
//  디버그 로깅 유틸리티
//

import Foundation

enum DebugLogger {
    static func log(_ items: Any...) {
#if DEBUG
        Swift.print("🪵", items.map { "\($0)" }.joined(separator: " "))
#endif
    }

    static func printDate(_ label: String, _ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        let dateString = formatter.string(from: date)
        Swift.print("🕓 \(label): \(dateString)")
    }

    static func debugLog(_ message: String) {
#if DEBUG
        Swift.print("🐞 DEBUG: \(message)")
#endif
    }

    static func errorLog(_ message: String) {
        Swift.print("❌ ERROR: \(message)")
    }

    static func section(_ name: String) {
        Swift.print("\n🚧 [\(name)] 시작 ------------------------")
    }
}
