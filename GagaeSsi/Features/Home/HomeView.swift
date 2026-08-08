//
//  HomeView.swift
//  GagaeSsi
//
//  홈 화면 - 오늘의 예산 현황 (Claude Design 적용)
//

import SwiftUI

struct HomeView: View {
    // MARK: - Properties
    @State private var viewModel = HomeViewModel()
    @Environment(AppEventBus.self) private var eventBus
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var pigBreathing = false
    @State private var dotPulsing = false
    @State private var weeklyTotals: [(date: Date, total: Int)] = []
    @State private var showWishlist = false
    @State private var showFixedExpenses = false
    @State private var showWithdraw = false
    @State private var showDebtPlan = false
    @State private var showPoolRepay = false
    @State private var showPaydayPrompt = false

    // MARK: - Computed
    private var characterState: CharacterState { viewModel.characterState }

    // MARK: - Body
    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    if !viewModel.unconfirmedVariableCosts.isEmpty {
                        unconfirmedBanner
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }

                    budgetCard
                        .padding(.horizontal, 20)

                    statusCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if let debt = viewModel.activeDebt, debt.isActive {
                        debtCard(debt)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    if let wish = viewModel.activeWish {
                        wishSavingCard(wish)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    if viewModel.carryOverMode == .separate {
                        carryOverPoolCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    chartCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    recordButton
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.fetchTodayBudget()
            loadWeeklyData()
            startAnimations()
            presentDebtPlanIfNeeded()
        }
        .onChange(of: eventBus.spendingAddedTrigger) {
            viewModel.fetchTodayBudget()
            loadWeeklyData()
        }
        .onChange(of: eventBus.budgetChangedTrigger) {
            viewModel.recalculateTodayBudget()
        }
        .onChange(of: eventBus.fixedExpenseChangedTrigger) {
            viewModel.recalculateTodayBudget()
        }
        .onChange(of: eventBus.wishChangedTrigger) {
            viewModel.fetchTodayBudget()
        }
        .sheet(isPresented: $showWishlist) {
            NavigationStack {
                WishListView(onClose: { showWishlist = false })
            }
        }
        .sheet(isPresented: $showFixedExpenses) {
            NavigationStack {
                FixedExpenseListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("닫기") { showFixedExpenses = false }.foregroundStyle(.gagaePinkDark)
                        }
                    }
            }
        }
        .sheet(isPresented: $showWithdraw) {
            CarryOverWithdrawView(poolBalance: viewModel.carryOverPoolBalance) { amount in
                viewModel.withdrawFromPool(amount: amount)
            }
        }
        .sheet(isPresented: $showDebtPlan) {
            if let debt = viewModel.activeDebt {
                DebtPlanSheet(
                    debtAmount: debt.remainingAmount,
                    dailyBudget: viewModel.baseBudget,
                    initialRate: debt.repayRatePercent,
                    repayableFromPool: viewModel.maxRepayableFromPool,
                    onConfirm: { viewModel.confirmDebtPlan(ratePercent: $0) },
                    onDefer: { viewModel.deferDebtPlan() },
                    onRepayFromPool: { viewModel.repayDebtFromPool(amount: $0) }
                )
            }
        }
        .sheet(isPresented: $showPoolRepay) {
            if let debt = viewModel.activeDebt {
                DebtPoolRepayView(poolBalance: viewModel.carryOverPoolBalance,
                                  remainingDebt: debt.remainingAmount) { amount in
                    viewModel.repayDebtFromPool(amount: amount)
                }
            }
        }
        .alert("급여일이에요 🎉", isPresented: $showPaydayPrompt) {
            Button("이월금으로 먼저 갚기") { viewModel.resolvePaydayAbsorption(usingPool: true) }
            Button("이월금은 그대로 두기") { viewModel.resolvePaydayAbsorption(usingPool: false) }
        } message: {
            Text("""
                 남은 초과분 \(FormatterUtils.currencyString(from: viewModel.activeDebt?.remainingAmount ?? 0))을 이번 달 예산으로 정산해요.
                 모아둔 이월금 \(FormatterUtils.currencyString(from: viewModel.carryOverPoolBalance))으로 먼저 갚을까요?
                 """)
        }
        .onChange(of: scenePhase) {
            // 백그라운드에서 자정을 넘긴 경우 등 다시 활성화될 때 이월 재처리
            if scenePhase == .active {
                viewModel.fetchTodayBudget()
                loadWeeklyData()
                presentDebtPlanIfNeeded()
            }
        }
    }

    /// 계획 미확정 부채가 있으면 설정 시트를, 급여일이면 이월금 사용 확인을 띄운다.
    /// 급여일 정산이 먼저다 — 정산 후에 남은 부채 기준으로 계획을 세워야 하기 때문.
    private func presentDebtPlanIfNeeded() {
        if viewModel.needsPaydayAbsorptionPrompt {
            if !showPaydayPrompt { showPaydayPrompt = true }
            return
        }
        guard viewModel.needsDebtPlanPrompt, !showDebtPlan else { return }
        showDebtPlan = true
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            pigBreathing = true
        }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            dotPulsing = true
        }
    }

    private func loadWeeklyData() {
        weeklyTotals = CoreDataManager.shared.fetchDailyTotals(days: 7)
    }
}

