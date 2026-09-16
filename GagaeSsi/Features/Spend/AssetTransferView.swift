//
//  AssetTransferView.swift
//  GagaeSsi
//
//  저축·투자 기록 — 예산에서는 빠지지만 소비로 잡히지 않는 '이동'
//

import SwiftUI

struct AssetTransferView: View {
    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss

    @State private var kind: AssetTransferKind = .investment
    @State private var amountText = ""
    @State private var amount = 0
    @State private var title = ""
    @State private var todayTransfers: [AssetTransferModel] = []
    @State private var monthSummary = AssetTransferSummary()
    @FocusState private var amountFocused: Bool

    private var isValid: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: GagaeSpacing.md) {
                        introCard
                        inputCard
                        GagaePrimaryButton(title: "기록하기", isEnabled: isValid) { save() }
                        if !todayTransfers.isEmpty { todayCard }
                        monthCard
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.vertical, GagaeSpacing.md)
                }
            }
            .navigationTitle("저축·투자 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear(perform: load)
            .onTapGesture { amountFocused = false }
        }
    }

    // MARK: - Cards

    private var introCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("투자는 쓴 돈이 아니라 옮긴 돈이에요")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                Text("오늘 예산에서는 빠지지만 소비 통계와 '초과한 날'에는 잡히지 않아요. 이번 달 소비가 부풀지 않아요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var inputCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                Picker("", selection: $kind) {
                    ForEach(AssetTransferKind.allCases) { Text("\($0.emoji) \($0.label)").tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                    Text("금액").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    HStack(spacing: GagaeSpacing.sm) {
                        Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                        TextField("0", text: $amountText)
                            .font(.gagaeTitle3).keyboardType(.numberPad).focused($amountFocused)
                            .onChange(of: amountText) { _, value in
                                if let result = FormatterUtils.formatCurrencyInput(value) {
                                    amount = result.plainNumber
                                    amountText = result.formatted
                                }
                            }
                    }
                    .padding(GagaeSpacing.md)
                    .background(Color.gagaeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: GagaeRadius.md)
                        .stroke(amountFocused ? Color.gagaePinkDark : Color.gagaeDivider,
                                lineWidth: amountFocused ? 2 : 0.5))
                }

                VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                    Text("항목 (선택)").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    TextField(kind.placeholder, text: $title)
                        .font(.gagaeCallout)
                        .padding(GagaeSpacing.md)
                        .background(Color.gagaeSurface)
                        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: GagaeRadius.md)
                            .stroke(Color.gagaeDivider, lineWidth: 0.5))
                }
            }
        }
    }

    private var todayCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("오늘 기록")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                ForEach(todayTransfers) { transfer in
                    HStack(spacing: 10) {
                        Text(transfer.kind.emoji).font(.system(size: 15))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(transfer.title.isEmpty ? transfer.kind.label : transfer.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.gagaeText).lineLimit(1)
                            Text(transfer.kind.label)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                        Spacer()
                        Text("-" + FormatterUtils.currencyString(from: transfer.amount))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(transfer.kind.color)
                        Button {
                            delete(transfer)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(.gagaeTextTertiary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var monthCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("이번 달 모은 돈")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)

                HStack(spacing: 0) {
                    ForEach(AssetTransferKind.allCases) { kind in
                        VStack(spacing: 3) {
                            Text(FormatterUtils.currencyString(from: monthSummary.total(of: kind)))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(kind.color)
                            Text("\(kind.emoji) \(kind.label)")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if monthSummary.total > 0 {
                    GagaeDivider()
                    HStack {
                        Text("합계").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                        Spacer()
                        Text(FormatterUtils.currencyString(from: monthSummary.total))
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func load() {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        todayTransfers = CoreDataManager.shared.fetchAssetTransfers(date: Date())
        monthSummary = CoreDataManager.shared.assetTransferSummary(
            year: comps.year ?? 0, month: comps.month ?? 0)
    }

    private func save() {
        let model = AssetTransferModel(date: Date(), amount: amount,
                                       title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                       kind: kind)
        guard CoreDataManager.shared.createAssetTransfer(model) else { return }

        amount = 0
        amountText = ""
        title = ""
        amountFocused = false
        load()
        eventBus.notifySpendingAdded()   // 홈 예산 갱신
    }

    private func delete(_ transfer: AssetTransferModel) {
        guard CoreDataManager.shared.deleteAssetTransfer(id: transfer.id) else { return }
        load()
        eventBus.notifySpendingAdded()
    }
}

#Preview {
    AssetTransferView().environment(AppEventBus())
}
