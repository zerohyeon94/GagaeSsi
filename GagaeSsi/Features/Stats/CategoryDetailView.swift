//
//  CategoryDetailView.swift
//  GagaeSsi
//
//  카테고리별 지출 목록 — 항목별 묶음 / 전체 기록
//

import SwiftUI

struct CategoryDetailView: View {
    let category: SpendingCategory
    /// 조회할 달 (그 달 1일 기준)
    let month: Date
    /// 그 달 전체 지출 (비중 계산용)
    var monthlyTotal: Int = 0

    private enum Mode: String, CaseIterable {
        case byItem = "항목별"
        case allRecords = "전체 기록"
    }

    @State private var mode: Mode = .byItem
    @State private var records: [SpendingRecordModel] = []
    @State private var items: [CategorySpendingItem] = []

    private var total: Int { records.reduce(0) { $0 + $1.amount } }
    private var share: Double {
        guard monthlyTotal > 0 else { return 0 }
        return Double(total) / Double(monthlyTotal)
    }

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    summaryCard

                    if records.isEmpty {
                        emptyCard
                    } else {
                        Picker("", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch mode {
                        case .byItem: itemListCard
                        case .allRecords: recordListCard
                        }
                    }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("\(category.emoji) \(category.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    // MARK: - 요약

    private var summaryCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                HStack {
                    Text(monthLabel)
                        .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: total))
                        .font(.gagaeTitle3).foregroundStyle(category.color)
                }

                GagaeDivider()

                HStack(spacing: 0) {
                    statItem("건수", "\(records.count)건")
                    statItem("항목 수", "\(items.count)개")
                    if monthlyTotal > 0 {
                        statItem("이번 달 비중", "\(Int((share * 100).rounded()))%")
                    }
                }

                if let top = items.first, items.count > 1 {
                    Text("가장 많이 쓴 항목은 \(top.title)이에요 (\(FormatterUtils.currencyString(from: top.total)))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.gagaeText)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.gagaeTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.sm) {
                Text(category.emoji).font(.system(size: 32))
                Text("이 달에는 \(category.rawValue) 지출이 없어요")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagaeSpacing.sm)
        }
    }

    // MARK: - 항목별

    private var itemListCard: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.gagaeText).lineLimit(1)
                        if item.count > 1 {
                            Text("\(item.count)번 · 평균 \(FormatterUtils.currencyString(from: item.average))")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.gagaeTextSecondary)
                        } else {
                            Text(dayLabel(item.lastDate))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FormatterUtils.currencyString(from: item.total))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.gagaeText)
                        if total > 0 {
                            Text("\(Int((Double(item.total) / Double(total) * 100).rounded()))%")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                if item.id != items.last?.id {
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 16)
                }
            }
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    // MARK: - 전체 기록

    private var recordListCard: some View {
        VStack(spacing: 0) {
            ForEach(records) { record in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title.isEmpty ? CategorySpendingAnalyzer.untitledLabel : record.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.gagaeText).lineLimit(1)
                        Text(dayLabel(record.date))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                    Spacer()
                    Text("-" + FormatterUtils.currencyString(from: record.amount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                if record.id != records.last?.id {
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 16)
                }
            }
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    // MARK: - Actions

    private func load() {
        let comps = Calendar.current.dateComponents([.year, .month], from: month)
        guard let year = comps.year, let monthValue = comps.month else { return }

        records = CoreDataManager.shared.fetchSpendingRecords(year: year, month: monthValue)
            .filter { $0.category == category }
            .sorted { $0.date > $1.date }
        items = CategorySpendingAnalyzer.itemSummaries(from: records)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: month)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: .cafe, month: Date(), monthlyTotal: 500_000)
    }
}