// MARK: - Subviews
extension HomeView {

    /// 상단 헤더: 날짜 + 가계씨 + 상태 배지
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayDateString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                Text("가계씨")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.gagaePinkDark)
            }

            Spacer()

            // 상태 배지
            HStack(spacing: 6) {
                Circle()
                    .fill(characterState.color)
                    .frame(width: 7, height: 7)
                    .scaleEffect(dotPulsing ? 1.0 : 0.85)
                Text(characterState.label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(characterState.color)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(characterState.color.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    /// 메인 예산 카드
    private var budgetCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: characterState.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .gagaeShadow(color: .gagaeBudgetCardBottom.opacity(0.34), radius: 20, y: 16)

            // 장식 버블
            GeometryReader { geo in
                Circle().fill(.white.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .offset(x: geo.size.width - 112, y: -44)
                Circle().fill(.white.opacity(0.06))
                    .frame(width: 120, height: 120)
                    .offset(x: -24, y: geo.size.height - 80)
                Circle().fill(.white.opacity(0.07))
                    .frame(width: 48, height: 48)
                    .offset(x: 22, y: 28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 5) {
                // 돼지 아바타
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 68, height: 68)
                    pigContent
                        .font(.system(size: 38))
                }
                .scaleEffect(pigBreathing ? 1.05 : 1.0)
                .padding(.bottom, 4)

                Text("오늘 쓸 수 있는 금액")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                Text(FormatterUtils.currencyString(from: viewModel.todayAvailableAmount))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(characterState.message)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.16))
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
            .padding(24)
        }
        .frame(height: 260)
    }

    @ViewBuilder
    private var pigContent: some View {
        if UIImage(named: "characterPig") != nil {
            Image("characterPig")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
        } else {
            Text(characterState.emoji)
        }
    }

    /// 예산 현황 카드
    private var statusCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("오늘의 예산 현황")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            statusRow(emoji: "🔵", label: "이월 금액",
                      value: FormatterUtils.currencyString(from: viewModel.displayCarryOverAmount),
                      valueColor: .gagaeText, bold: false)
            divider
            statusRow(emoji: "🔴", label: "오늘 기본 예산",
                      value: FormatterUtils.currencyString(from: viewModel.baseBudget),
                      valueColor: .gagaeText, bold: false)
            if viewModel.todayDebtRepayment > 0 {
                divider
                statusRow(emoji: "💪", label: "초과분 상환",
                          value: "-" + FormatterUtils.currencyString(from: viewModel.todayDebtRepayment),
                          valueColor: .gagaePinkDark, bold: false)
            }
            if viewModel.transferAmount > 0 {
                divider
                statusRow(emoji: "📈", label: "저축·투자",
                          value: "-" + FormatterUtils.currencyString(from: viewModel.transferAmount),
                          valueColor: .gagaeGood, bold: false)
            }
            divider
            statusRow(emoji: "🛒", label: "오늘 소비",
                      value: "-" + FormatterUtils.currencyString(from: viewModel.spentAmount),
                      valueColor: .gagaeDanger, bold: false)
            divider
            statusRow(emoji: viewModel.todayAvailableAmount < 0 ? "⚠️" : "✅", label: "잔여 예산",
                      value: FormatterUtils.currencyString(from: viewModel.todayAvailableAmount),
                      valueColor: characterState.color, bold: true)

            Color.clear.frame(height: 4)
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func statusRow(emoji: String, label: String, value: String, valueColor: Color, bold: Bool) -> some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 17))
                .frame(width: 24, alignment: .center)
            Text(label)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.gagaeText)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: bold ? .bold : .regular, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gagaeDivider)
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    /// 모아둔 이월금 카드 (분리 모드)
    private var carryOverPoolCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.gagaePinkLight).frame(width: 40, height: 40)
                Text("🐷").font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("모아둔 이월금")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                Text(FormatterUtils.currencyString(from: viewModel.carryOverPoolBalance))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.gagaeText)
                if viewModel.todayPoolWithdrawn > 0 {
                    Text("오늘 \(FormatterUtils.currencyString(from: viewModel.todayPoolWithdrawn)) 가져옴")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                }
            }
            Spacer()
            Button {
                showWithdraw = true
            } label: {
                Text("꺼내 쓰기")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.carryOverPoolBalance > 0 ? .white : .gagaeTextTertiary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(viewModel.carryOverPoolBalance > 0 ? AnyShapeStyle(Color.gagaePinkDark) : AnyShapeStyle(Color.gagaeSurface))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.carryOverPoolBalance <= 0)
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    /// 초과분 상환 진행 카드
    private func debtCard(_ debt: SpendingDebtModel) -> some View {
        let plan = DebtRepaymentPlan.calculate(debt: debt.remainingAmount,
                                               dailyBudget: viewModel.baseBudget,
                                               ratePercent: debt.repayRatePercent)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("💪 초과분 갚는 중")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if debt.isPlanned && plan.days > 0 {
                    Text("앞으로 \(plan.days)일")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Color.gagaePinkDark).clipShape(Capsule())
                }
            }

            // "이 돈이 어디서 왔지?" → 초과한 날과 그날 소비로 바로 이동
            NavigationLink {
                OverspendHistoryView(remainingDebt: debt.remainingAmount)
            } label: {
                HStack(spacing: 4) {
                    Text("언제 초과했는지 보기")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.gagaePinkDark)
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gagaeDivider.opacity(0.5)).frame(height: 9)
                    Capsule().fill(LinearGradient(colors: [.gagaePinkDark, .gagaePink],
                                                  startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * debt.progress), height: 9)
                }
            }
            .frame(height: 9)

            HStack {
                Text("\(FormatterUtils.currencyString(from: debt.remainingAmount)) / \(FormatterUtils.currencyString(from: debt.originalAmount))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                Spacer()
                if debt.isPlanned {
                    Text("하루 −\(FormatterUtils.currencyString(from: plan.perDay)) (\(debt.repayRatePercent)%)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                } else {
                    Button {
                        showDebtPlan = true
                    } label: {
                        Text("상환 계획 세우기")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.gagaePinkDark).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // 최근 씀씀이로는 부채가 줄지 않는 경우 — 숫자만 보여주면 사용자가 알 수 없다
            if viewModel.isDebtOffTrack {
                HStack(alignment: .top, spacing: 6) {
                    Text("⚠️").font(.system(size: 12))
                    Text("이 속도면 초과분이 줄지 않아요. 하루 \(FormatterUtils.currencyString(from: viewModel.debtDailyCutNeeded))씩 더 줄여보세요.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeWarning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }

            if viewModel.todayPoolRepayment > 0 {
                Text("오늘 모아둔 이월금 \(FormatterUtils.currencyString(from: viewModel.todayPoolRepayment))으로 갚았어요")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gagaePinkDark)
            }

            // 모아둔 이월금이 있으면 그 돈으로 초과분을 갚을 수 있게 한다
            if viewModel.canRepayDebtFromPool {
                Button {
                    showPoolRepay = true
                } label: {
                    HStack(spacing: 6) {
                        Text("🐷").font(.system(size: 13))
                        Text("모아둔 이월금 \(FormatterUtils.currencyString(from: viewModel.maxRepayableFromPool))으로 갚기")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.gagaePinkDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.gagaePinkLight)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    /// 변동 고정비 미확정 프롬프트 배너
    private var unconfirmedBanner: some View {
        Button {
            showFixedExpenses = true
        } label: {
            HStack(spacing: 10) {
                Text("💳").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("이번 달 미확정 변동 고정비 \(viewModel.unconfirmedVariableCosts.count)건")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeText)
                    Text(viewModel.unconfirmedVariableCosts.map { $0.title }.joined(separator: ", "))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("입력")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.gagaePinkDark).clipShape(Capsule())
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.gagaePinkLight)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    /// 위시리스트 저금 카드 (활성 저금이 있을 때)
    private func wishSavingCard(_ wish: WishItemModel) -> some View {
        Button {
            showWishlist = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(wish.kind.emoji) \(wish.title)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeText)
                    Spacer()
                    if let d = wish.daysLeft {
                        Text(d == 0 ? "구매 가능" : "D-\(d)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Color.gagaePinkDark).clipShape(Capsule())
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gagaeDivider.opacity(0.5)).frame(height: 9)
                        Capsule().fill(LinearGradient(colors: [.gagaePinkDark, .gagaePink],
                                                      startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * wish.progress), height: 9)
                    }
                }
                .frame(height: 9)
                HStack {
                    Text("\(FormatterUtils.currencyString(from: wish.savedAmount)) / \(FormatterUtils.currencyString(from: wish.targetAmount))")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text("오늘 −\(FormatterUtils.currencyString(from: wish.dailySaving)) 저금 중")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                }
            }
            .padding(16)
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gagaeCardShadow()
        }
        .buttonStyle(.plain)
    }

    /// 최근 7일 차트 카드
    private var chartCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("최근 7일 소비 흐름")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                let weekTotal = weeklyTotals.reduce(0) { $0 + $1.total }
                if weekTotal > 0 {
                    Text("합계 " + FormatterUtils.currencyString(from: weekTotal))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                }
            }
            .padding(.bottom, 18)

            weeklyBarChart
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private var weeklyBarChart: some View {
        let maxV = max(weeklyTotals.map { $0.total }.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 7) {
            ForEach(weeklyTotals, id: \.date) { item in
                let isToday = Calendar.current.isDateInToday(item.date)
                let barH = max(8, CGFloat(item.total) / CGFloat(maxV) * 62)
                VStack(spacing: 7) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? Color.gagaePinkDark : Color.gagaePink)
                        .frame(height: barH)
                        .gagaeShadow(color: isToday ? .gagaePinkDark.opacity(0.35) : .clear, radius: 5, y: 3)
                    Text(weekdayLabel(item.date))
                        .font(.system(size: 11, weight: isToday ? .heavy : .medium, design: .rounded))
                        .foregroundStyle(isToday ? Color.gagaePinkDark : Color.gagaeTextTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 82)
    }

    /// 소비 기록 버튼 (기록 탭으로 전환)
    private var recordButton: some View {
        Button {
            appState.selectedTab = 1
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.65), lineWidth: 2.2)
                        .frame(width: 26, height: 26)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("소비 기록하기")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [.gagaePinkDark, .gagaePink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .gagaeShadow(color: .gagaePinkDark.opacity(0.38), radius: 14, y: 10)
        }
    }
}

// MARK: - Helpers
extension HomeView {
    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: Date())
    }

    private func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEEE"  // 월 화 수...
        return f.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppEventBus())
    .environment(AppState())
}
