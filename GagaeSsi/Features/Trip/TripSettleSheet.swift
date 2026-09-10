//
//  TripSettleSheet.swift
//  GagaeSsi
//
//  정산 시트 — 계산된 받을 돈을 보여주고, 실제 금액을 고칠 수 있게 한다
//

import SwiftUI

struct TripSettleSheet: View {
    let trip: TripModel
    let settlement: TripSettlementModel
    /// 연결된 지갑 이름 (nil이면 예산으로)
    let walletTitle: String?
    let onSettle: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var amount = 0

    private var differsFromComputed: Bool { amount != settlement.receivable }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            Text("🧳 \(trip.title)").font(.gagaeHeadline).foregroundStyle(.gagaeText)

                            line("공용 지출", settlement.sharedTotal)
                            if let n = settlement.uniformParticipants, let per = settlement.perPersonSpending {
                                HStack {
                                    Text("÷ \(n)명").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                    Spacer()
                                    Text("인당 \(FormatterUtils.currencyString(from: per))")
                                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                }
                            } else {
                                line("내 몫 합계", settlement.myShareTotal)
                            }
                            line("내가 낸 돈", settlement.paidByMeTotal)

                            GagaeDivider()

                            Label("받을 돈", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) {
                                            amount = r.plainNumber; amountText = r.formatted
                                        } else if v.isEmpty { amount = 0 }
                                    }
                            }
                            .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            if differsFromComputed {
                                Text("계산과 다른 금액이에요 (계산: \(FormatterUtils.currencyString(from: settlement.receivable)))")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                            }

                            if let walletTitle {
                                Text("→ 🎁 \(walletTitle) 지갑으로 돌아가요")
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeGood)
                            } else {
                                Text("→ 오늘 예산으로 들어와요")
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeGood)
                            }
                            Text("정산하면 이 여행에 소비를 더 넣거나 고칠 수 없어요. 필요하면 정산을 다시 열 수 있어요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: amount > 0 ? "정산 완료" : "받을 돈 없이 정산 완료", isEnabled: true) {
                        onSettle(amount); dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("정산").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark) } }
            .onAppear {
                amount = settlement.receivable
                amountText = settlement.receivable > 0 ? FormatterUtils.inputAmountString(from: settlement.receivable) : ""
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func line(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
            Spacer()
            Text(FormatterUtils.currencyString(from: value)).font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
        }
    }
}
