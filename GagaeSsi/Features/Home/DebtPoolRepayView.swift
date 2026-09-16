//
//  DebtPoolRepayView.swift
//  GagaeSsi
//
//  모아둔 이월금 → 초과분 상환 시트.
//  오늘 예산은 건드리지 않고 풀 잔액과 남은 부채를 함께 줄인다.
//

import SwiftUI

struct DebtPoolRepayView: View {
    let poolBalance: Int
    let remainingDebt: Int
    let onRepay: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var amount = 0
    @FocusState private var focused: Bool

    /// 갚을 수 있는 최대 금액 (풀 잔액과 남은 부채 중 작은 쪽)
    private var maxAmount: Int { max(0, min(poolBalance, remainingDebt)) }
    private var isValid: Bool { amount > 0 && amount <= maxAmount }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            HStack {
                                Text("🐷 모아둔 이월금")
                                    .font(.gagaeHeadline).foregroundStyle(.gagaeText)
                                Spacer()
                                Text(FormatterUtils.currencyString(from: poolBalance))
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                            }
                            HStack {
                                Text("💪 남은 초과분")
                                    .font(.gagaeHeadline).foregroundStyle(.gagaeText)
                                Spacer()
                                Text(FormatterUtils.currencyString(from: remainingDebt))
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeDanger)
                            }

                            Text("모아둔 돈으로 초과분을 갚아요.\n오늘 쓸 수 있는 금액은 그대로예요.")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            GagaeDivider()

                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad).focused($focused)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) {
                                            amount = r.plainNumber; amountText = r.formatted
                                        }
                                    }
                            }
                            .padding(GagaeSpacing.md)
                            .background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                            .overlay(RoundedRectangle(cornerRadius: GagaeRadius.md)
                                .stroke(focused ? Color.gagaePinkDark : Color.gagaeDivider,
                                        lineWidth: focused ? 2 : 0.5))

                            if amount > maxAmount {
                                Text(poolBalance < remainingDebt
                                     ? "모아둔 이월금보다 많이 갚을 수 없어요"
                                     : "남은 초과분보다 많이 갚을 수 없어요")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeDanger)
                            }

                            Button {
                                setAmount(maxAmount)
                            } label: {
                                Text("전액 갚기 (\(FormatterUtils.currencyString(from: maxAmount)))")
                                    .font(.gagaeCaptionMedium).foregroundStyle(.gagaePinkDark)
                            }

                            if isValid {
                                GagaeDivider()
                                HStack {
                                    Text("갚고 나면 남는 초과분")
                                        .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                    Spacer()
                                    Text(FormatterUtils.currencyString(from: remainingDebt - amount))
                                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "이월금으로 갚기", isEnabled: isValid) {
                        onRepay(amount)
                        dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("이월금으로 갚기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear {
                setAmount(maxAmount)   // 기본값은 전액
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func setAmount(_ value: Int) {
        amount = value
        amountText = FormatterUtils.inputAmountString(from: value)
    }
}

#Preview {
    DebtPoolRepayView(poolBalance: 25_760, remainingDebt: 301_329) { _ in }
}
