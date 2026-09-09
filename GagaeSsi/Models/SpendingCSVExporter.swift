//
//  SpendingCSVExporter.swift
//  GagaeSsi
//
//  소비 기록 → CSV 내보내기 (순수 로직)
//
//  서버에 사본이 없는 앱이라 기기를 잃으면 기록이 영구 소실된다.
//  사용자가 직접 파일로 빼둘 수 있는 유일한 수단.
//

import Foundation

enum SpendingCSVExporter {
    /// 내보낼 기간
    enum Range: String, CaseIterable, Identifiable {
        case thisMonth = "이번 달"
        case last3Months = "최근 3개월"
        case all = "전체"

        var id: String { rawValue }

        /// 조회 시작일 (nil이면 제한 없음)
        func startDate(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
            let today = calendar.startOfDay(for: now)
            switch self {
            case .thisMonth:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: today))
            case .last3Months:
                return calendar.date(byAdding: .month, value: -3, to: today)
            case .all:
                return nil
            }
        }
    }

    static let header = ["날짜", "시각", "카테고리", "항목", "금액", "내 몫", "환급 예정", "환급 받음"]

    /// 한글이 Excel에서 깨지지 않게 하는 UTF-8 BOM.
    /// 없으면 Excel이 CSV를 로컬 인코딩으로 읽어 한글이 전부 깨진다.
    static let byteOrderMark = "\u{FEFF}"

    /// 기록을 CSV 문자열로 변환한다 (최신순).
    static func makeCSV(from records: [SpendingRecordModel],
                        calendar: Calendar = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ko_KR")
        timeFormatter.dateFormat = "HH:mm"

        var lines = [header.map(escape).joined(separator: ",")]

        for record in records.sorted(by: { $0.date > $1.date }) {
            let fields = [
                dateFormatter.string(from: record.date),
                timeFormatter.string(from: record.date),
                record.category.rawValue,
                record.title,
                String(record.amount),
                String(record.myShare),
                record.expectedPayback > 0 ? String(record.expectedPayback) : "",
                record.expectedPayback > 0 ? (record.paybackReceived ? "Y" : "N") : "",
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }

        return byteOrderMark + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// CSV 필드 이스케이프 — 쉼표·따옴표·줄바꿈이 있으면 큰따옴표로 감싸고 내부 따옴표는 두 번 쓴다.
    /// 항목명에 쉼표를 넣는 사용자가 있으므로 반드시 필요하다.
    static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// 공유용 파일 이름 (예: 가계씨_소비내역_2026-08-08.csv)
    static func fileName(for range: Range, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        return "가계씨_소비내역_\(range.rawValue)_\(formatter.string(from: now)).csv"
    }

    /// CSV를 임시 파일로 써서 URL을 돌려준다 (ShareLink 전달용)
    static func writeTemporaryFile(csv: String, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
