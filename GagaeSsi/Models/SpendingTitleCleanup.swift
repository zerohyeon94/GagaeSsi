//
//  SpendingTitleCleanup.swift
//  GagaeSsi
//
//  소비 항목 이름 정리 — 같은 가게를 다르게 적어 갈라진 기록을 찾아 합친다.
//
//  자동완성과 카테고리별 항목 집계는 "정규화 + 소문자" 완전일치로 묶는다.
//  그래서 "스타벅스 커피"와 "스타벅스커피"가 다른 항목이 되어 목록이 지저분해진다.
//
//  주의: 여기서 다루는 건 **표기뿐**이다. 금액·날짜·카테고리는 건드리지 않으므로
//  예산·이월·부채 계산에 영향이 없다.
//

import Foundation

/// 항목명 하나의 사용 통계
struct SpendingTitleStat: Identifiable, Equatable {
    var id: String { title.lowercased() }
    let title: String
    let count: Int
    let total: Int
    let lastDate: Date
}

/// 합칠 후보 묶음
struct SpendingTitleGroup: Identifiable, Equatable {
    enum Kind: Equatable {
        /// 공백·기호·대소문자만 다름 — 사실상 확실한 중복
        case duplicate
        /// 한쪽이 다른 쪽으로 시작함 ("스타벅스" / "스타벅스 커피") — 사용자 판단 필요
        case similar
    }

    var id: String { kind == .duplicate ? "dup-\(key)" : "sim-\(key)" }
    let key: String
    let kind: Kind
    let stats: [SpendingTitleStat]

    /// 합칠 때 기본으로 제안할 이름 (가장 많이 쓴 표기, 같으면 최근 것)
    var suggestedName: String {
        stats.max {
            $0.count != $1.count ? $0.count < $1.count : $0.lastDate < $1.lastDate
        }?.title ?? stats.first?.title ?? ""
    }

    var totalCount: Int { stats.reduce(0) { $0 + $1.count } }
    var totalAmount: Int { stats.reduce(0) { $0 + $1.total } }
}

enum SpendingTitleCleanup {
    /// 비교용 느슨한 키 — 공백·기호를 모두 없애고 소문자로.
    /// "스타벅스 커피", "스타벅스커피", "STARBUCKS-커피"가 모두 같은 키가 된다.
    static func looseKey(_ title: String) -> String {
        String(title.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// 기록에서 항목별 사용 통계를 뽑는다 (건수 많은 순).
    /// 묶는 기준은 자동완성과 동일한 `정규화 + 소문자`.
    static func titleStats(from records: [SpendingRecordModel]) -> [SpendingTitleStat] {
        struct Accumulator { var title: String; var count: Int; var total: Int; var lastDate: Date }
        var map: [String: Accumulator] = [:]

        for record in records {
            let normalized = SpendingSuggestionEngine.normalize(record.title)
            guard !normalized.isEmpty else { continue }
            let key = normalized.lowercased()

            if var accumulator = map[key] {
                accumulator.count += 1
                // 항목 이름 정리도 소비 기록 화면 — 내가 소비한 몫(myShare)으로 묶는다
                accumulator.total += record.myShare
                if record.date > accumulator.lastDate {
                    accumulator.title = normalized
                    accumulator.lastDate = record.date
                }
                map[key] = accumulator
            } else {
                map[key] = Accumulator(title: normalized, count: 1,
                                       total: record.myShare, lastDate: record.date)
            }
        }

        return map.values
            .map { SpendingTitleStat(title: $0.title, count: $0.count,
                                     total: $0.total, lastDate: $0.lastDate) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.total > rhs.total
            }
    }

    /// 공백·기호·대소문자만 다른 확실한 중복 묶음
    static func duplicateGroups(from stats: [SpendingTitleStat]) -> [SpendingTitleGroup] {
        Dictionary(grouping: stats) { looseKey($0.title) }
            .filter { $0.key.count >= 1 && $0.value.count >= 2 }
            .map { SpendingTitleGroup(key: $0.key, kind: .duplicate,
                                      stats: $0.value.sorted { $0.count > $1.count }) }
            .sorted { $0.totalCount > $1.totalCount }
    }

    /// 한쪽이 다른 쪽으로 **시작하는** 묶음 ("스타벅스" / "스타벅스 커피").
    ///
    /// 줄임말("스벅" ↔ "스타벅스")은 규칙으로 안전하게 잡을 수 없어 다루지 않는다.
    /// 그런 건 목록에서 직접 골라 합치면 된다.
    /// 확실한 중복(`duplicateGroups`)에 이미 들어간 표기는 제외한다.
    static func similarGroups(from stats: [SpendingTitleStat],
                              minimumPrefixLength: Int = 2) -> [SpendingTitleGroup] {
        let duplicateKeys = Set(duplicateGroups(from: stats).map(\.key))
        let candidates = stats.filter { !duplicateKeys.contains(looseKey($0.title)) }

        // 짧은 이름을 대표로 삼아, 그 이름으로 시작하는 긴 이름들을 모은다
        let sorted = candidates.sorted { looseKey($0.title).count < looseKey($1.title).count }
        var used = Set<String>()
        var groups: [SpendingTitleGroup] = []

        for base in sorted {
            let baseKey = looseKey(base.title)
            guard baseKey.count >= minimumPrefixLength, !used.contains(baseKey) else { continue }

            let members = sorted.filter { candidate in
                let key = looseKey(candidate.title)
                return key != baseKey && !used.contains(key) && key.hasPrefix(baseKey)
            }
            guard !members.isEmpty else { continue }

            used.insert(baseKey)
            members.forEach { used.insert(looseKey($0.title)) }
            groups.append(SpendingTitleGroup(key: baseKey, kind: .similar,
                                             stats: ([base] + members).sorted { $0.count > $1.count }))
        }

        return groups.sorted { $0.totalCount > $1.totalCount }
    }
}
