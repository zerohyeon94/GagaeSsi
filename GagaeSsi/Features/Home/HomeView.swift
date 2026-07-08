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

    // MARK: - Computed
    private var budgetStatus: BudgetStatus {
        BudgetStatus.from(available: viewModel.todayAvailableAmount, base: viewModel.baseBudget)
    }

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

                    budgetCard
                        .padding(.horizontal, 20)

                    statusCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

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
        .onChange(of: scenePhase) {
            // 백그라운드에서 자정을 넘긴 경우 등 다시 활성화될 때 이월 재처리
            if scenePhase == .active {
                viewModel.fetchTodayBudget()
                loadWeeklyData()
            }
        }
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
                    .fill(budgetStatus.color)
                    .frame(width: 7, height: 7)
                    .scaleEffect(dotPulsing ? 1.0 : 0.85)
                Text(statusBadgeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(budgetStatus.color)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(budgetStatus.color.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    /// 메인 예산 카드
    private var budgetCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: cardGradientColors,
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

                Text(budgetStatus.message)
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
            Text(budgetStatus.pigMood)
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
                      value: FormatterUtils.currencyString(from: viewModel.carryOverAmount),
                      valueColor: .gagaeText, bold: false)
            divider
            statusRow(emoji: "🔴", label: "오늘 기본 예산",
                      value: FormatterUtils.currencyString(from: viewModel.baseBudget),
                      valueColor: .gagaeText, bold: false)
            divider
            statusRow(emoji: "🛒", label: "오늘 소비",
                      value: "-" + FormatterUtils.currencyString(from: viewModel.spentAmount),
                      valueColor: .gagaeDanger, bold: false)
            divider
            statusRow(emoji: "✅", label: "잔여 예산",
                      value: FormatterUtils.currencyString(from: viewModel.todayAvailableAmount),
                      valueColor: budgetStatus.color, bold: true)

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
    private var cardGradientColors: [Color] {
        switch budgetStatus {
        case .good:
            return [.gagaeBudgetCardTop, .gagaeBudgetCardBottom]
        case .warning:
            return [Color(hex: "#FFA94D"), Color(hex: "#FB8B1A")]
        case .critical, .empty:
            return [Color(hex: "#F26666"), Color(hex: "#E13F47")]
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: Date())
    }

    private var statusBadgeText: String {
        switch budgetStatus {
        case .good: return "여유"
        case .warning: return "주의"
        case .critical: return "위험"
        case .empty: return "소진"
        }
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
