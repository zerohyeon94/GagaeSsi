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
    /// 모아둔 이월금으로 먼저 갚을 수 있는 금액 (0이면 제안하지 않음)
    var repayableFromPool: Int = 0
    /// 부채가 시작된 날. 과거 소비를 뒤늦게 입력해 며칠치가 한꺼번에 잡히면
    /// "어제 넘겼어요"가 사실과 달라지므로 안내 문구를 바꾼다.
    var startedAt: Date?
    /// 확정 시 선택한 비율 전달
    let onConfirm: (Int) -> Void
    /// "나중에" — 오늘은 다시 띄우지 않는다
    var onDefer: (() -> Void)?
    /// 모아둔 이월금으로 먼저 갚기
    var onRepayFromPool: ((Int) -> Void)?
    /// 할부로 나누기 (개월 수 전달)
    var onConvertToInstallment: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var rate: Int = DebtRepaymentPlan.defaultRate
    @State private var usePool = false
    /// 나눠 갚기 대신 할부로 돌릴지 (여행 등 계획했던 큰 지출)
    @State private var useInstallment = false
    @State private var months = 3

    private static let monthOptions = [2, 3, 6, 12]
    /// 할부 월 납입액 (원 단위 내림)
    private var monthlyAmount: Int { months > 0 ? effectiveDebt / months : 0 }

    /// 풀로 먼저 갚은 뒤 실제로 계획을 세울 금액
    private var effectiveDebt: Int {
        usePool ? max(0, debtAmount - repayableFromPool) : debtAmount
    }
    private var plan: (perDay: Int, days: Int) {
        DebtRepaymentPlan.calculate(debt: effectiveDebt, dailyBudget: dailyBudget, ratePercent: rate)
    }
    private var isValid: Bool {
        if effectiveDebt == 0 { return true }
        return useInstallment ? monthlyAmount > 0 : plan.perDay > 0
    }

    /// 초과가 있었던 날부터 오늘까지의 일수. 부채는 "전날 초과"가 다음 날 전환되므로 +1.
    private var spanDays: Int? {
        guard let startedAt else { return nil }
        let cal = Calendar.current
        guard let days = cal.dateComponents([.day], from: cal.startOfDay(for: startedAt),
                                            to: cal.startOfDay(for: Date())).day else { return nil }
        return days + 1
    }
    /// 어제 넘긴 게 아니라 며칠치가 소급으로 모인 경우
    private var isBackdated: Bool { (spanDays ?? 0) > 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: GagaeSpacing.md) {
                        summaryCard
                        if repayableFromPool > 0 { poolCard }
                        if effectiveDebt > 0 {
                            methodCard
                            if useInstallment { monthsCard } else { rateCard }
                        }
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
                        Text(isBackdated
                             ? "지난 \(spanDays ?? 0)일 사이에 예산을 넘겼어요"
                             : "어제 예산을 넘겼어요")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                        Text(isBackdated
                             ? "뒤늦게 입력한 소비까지 모아서 계산했어요"
                             : "한 번에 빼지 않고 나눠서 갚아요")
                            .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - 모아둔 이월금 선상환 제안

    private var poolCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Toggle(isOn: $usePool.animation(.easeInOut(duration: 0.15))) {
                    HStack(spacing: 6) {
                        Text("🐷").font(.system(size: 16))
                        Text("모아둔 이월금으로 먼저 갚기")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    }
                }
                .tint(.gagaePinkDark)

                Text("모아둔 \(FormatterUtils.currencyString(from: repayableFromPool))을 먼저 쓰면 갚을 금액이 줄어 기간이 짧아져요. 오늘 쓸 수 있는 금액은 그대로예요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if usePool {
                    GagaeDivider()
                    HStack {
                        Text("갚을 금액").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                        Spacer()
                        Text("\(FormatterUtils.currencyString(from: debtAmount)) → \(FormatterUtils.currencyString(from: effectiveDebt))")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                    }
                }
            }
        }
    }

    // MARK: - 갚는 방식 선택

    /// 나눠 갚기 vs 할부. 여행처럼 의도한 큰 지출은 "빚 갚기" 톤이 맞지 않는다.
    private var methodCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Toggle(isOn: $useInstallment.animation(.easeInOut(duration: 0.15))) {
                    HStack(spacing: 6) {
                        Text("🧾").font(.system(size: 16))
                        Text("할부처럼 여러 달로 나누기")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    }
                }
                .tint(.gagaePinkDark)

                Text(useInstallment
                     ? "매달 조금씩 하루 예산이 줄어요. 하루 예산에서 바로 빼는 것보다 부담이 적어요."
                     : "여행처럼 계획했던 큰 지출이라면 이 편이 나아요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 개월 선택 (할부)

    private var monthsCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                HStack {
                    Text("몇 달에 나눠 낼까요?")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    Spacer()
                    Text("\(months)개월")
                        .font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                }
                HStack(spacing: GagaeSpacing.sm) {
                    ForEach(Self.monthOptions, id: \.self) { option in
                        monthChip(option)
                    }
                }
            }
        }
    }

    private func monthChip(_ option: Int) -> some View {
        let selected = option == months
        return Button {
            months = option
        } label: {
            Text("\(option)개월")
                .font(.system(size: 14, weight: selected ? .heavy : .medium, design: .rounded))
                .foregroundStyle(selected ? .white : Color.gagaeTextSecondary)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(selected ? AnyShapeStyle(Color.gagaePinkDark) : AnyShapeStyle(Color.gagaeSurface))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
                if effectiveDebt == 0 {
                    Text("모아둔 이월금으로 다 갚아요")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                    Text("따로 나눠 갚을 금액이 없어요")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                } else if useInstallment {
                    Text("매달 \(FormatterUtils.currencyString(from: monthlyAmount))씩")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                    Text("\(months)개월 동안 나눠 내요")
                        .font(.gagaeCallout).foregroundStyle(.gagaeText)
                    Text("초과분이 할부로 바뀌어 하루 예산이 조금씩 줄어요")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        .multilineTextAlignment(.center)
                } else if isValid {
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

    private var primaryTitle: String {
        if effectiveDebt == 0 { return "이월금으로 갚기" }
        return useInstallment ? "할부로 나누기" : "이 계획으로 갚기"
    }

    private var actionButtons: some View {
        VStack(spacing: GagaeSpacing.sm) {
            GagaePrimaryButton(title: primaryTitle, isEnabled: isValid) {
                // 풀 선상환을 먼저 반영해야 남은 금액 기준으로 계획이 세워진다
                if usePool, repayableFromPool > 0 { onRepayFromPool?(repayableFromPool) }
                if effectiveDebt > 0 {
                    if useInstallment { onConvertToInstallment?(months) } else { onConfirm(rate) }
                }
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
