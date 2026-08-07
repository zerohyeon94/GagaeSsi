//
//  DebtPlanSheet.swift
//  GagaeSsi
//
//  초과 소비 상환 계획 설정 시트 — 하루 예산의 몇 %씩 갚을지 고르면
//  하루 상환액과 소요 일수를 미리 보여준다.
//

import SwiftUI

struct DebtPlanSheet: View {
    /// 갚아야 할 초과 금액
    let debtAmount: Int
    /// 하루 기본 예산 (상환액 계산 기준)
    let dailyBudget: Int
    /// 초기 선택 비율
    var initialRate: Int = DebtRepaymentPlan.defaultRate
    /// 확정 시 선택한 비율 전달
    let onConfirm: (Int) -> Void
    /// "나중에" — 오늘은 다시 띄우지 않는다
    var onDefer: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var rate: Int = DebtRepaymentPlan.defaultRate

    private var plan: (perDay: Int, days: Int) {
        DebtRepaymentPlan.calculate(debt: debtAmount, dailyBudget: dailyBudget, ratePercent: rate)
    }
    private var isValid: Bool { plan.perDay > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: GagaeSpacing.md) {
                        summaryCard
                        rateCard
                        resultCard
                        actionButtons
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.vertical, GagaeSpacing.md)
                }
            }
            .navigationTitle("초과분 갚기")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
        .onAppear { rate = initialRate }
        .presentationDragIndicator(.hidden)
    }

    // MARK: - 초과 금액 요약

    private var summaryCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                HStack(spacing: GagaeSpacing.sm) {
                    Text("💪").font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("어제 예산을 넘겼어요")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                        Text("한 번에 빼지 않고 나눠서 갚아요")
                            .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    }
                }

                GagaeDivider()

                HStack {
                    Text("갚을 초과 금액").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: debtAmount))
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeDanger)
                }
                HStack {
                    Text("하루 사용 가능 금액").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: dailyBudget))
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                }
            }
        }
    }

    // MARK: - 비율 선택

    private var rateCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                HStack {
                    Text("하루 예산의 몇 %씩 갚을까요?")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    Spacer()
                    Text("\(rate)%")
                        .font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: GagaeSpacing.sm) {
                            ForEach(DebtRepaymentPlan.rateOptions, id: \.self) { option in
                                rateChip(option).id(option)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .onAppear {
                        // 기본 선택(20%)이 화면 밖에 숨지 않도록 중앙으로 스크롤
                        DispatchQueue.main.async {
                            withAnimation { proxy.scrollTo(rate, anchor: .center) }
                        }
                    }
                }

                if DebtRepaymentPlan.isAggressive(ratePercent: rate) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("⚠️").font(.system(size: 13))
                        Text("한국 DSR 규제 상한(은행권 40%)보다 빡센 설정이에요. 무리하면 다시 초과하기 쉬워요.")
                            .font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if rate == DebtRepaymentPlan.defaultRate {
                    HStack(alignment: .top, spacing: 6) {
                        Text("💡").font(.system(size: 13))
                        Text("50/30/20 법칙에서 저축·부채 상환에 권하는 비율이에요. 부담 없는 출발점입니다.")
                            .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func rateChip(_ option: Int) -> some View {
        let selected = option == rate
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { rate = option }
        } label: {
            Text("\(option)%")
                .font(.system(size: 14, weight: selected ? .heavy : .medium, design: .rounded))
                .foregroundStyle(selected ? .white : Color.gagaeTextSecondary)
                .frame(minWidth: 52)
                .padding(.vertical, 9)
                .background(selected ? AnyShapeStyle(Color.gagaePinkDark) : AnyShapeStyle(Color.gagaeSurface))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 계산 결과

    private var resultCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.sm) {
                if isValid {
                    Text("하루 \(FormatterUtils.currencyString(from: plan.perDay))씩")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                    Text("\(plan.days)일 동안 갚으면 끝나요")
                        .font(.gagaeCallout).foregroundStyle(.gagaeText)
                    Text("이 금액은 하루 사용 가능 금액에서 자동으로 빠져요")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("이 비율로는 갚을 수 없어요")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeDanger)
                    Text("하루 상환액이 0원이 돼요. 더 높은 비율을 골라주세요.")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagaeSpacing.sm)
        }
    }

    // MARK: - 버튼

    private var actionButtons: some View {
        VStack(spacing: GagaeSpacing.sm) {
            GagaePrimaryButton(title: "이 계획으로 갚기", isEnabled: isValid) {
                onConfirm(rate)
                dismiss()
            }
            Button {
                onDefer?()
                dismiss()
            } label: {
                Text("나중에")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeTextSecondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    DebtPlanSheet(debtAmount: 100_000, dailyBudget: 50_000, onConfirm: { _ in })
}
