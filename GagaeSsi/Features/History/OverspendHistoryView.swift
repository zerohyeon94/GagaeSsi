//
//  OverspendHistoryView.swift
//  GagaeSsi
//
//  "언제 초과했는지" 되짚어보기 — 초과한 날 목록에서 그날 소비를 바로 확인한다.
//

import SwiftUI

struct OverspendHistoryView: View {
    /// 현재 남은 초과분 (없으면 nil)
    var remainingDebt: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var days: [OverspendDay] = []
    @State private var expanded: Date?
    @State private var records: [Date: [SpendingRecordModel]] = [:]

    private var total: Int { OverspendAnalyzer.total(of: days) }
    private var worst: OverspendDay? { OverspendAnalyzer.worst(of: days) }

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    summaryCard
                    if days.isEmpty { emptyCard } else { listCard }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("초과한 날")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    // MARK: - 요약

    private var summaryCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                if let remainingDebt, remainingDebt > 0 {
                    HStack {
                        Text("💪 아직 갚는 중")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                        Spacer()
                        Text(FormatterUtils.currencyString(from: remainingDebt))
                            .font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                    }
                    GagaeDivider()
                }

                HStack {
                    Text("최근 3개월 초과한 날")
                        .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text("\(days.count)일 · \(FormatterUtils.currencyString(from: total))")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeDanger)
                }

                if let worst {
                    Text("가장 크게 넘긴 날은 \(dayLabel(worst.date))이에요 (\(FormatterUtils.currencyString(from: worst.overspentAmount)))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var emptyCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.sm) {
                Text("🐷").font(.system(size: 32))
                Text("최근 3개월 동안 넘긴 날이 없어요")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                Text("잘 지키고 계세요!")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagaeSpacing.sm)
        }
    }

    // MARK: - 목록

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(days) { day in
                dayRow(day)
                if expanded == day.date { detail(day) }
                if day.id != days.last?.id {
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5)
                }
            }
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func dayRow(_ day: OverspendDay) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                if expanded == day.date {
                    expanded = nil
                } else {
                    expanded = day.date
                    loadRecords(for: day.date)
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayLabel(day.date))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeText)
                    Text("그날 배정 \(FormatterUtils.currencyString(from: day.availableThatDay)) · 쓴 돈 \(FormatterUtils.currencyString(from: day.outgoing))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+" + FormatterUtils.currencyString(from: day.overspentAmount))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                    Text("초과").font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
                Image(systemName: expanded == day.date ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.gagaeTextTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detail(_ day: OverspendDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let list = records[day.date] ?? []
            if list.isEmpty {
                Text("이 날은 소비 기록이 없어요 (이월 적자로 넘긴 날)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(list) { record in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(record.category.color.opacity(0.13)).frame(width: 28, height: 28)
                            Text(record.category.emoji).font(.system(size: 13))
                        }
                        Text(record.title.isEmpty ? record.category.rawValue : record.title)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.gagaeText).lineLimit(1)
                        Spacer()
                        Text("-" + FormatterUtils.currencyString(from: record.amount))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.gagaeDanger)
                    }
                }
            }

            if day.wishSaving > 0 {
                Text("🎁 위시 저금 \(FormatterUtils.currencyString(from: day.wishSaving))도 이 날 빠졌어요")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
        .background(Color.gagaeSurface.opacity(0.5))
    }

    // MARK: - Actions

    private func load() {
        days = CoreDataManager.shared.fetchOverspendDays(months: 3)
    }

    private func loadRecords(for date: Date) {
        guard records[date] == nil else { return }
        records[date] = CoreDataManager.shared.fetchSpendingRecords(date: date)
            .sorted { $0.amount > $1.amount }   // 큰 지출부터 (반성 우선순위)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack { OverspendHistoryView(remainingDebt: 289_605) }
}
