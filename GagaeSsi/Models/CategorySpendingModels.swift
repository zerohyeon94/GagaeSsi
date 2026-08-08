//
//  CategorySpendingModels.swift
//  GagaeSsi
//
//  카테고리 안에서 "무엇에 얼마나 썼는지" 집계.
//
//  통계는 카테고리 합계까지만 보여줘서 "카페에 12만원"은 알아도
//  그게 스타벅스인지 편의점 커피인지는 알 수 없었다. 항목명으로 묶어
//  반복 소비를 드러낸다.
//

import Foundation

/// 카테고리 안의 항목별 집계 (같은 이름끼리 묶음)
struct CategorySpendingItem: Identifiable, Equatable {
    var id: String { title.lowercased() }
    /// 표시용 항목명 (가장 최근 기록의 표기를 따른다)
    let title: String
    /// 합계 금액
    let total: Int
    /// 기록 건수
    let count: Int
    /// 마지막으로 산 날
    let lastDate: Date

    /// 1회 평균 금액
    var average: Int { count > 0 ? total / count : 0 }
}

enum CategorySpendingAnalyzer {
    /// 제목 없는 기록의 표시 이름
    static let untitledLabel = "(제목 없음)"

    /// 항목명으로 묶어 금액 큰 순으로 정렬한다.
    /// 묶는 기준은 자동완성과 동일하게 `정규화 + 소문자` — 화면에 보이는 묶임이
    /// 입력할 때 뜨는 추천과 어긋나지 않도록 같은 규칙을 쓴다.
    static func itemSummaries(from records: [SpendingRecordModel]) -> [CategorySpendingItem] {
        struct Accumulator {
            var title: String
            var total: Int
            var count: Int
            var lastDate: Date
        }
        var map: [String: Accumulator] = [:]

        for record in records {
            let normalized = SpendingSuggestionEngine.normalize(record.title)
            let display = normalized.isEmpty ? untitledLabel : normalized
            let key = display.lowercased()

            if var accumulator = map[key] {
                accumulator.total += record.amount
                accumulator.count += 1
                if record.date > accumulator.lastDate {
                    accumulator.title = display          // 최근 표기를 대표로
                    accumulator.lastDate = record.date
                }
                map[key] = accumulator
            } else {
                map[key] = Accumulator(title: display, total: record.amount,
                                       count: 1, lastDate: record.date)
            }
        }

        return map.values
            .map { CategorySpendingItem(title: $0.title, total: $0.total,
                                        count: $0.count, lastDate: $0.lastDate) }
            .sorted { lhs, rhs in
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.lastDate > rhs.lastDate
            }
    }

    /// 2건 이상 반복해서 산 항목만 (습관이 드러나는 것들)
    static func repeatedItems(from items: [CategorySpendingItem]) -> [CategorySpendingItem] {
        items.filter { $0.count >= 2 }
    }
}
