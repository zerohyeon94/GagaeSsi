//
//  CarryOverPoolHistoryView.swift
//  GagaeSsi
//
//  모아둔 이월금 사용 내역 — 언제 왜 쌓이고 빠져나갔는지
//

import SwiftUI

struct CarryOverPoolHistoryView: View {
    /// 현재 풀 잔액
    var balance: Int = 0

    @State private var entries: [CarryOverPoolEntryModel] = []

    private var summary: CarryOverPoolSummary { CarryOverPoolSummary.make(from: entries) }
    private var usage: [(reason: CarryOverPoolReason, amount: Int)] {
        CarryOverPoolSummary.usageByReason(from: entries)
    }

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    summaryCard
                    if !usage.isEmpty { usageCard }
                    if entries.isEmpty { emptyCard } else { listCard }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("모아둔 이월금 내역")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    // MARK: - Cards

    private var summaryCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                HStack {
                    Text("🐷 지금 모아둔 돈")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: balance))
                        .font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                }

                GagaeDivider()

                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        Text("+" + FormatterUtils.currencyString(from: summary.depositTotal))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.gagaeGood)
                        Text("모인 돈").font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 3) {
                        Text("-" + FormatterUtils.currencyString(from: summary.usedTotal))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.gagaeDanger)
                        Text("쓴 돈").font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("최근 3개월 기준")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    private var usageCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("어디에 썼나요")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                ForEach(usage, id: \.reason) { item in
                    HStack(spacing: 8) {
                        Text(item.reason.emoji).font(.system(size: 14))
                        Text(item.reason.label)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.gagaeText)
                        Spacer()
                        Text(FormatterUtils.currencyString(from: item.amount))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.gagaeText)
                        if summary.usedTotal > 0 {
                            Text("\(Int((Double(item.amount) / Double(summary.usedTotal) * 100).rounded()))%")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.gagaeTextTertiary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var emptyCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.sm) {
                Text("🐷").font(.system(size: 32))
                Text("아직 내역이 없어요")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                Text("이월 방식을 '모아둔 이월금으로 분리'로 두면 아껴서 남은 돈이 여기에 쌓여요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagaeSpacing.sm)
        }
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(entry.isIncoming ? Color.gagaeGood.opacity(0.13) : Color.gagaePinkLight)
                            .frame(width: 32, height: 32)
                        Text(entry.reason.emoji).font(.system(size: 15))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.reason.label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.gagaeText)
                        Text(dayLabel(entry.date))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                    Spacer()
                    Text((entry.isIncoming ? "+" : "-")
                         + FormatterUtils.currencyString(from: abs(entry.amount)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.isIncoming ? .gagaeGood : .gagaeDanger)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)

                if entry.id != entries.last?.id {
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 58)
                }
            }
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    // MARK: - Actions

    private func load() {
        entries = CoreDataManager.shared.fetchPoolEntries(months: 3)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack { CarryOverPoolHistoryView(balance: 25_760) }
}
