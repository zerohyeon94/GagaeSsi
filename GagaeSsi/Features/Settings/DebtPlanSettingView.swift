//
//  DebtPlanSettingView.swift
//  GagaeSsi
//
//  초과 소비 상환 계획 설정 — 기능 on/off, 진행 중인 부채의 비율 변경·조기 완납
//

import SwiftUI

struct DebtPlanSettingView: View {
    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss

    @State private var enabled = true
    @State private var debt: SpendingDebtModel?
    @State private var dailyBudget = 0
    @State private var rate = DebtRepaymentPlan.defaultRate
    @State private var showDisableConfirm = false
    @State private var showSettleConfirm = false

    private var plan: (perDay: Int, days: Int) {
        DebtRepaymentPlan.calculate(debt: debt?.remainingAmount ?? 0,
                                    dailyBudget: dailyBudget, ratePercent: rate)
    }

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    toggleCard
                    if enabled {
                        if let debt, debt.isActive {
                            activeDebtCard(debt)
                        } else {
                            emptyCard
                        }
                    }
                    explainCard
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("초과분 상환 계획")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .alert("상환 계획을 끌까요?", isPresented: $showDisableConfirm) {
            Button("취소", role: .cancel) { enabled = true }
            Button("끄기", role: .destructive) { disable() }
        } message: {
            Text("남은 초과분 \(FormatterUtils.currencyString(from: debt?.remainingAmount ?? 0))이 오늘 예산에서 한 번에 차감돼요.")
        }
        .alert("남은 초과분을 한 번에 갚을까요?", isPresented: $showSettleConfirm) {
            Button("취소", role: .cancel) {}
            Button("한 번에 갚기") { settle() }
        } message: {
            Text("\(FormatterUtils.currencyString(from: debt?.remainingAmount ?? 0))이 오늘 예산에서 차감돼요.")
        }
    }

    // MARK: - Cards

    private var toggleCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Toggle(isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        // 끌 때 남은 부채가 있으면 확인부터 받는다
                        if !newValue, let debt, debt.isActive, debt.remainingAmount > 0 {
                            enabled = false
                            showDisableConfirm = true
                        } else {
                            enabled = newValue
                            _ = CoreDataManager.shared.setDebtPlanEnabled(newValue)
                            load()
                        }
                    }
                )) {
                    Text("초과분 나눠 갚기")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                }
                .tint(.gagaePinkDark)

                Text(enabled
                     ? "예산을 크게 넘긴 다음 날, 초과분을 한 번에 빼지 않고 며칠에 나눠 갚아요."
                     : "끄면 초과분이 다음 날 예산에서 한 번에 차감돼요 (기존 방식).")
                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func activeDebtCard(_ debt: SpendingDebtModel) -> some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                HStack {
                    Text("💪 갚는 중")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: debt.remainingAmount))
                        .font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                }
                Text("처음 \(FormatterUtils.currencyString(from: debt.originalAmount)) 중 \(FormatterUtils.currencyString(from: debt.repaidAmount)) 갚았어요")
                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)

                GagaeDivider()

                HStack {
                    Text("하루 예산의").font(.gagaeCallout).foregroundStyle(.gagaeText)
                    Spacer()
                    Text("\(rate)%").font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GagaeSpacing.sm) {
                        ForEach(DebtRepaymentPlan.rateOptions, id: \.self) { option in
                            rateChip(option)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if plan.perDay > 0 {
                    Text("하루 \(FormatterUtils.currencyString(from: plan.perDay))씩 · 앞으로 \(plan.days)일")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                } else {
                    Text("이 비율로는 하루 상환액이 0원이에요. 더 높은 비율을 골라주세요.")
                        .font(.gagaeCaption).foregroundStyle(.gagaeDanger)
                }

                if DebtRepaymentPlan.isAggressive(ratePercent: rate) {
                    Text("⚠️ 한국 DSR 규제 상한(은행권 40%)보다 빡센 설정이에요.")
                        .font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GagaeDivider()

                Button {
                    showSettleConfirm = true
                } label: {
                    Text("남은 초과분 한 번에 갚기")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeDanger)
                        .frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rateChip(_ option: Int) -> some View {
        let selected = option == rate
        return Button {
            rate = option
            _ = CoreDataManager.shared.updateDebtRate(option)
            eventBus.notifyBudgetChanged()
        } label: {
            Text("\(option)%")
                .font(.system(size: 14, weight: selected ? .heavy : .medium, design: .rounded))
                .foregroundStyle(selected ? .white : Color.gagaeTextSecondary)
                .frame(minWidth: 52).padding(.vertical, 9)
                .background(selected ? AnyShapeStyle(Color.gagaePinkDark) : AnyShapeStyle(Color.gagaeSurface))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.sm) {
                Text("🐷").font(.system(size: 32))
                Text("지금은 갚을 초과분이 없어요")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                Text("예산을 크게 넘긴 다음 날 상환 계획을 제안해요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagaeSpacing.sm)
        }
    }

    private var explainCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("비율은 어떻게 정하나요?")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                explainRow("20%", "50/30/20 법칙에서 저축·부채 상환에 권하는 비율이에요. 기본값이자 무난한 출발점.")
                explainRow("25~35%", "빨리 털고 싶을 때. 고금리 부채에 권장되는 공격적 상환 구간이에요.")
                explainRow("40% 이상", "한국 DSR 규제 상한(은행권 40%)을 넘는 수준. 무리하면 다시 초과하기 쉬워요.")
                Text("위 기준은 월 소득 대비 비율이라 하루 예산과 정확히 같지는 않아요. 감을 잡는 출발점으로만 참고하세요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private func explainRow(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: GagaeSpacing.sm) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.gagaePinkDark)
                .frame(width: 62, alignment: .leading)
            Text(body)
                .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func load() {
        let config = CoreDataManager.shared.fetchBudgetConfig()
        enabled = config?.debtPlanEnabled ?? true
        debt = CoreDataManager.shared.fetchActiveDebt()
        rate = debt?.repayRatePercent ?? DebtRepaymentPlan.defaultRate
        // 상환액 미리보기에만 쓰므로, 일자를 만들지 않는 순수 계산으로 구한다.
        dailyBudget = config.map {
            DailyBudgetCalculator.calculate(from: $0,
                                            installments: CoreDataManager.shared.fetchInstallments(),
                                            for: Date())
        } ?? 0
    }

    private func disable() {
        _ = CoreDataManager.shared.setDebtPlanEnabled(false)
        eventBus.notifySpendingAdded()
        load()
    }

    private func settle() {
        _ = CoreDataManager.shared.settleDebtImmediately()
        eventBus.notifySpendingAdded()
        load()
    }
}

#Preview {
    NavigationStack {
        DebtPlanSettingView()
    }
    .environment(AppEventBus())
}
