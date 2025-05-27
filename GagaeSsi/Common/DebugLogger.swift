//
//  DebugLogger.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/27/25.
//

import Foundation

enum DebugLogger {

    static func printDate(_ label: String, _ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        let dateString = formatter.string(from: date)
        print("🕓 \(label): \(dateString)")
    }

    static func debugLog(_ message: String) {
#if DEBUG
        print("🐞 DEBUG: \(message)")
#endif
    }

    static func errorLog(_ message: String) {
        print("❌ ERROR: \(message)")
    }

    static func section(_ name: String) {
        print("\n🚧 [\(name)] 시작 ------------------------")
    }
}
