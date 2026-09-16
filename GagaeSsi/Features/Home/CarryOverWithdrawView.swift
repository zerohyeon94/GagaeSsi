//
//  CarryOverWithdrawView.swift
//  GagaeSsi
//
//  모아둔 이월금 → 오늘 예산으로 꺼내 쓰기 시트
//

import SwiftUI

struct CarryOverWithdrawView: View {
    let poolBalance: Int
    let onWithdraw: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var amount = 0
    @FocusState private var focused: Bool

    private var isValid: Bool { amount > 0 && amount <= poolBalance }

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
                            Text("오늘 예산으로 가져올 금액을 입력하세요.\n남기면 다음 날 다시 모아둔 이월금으로 돌아가요.")
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
                                .stroke(focused ? Color.gagaePinkDark : Color.gagaeDivider, lineWidth: focused ? 2 : 0.5))

                            if amount > poolBalance {
                                Text("모아둔 이월금보다 많이 꺼낼 수 없어요")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeDanger)
                            }

                            Button {
                                amount = poolBalance
                                amountText = FormatterUtils.inputAmountString(from: poolBalance)
                            } label: {
                                Text("전액 꺼내기").font(.gagaeCaptionMedium).foregroundStyle(.gagaePinkDark)
                            }
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "꺼내 쓰기", isEnabled: isValid) {
                        onWithdraw(amount)
                        dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("이월금 꺼내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
