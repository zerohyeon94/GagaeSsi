//
//  HomeView.swift
//  GagaeSsi
//
//  홈 화면 - 오늘의 예산 현황
//

import SwiftUI

struct HomeView: View {
    // MARK: - Properties
    @State private var viewModel = HomeViewModel()
    @Environment(AppEventBus.self) private var eventBus
    @State private var showRecordSpend = false
    @State private var pigAnimating = false

    // MARK: - Computed
    private var budgetStatus: BudgetStatus {
        BudgetStatus.from(available: viewModel.todayAvailableAmount, base: viewModel.baseBudget)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // 배경
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    // 헤더 (날짜 + 인사)
                    headerSection
                        .padding(.top, GagaeSpacing.md)

                    // 돼지 캐릭터 + 메인 금액 카드
                    mainBudgetCard

                    // 예산 상세 분석 카드
                    budgetBreakdownCard

                    // 최근 7일 요약 카드
                    recentSummaryCard

                    // 소비 기록 버튼
                    recordSpendButton
                        .padding(.bottom, GagaeSpacing.xl)
                }
                .padding(.horizontal, GagaeSpacing.md)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            viewModel.fetchTodayBudget()
            startPigAnimation()
        }
        .onChange(of: eventBus.spendingAddedTrigger) {
            viewModel.fetchTodayBudget()
        }
        .onChange(of: eventBus.budgetChangedTrigger) {
            viewModel.recalculateTodayBudget()
        }
        .onChange(of: eventBus.fixedExpenseChangedTrigger) {
            viewModel.recalculateTodayBudget()
        }
    }

    private func startPigAnimation() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pigAnimating = true
        }
    }
}

// MARK: - Subviews
extension HomeView {

