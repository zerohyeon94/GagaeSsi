//
//  SpendingSuggestion.swift
//  GagaeSsi
//
//  소비 항목 자동완성 — 기존 기록에서 파생한 추천 (신규 스키마 없음)
//

import Foundation

// MARK: - 추천 항목
struct SpendingSuggestion: Identifiable, Equatable {
    var id: String { title.lowercased() }
    let title: String
    let category: SpendingCategory
    let lastAmount: Int
    let lastDate: Date
    let count: Int
}

// MARK: - 추천 엔진 (순수 함수)
enum SpendingSuggestionEngine {

    /// 항목명 정규화: 앞뒤 공백 제거 + 연속 공백 1칸
    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// 소비 기록 → 고유 항목별 추천 (정규화·중복 제거, 최근 카테고리/금액 반영)
    static func build(from records: [SpendingRecordModel]) -> [SpendingSuggestion] {
        struct Acc { var title: String; var category: SpendingCategory; var lastAmount: Int; var lastDate: Date; var count: Int }
        var map: [String: Acc] = [:]

        for r in records {
            let norm = normalize(r.title)
            guard !norm.isEmpty else { continue }
            let key = norm.lowercased()
            if var acc = map[key] {
                acc.count += 1
                if r.date > acc.lastDate {          // 더 최근 기록이면 표시 정보 갱신
                    acc.title = norm
                    acc.category = r.category
                    acc.lastAmount = r.amount
                    acc.lastDate = r.date
                }
                map[key] = acc
            } else {
                map[key] = Acc(title: norm, category: r.category, lastAmount: r.amount, lastDate: r.date, count: 1)
            }
        }

        return map.values.map {
            SpendingSuggestion(title: $0.title, category: $0.category,
                               lastAmount: $0.lastAmount, lastDate: $0.lastDate, count: $0.count)
        }
    }

    /// 쿼리로 필터·정렬. 빈 쿼리 → 최근순. 있으면 포함 필터 + prefix/recency/frequency/가나다.
    static func filter(_ suggestions: [SpendingSuggestion], query: String, limit: Int = 8) -> [SpendingSuggestion] {
        let q = normalize(query).lowercased()

        let result: [SpendingSuggestion]
        if q.isEmpty {
            result = suggestions.sorted { $0.lastDate > $1.lastDate }
        } else {
            result = suggestions
                .filter { $0.title.lowercased().contains(q) }
                .sorted { a, b in
                    let aStarts = a.title.lowercased().hasPrefix(q)
                    let bStarts = b.title.lowercased().hasPrefix(q)
                    if aStarts != bStarts { return aStarts }                       // ① prefix
                    if a.lastDate != b.lastDate { return a.lastDate > b.lastDate }  // ② recency
                    if a.count != b.count { return a.count > b.count }              // ③ frequency
                    return a.title < b.title                                        // ④ 가나다
                }
        }
        return Array(result.prefix(limit))
    }
}