    /// 상단 헤더: 날짜 + 가게씨 로고
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayDateString)
                    .font(.gagaeCaption)
                    .foregroundStyle(.gagaeTextSecondary)

                Text("가계씨")
                    .font(.gagaeTitle2)
                    .foregroundStyle(.gagaePinkDark)
            }

            Spacer()

            // 상태 배지
            HStack(spacing: GagaeSpacing.xs) {
                Circle()
                    .fill(budgetStatus.color)
                    .frame(width: 8, height: 8)
                Text(statusBadgeText)
                    .font(.gagaeCaptionMedium)
                    .foregroundStyle(budgetStatus.color)
            }
            .padding(.horizontal, GagaeSpacing.sm)
            .padding(.vertical, GagaeSpacing.xs)
            .background(budgetStatus.color.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    /// 메인 예산 카드: 돼지 + 금액
    private var mainBudgetCard: some View {
        ZStack {
            // 카드 배경
            RoundedRectangle(cornerRadius: GagaeRadius.xxl)
                .fill(
                    LinearGradient(
                        colors: cardGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .gagaeCardShadow()

            // 장식 원들
            GeometryReader { geo in
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .offset(x: geo.size.width - 60, y: -40)

                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 80, height: 80)
                    .offset(x: -20, y: geo.size.height - 30)
            }

            VStack(spacing: GagaeSpacing.md) {
                // 돼지 캐릭터 이미지 또는 이모지
                pigCharacterView

                // 금액
                VStack(spacing: GagaeSpacing.xs) {
                    Text("오늘 쓸 수 있는 금액")
                        .font(.gagaeSubheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(FormatterUtils.currencyString(from: viewModel.todayAvailableAmount))
                        .font(.gagaeAmountLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(budgetStatus.message)
                        .font(.gagaeCaption)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, GagaeSpacing.md)
                        .padding(.vertical, GagaeSpacing.xs)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(GagaeSpacing.xl)
        }
        .frame(height: 260)
    }

    /// 돼지 캐릭터 뷰
    private var pigCharacterView: some View {
        ZStack {
            // 광채 효과
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 90, height: 90)
                .scaleEffect(pigAnimating ? 1.1 : 1.0)

            // 돼지 이미지 (있으면 사용, 없으면 이모지)
            if UIImage(named: "characterPig") != nil {
                Image("characterPig")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .scaleEffect(pigAnimating ? 1.05 : 1.0)
            } else {
                Text(budgetStatus.pigMood)
                    .font(.system(size: 56))
                    .scaleEffect(pigAnimating ? 1.08 : 1.0)
            }
        }
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pigAnimating)
    }

    /// 예산 분석 카드
    private var budgetBreakdownCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.sm) {
                // 헤더
                HStack {
                    Text("오늘의 예산 현황")
                        .font(.gagaeHeadline)
                        .foregroundStyle(.gagaeText)
                    Spacer()
                }
                .padding(.bottom, GagaeSpacing.xs)

                GagaeDivider()

                // 이월 금액
                budgetRow(
                    icon: "arrow.uturn.right.circle.fill",
                    iconColor: .blue,
                    label: "이월 금액",
                    amount: viewModel.carryOverAmount,
                    amountColor: .gagaeText
                )

                GagaeDivider()

                // 오늘 예산
                budgetRow(
                    icon: "calendar.circle.fill",
                    iconColor: .gagaePinkDark,
                    label: "오늘 기본 예산",
                    amount: viewModel.baseBudget,
                    amountColor: .gagaeText
                )

                GagaeDivider()

                // 오늘 소비
                budgetRow(
                    icon: "cart.circle.fill",
                    iconColor: .gagaeDanger,
                    label: "오늘 소비",
                    amount: viewModel.spentAmount,
                    amountColor: .gagaeDanger
                )

                GagaeDivider()

                // 잔여
                HStack {
                    HStack(spacing: GagaeSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(budgetStatus.color)

                        Text("잔여 예산")
                            .font(.gagaeBodyMedium)
                            .foregroundStyle(.gagaeText)
                    }

                    Spacer()

                    Text(FormatterUtils.currencyString(from: viewModel.todayAvailableAmount))
                        .font(.gagaeAmountSmall)
                        .foregroundStyle(budgetStatus.color)
                }
            }
        }
    }

    private func budgetRow(icon: String, iconColor: Color, label: String, amount: Int, amountColor: Color) -> some View {
        HStack {
            HStack(spacing: GagaeSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)

                Text(label)
                    .font(.gagaeCallout)
                    .foregroundStyle(.gagaeTextSecondary)
            }

            Spacer()

            Text(FormatterUtils.currencyString(from: amount))
                .font(.gagaeCalloutMedium)
                .foregroundStyle(amountColor)
        }
    }

    /// 예산 프로그레스 바
    private var budgetProgressBar: some View {
        let progress = viewModel.baseBudget > 0
            ? max(0, min(1, Double(viewModel.todayAvailableAmount) / Double(viewModel.baseBudget)))
            : 0

        return VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: GagaeRadius.full)
                        .fill(Color.gagaeDivider)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: GagaeRadius.full)
                        .fill(
                            LinearGradient(
                                colors: [budgetStatus.color, budgetStatus.color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(duration: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    /// 최근 7일 요약 카드 (placeholder)
    private var recentSummaryCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.md) {
                HStack {
                    Text("📊 최근 7일 소비 흐름")
                        .font(.gagaeHeadline)
                        .foregroundStyle(.gagaeText)
                    Spacer()
                    Text("곧 공개")
                        .font(.gagaeCaptionMedium)
                        .foregroundStyle(.gagaePinkDark)
                        .padding(.horizontal, GagaeSpacing.sm)
                        .padding(.vertical, GagaeSpacing.xs)
                        .background(.gagaePinkLight)
                        .clipShape(Capsule())
                }

                // 미니 차트 플레이스홀더
                HStack(alignment: .bottom, spacing: GagaeSpacing.sm) {
                    ForEach(mockChartData, id: \.0) { item in
                        VStack(spacing: GagaeSpacing.xs) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.1 ? Color.gagaePinkDark : Color.gagaePink.opacity(0.4))
                                .frame(width: 28, height: item.2)

                            Text(item.0)
                                .font(.gagaeCaption)
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // 임시 차트 데이터: (요일, isToday, 높이)
    private var mockChartData: [(String, Bool, CGFloat)] {
        let days = ["월", "화", "수", "목", "금", "토", "일"]
        let heights: [CGFloat] = [40, 65, 30, 55, 48, 70, 45]
        let today = Calendar.current.component(.weekday, from: Date())
        let todayIndex = (today - 2 + 7) % 7

        return days.enumerated().map { index, day in
            (day, index == todayIndex, heights[index])
        }
    }

    /// 소비 기록 FAB 버튼
    private var recordSpendButton: some View {
        NavigationLink {
            SpendView()
        } label: {
            HStack(spacing: GagaeSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("소비 기록하기")
                    .font(.gagaeHeadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [.gagaePinkDark, .gagaePink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.full))
            .gagaeShadow(color: .gagaePink.opacity(0.4), radius: 12, y: 6)
        }
    }
}

// MARK: - Helpers
extension HomeView {
    private var cardGradientColors: [Color] {
        switch budgetStatus {
        case .good:
            return [Color(red: 0.98, green: 0.50, blue: 0.65), Color(red: 0.95, green: 0.40, blue: 0.60)]
        case .warning:
            return [Color(red: 1.0, green: 0.68, blue: 0.30), Color(red: 0.98, green: 0.55, blue: 0.20)]
        case .critical:
            return [Color(red: 0.95, green: 0.40, blue: 0.40), Color(red: 0.88, green: 0.25, blue: 0.30)]
        case .empty:
            return [Color(red: 0.6, green: 0.6, blue: 0.65), Color(red: 0.5, green: 0.5, blue: 0.55)]
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
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppEventBus())
}
