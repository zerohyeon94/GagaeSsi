//
//  StatsView.swift
//  GagaeSsi
//
//  통계 화면 (Claude Design 적용)
//

import SwiftUI
import Charts

struct StatsView: View {
    @State private var viewModel = StatsViewModel()

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: 14) {
                    largeTitle
                    monthNavigator

                    if viewModel.monthlyTotal == 0 && viewModel.categoryTotals.isEmpty {
                        emptyStateCard
                    } else {
                        monthlySummaryCard
                        if viewModel.transferSummary.total > 0 { transferCard }
                        categoryCard
                        dailyChartCard
                        timeSlotCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.load() }
    }
}

// MARK: - Header
extension StatsView {
    private var largeTitle: some View {
        HStack {
            Text("통계")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.gagaeText)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var monthNavigator: some View {
        HStack {
            navButton(systemName: "chevron.left", enabled: !viewModel.isFirstMonth) {
                viewModel.goToPrevMonth()
            }
            Spacer()
            Text(viewModel.currentMonthLabel)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeText)
            Spacer()
            navButton(systemName: "chevron.right", enabled: viewModel.canGoToNextMonth) {
                viewModel.goToNextMonth()
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(enabled ? Color.gagaePinkLight : Color.gagaeSurfaceAlt)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(enabled ? Color.gagaePinkDark : Color.gagaeTextTertiary)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Cards
extension StatsView {

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Text("🐷").font(.system(size: 40))
            Text("이번 달 기록이 없어요")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeText)
            Text("소비를 기록하면 통계가 나타나요!")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    /// 월별 요약 카드
    private var monthlySummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("이번 달 요약")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeText)
                .padding(.bottom, 16)

            HStack(spacing: 0) {
                summaryItem(label: "총 지출",
                            value: FormatterUtils.currencyString(from: viewModel.monthlyTotal),
                            color: .gagaeDanger, showDivider: true)
                summaryItem(label: "일 평균",
                            value: FormatterUtils.currencyString(from: viewModel.dailyAverage),
                            color: .gagaePinkDark, showDivider: true)
                summaryItem(label: "전월 대비",
                            value: diffText, color: diffColor, showDivider: false)
            }
            .padding(.bottom, 18)

            // 환급 예정이 있으면 순 지출 보조 표시
            if viewModel.expectedPaybackTotal > 0 {
                HStack(spacing: 8) {
                    Text("순 지출 \(FormatterUtils.currencyString(from: viewModel.netSpendingTotal))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeGood)
                    Text("· 환급 예정 \(FormatterUtils.currencyString(from: viewModel.expectedPaybackTotal))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                    Spacer()
                }
                .padding(.bottom, 14)
            }

            if let state = viewModel.dominantState {
                HStack(spacing: 8) {
                    Text("이번 달 가게씨")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.gagaeTextSecondary)
                    Text("\(state.emoji) \(state.label)")
                        .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(state.color)
                    Spacer()
                }
                .padding(.bottom, 14)
            }

            Rectangle().fill(Color.gagaeDivider).frame(height: 0.5)
                .padding(.bottom, 16)

            progressBar
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func summaryItem(label: String, value: String, color: Color, showDivider: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            if showDivider {
                Rectangle().fill(Color.gagaeDivider).frame(width: 1, height: 28)
            }
        }
    }

    private var diffText: String {
        let d = viewModel.diffAmount
        if viewModel.prevMonthTotal == 0 { return "-" }
        let sign = d > 0 ? "+" : (d < 0 ? "-" : "")
        return sign + FormatterUtils.currencyString(from: abs(d))
    }

    private var diffColor: Color {
        let d = viewModel.diffAmount
        if d > 0 { return .gagaeDanger }
        if d < 0 { return .gagaeGood }
        return .gagaeText
    }

    /// 예산 사용률 바
    private var progressBar: some View {
        let pct = viewModel.budgetUsagePct
        let color: Color = pct >= 90 ? .gagaeDanger : (pct >= 70 ? .gagaeWarning : .gagaeGood)
        return VStack(spacing: 8) {
            HStack {
                Text("예산 사용률")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gagaeDivider).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: pct >= 90 ? [.gagaeWarning, .gagaeDanger]
                                  : pct >= 70 ? [Color(hex: "#FFD166"), .gagaeWarning]
                                  : [.gagaePink, .gagaeGood],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(1, Double(pct) / 100), height: 8)
                        .animation(.spring(duration: 0.7), value: pct)
                }
            }
            .frame(height: 8)
        }
    }

    /// 이번 달 저축·투자 카드 — 소비가 아니라 '이동'이라 위 소비 합계와 별개다
    private var transferCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("이번 달 모은 돈")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                Text(FormatterUtils.currencyString(from: viewModel.transferSummary.total))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.gagaeGood)
            }

            HStack(spacing: 0) {
                ForEach(AssetTransferKind.allCases) { kind in
                    VStack(spacing: 3) {
                        Text(FormatterUtils.currencyString(from: viewModel.transferSummary.total(of: kind)))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(kind.color)
                        Text("\(kind.emoji) \(kind.label)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("저축·투자는 쓴 돈이 아니라 옮긴 돈이라 위 소비 통계에는 포함되지 않아요.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.gagaeTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    /// 카테고리별 지출 카드
    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("카테고리별 지출")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if !viewModel.categoryTotals.isEmpty {
                    Text("눌러서 자세히")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
            }

            if viewModel.categoryTotals.isEmpty {
                Text("기록이 없어요")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                donutChart
                    .frame(maxWidth: .infinity)
                categoryRows
            }
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    /// 카테고리 행 — 금액까지 보여주고, 누르면 그 카테고리의 지출 목록으로
    private var categoryRows: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.categoryTotals) { item in
                NavigationLink {
                    CategoryDetailView(category: item.category,
                                       month: viewModel.selectedMonth,
                                       monthlyTotal: viewModel.monthlyTotal)
                } label: {
                    HStack(spacing: 9) {
                        Circle().fill(item.category.color).frame(width: 9, height: 9)
                        Text("\(item.category.emoji) \(item.category.rawValue)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.gagaeText)
                        Spacer()
                        Text(FormatterUtils.currencyString(from: item.amount))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.gagaeText)
                        Text("\(Int((item.percentage * 100).rounded()))%")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.gagaeTextTertiary)
                            .frame(width: 38, alignment: .trailing)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.id != viewModel.categoryTotals.last?.id {
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 18)
                }
            }
        }
    }

    private var donutChart: some View {
        ZStack {
            Chart(viewModel.categoryTotals) { item in
                SectorMark(
                    angle: .value("금액", item.amount),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(item.category.color)
            }
            .frame(width: 130, height: 130)

            VStack(spacing: 1) {
                Text("₩\(String(format: "%.1f", Double(viewModel.monthlyTotal) / 10000))")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Text("만원")
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
            }
        }
    }

    /// 일별 소비 카드
    private var dailyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("일별 소비")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if viewModel.baseDailyBudget > 0 {
                    HStack(spacing: 5) {
                        DashLine().stroke(Color.gagaeTextTertiary,
                                          style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                            .frame(width: 18, height: 1)
                        Text("일일 예산")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                }
            }

            if viewModel.dailyTotals.allSatisfy({ $0.amount == 0 }) {
                Text("기록이 없어요")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                dailyChart

                // 예산 초과 pill
                if viewModel.baseDailyBudget > 0 {
                    if viewModel.overBudgetDays > 0 {
                        HStack(spacing: 6) {
                            Text("예산 초과 \(viewModel.overBudgetDays)일")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.gagaeDanger)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.gagaeDanger.opacity(0.10))
                                .clipShape(Capsule())
                            Text("이 있어요")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                    } else {
                        Text("모두 예산 안에서 🎉")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.gagaeGood)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gagaeGood.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    // MARK: - 시간대별 소비
    private var timeSlotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("시간대별 소비")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if let peak = viewModel.peakTimeSlot {
                    Text("주로 \(peak.label) \(peak.emoji)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gagaePinkLight)
                        .clipShape(Capsule())
                }
            }

            if viewModel.timedRecordCount == 0 {
                Text("아직 시간대 데이터가 쌓이지 않았어요")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.timeSlotTotals) { item in
                        timeSlotRow(item, isPeak: item.slot == viewModel.peakTimeSlot)
                    }
                }
                Text("시간 정보가 있는 \(viewModel.timedRecordCount)건 기준")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
            }
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func timeSlotRow(_ item: TimeSlotTotal, isPeak: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(item.slot.emoji) \(item.slot.label)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.gagaeText)
                .frame(width: 62, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gagaeDivider.opacity(0.5))
                        .frame(height: 8)
                    Capsule()
                        .fill(isPeak ? Color.gagaePinkDark : Color.gagaePink.opacity(0.55))
                        .frame(width: max(0, geo.size.width * item.percentage), height: 8)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 8)

            Text(FormatterUtils.currencyString(from: item.amount))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
                .frame(width: 82, alignment: .trailing)
        }
    }

    private var dailyChart: some View {
        // 막대 높이는 소비 렌즈(myShare)지만, 그날이 예산을 넘겼는지 색으로 알려주는 판정은
        // 예산 렌즈(dailyBudgetTotals)로 봐야 한다 — 친구 몫까지 낸 날은 막대는 낮아도
        // 실제로는 예산을 넘겼을 수 있다.
        let budgetByDate = Dictionary(uniqueKeysWithValues:
            viewModel.dailyBudgetTotals.map { (Calendar.current.startOfDay(for: $0.date), $0.amount) })
        return Chart {
            ForEach(viewModel.dailyTotals) { item in
                let dayBudgetAmount = budgetByDate[Calendar.current.startOfDay(for: item.date)] ?? item.amount
                BarMark(
                    x: .value("날짜", item.date, unit: .day),
                    y: .value("금액", item.amount)
                )
                .foregroundStyle(
                    dayBudgetAmount > viewModel.baseDailyBudget && viewModel.baseDailyBudget > 0
                        ? Color.gagaeDanger : Color.gagaePinkDark
                )
                .cornerRadius(2)
            }
            if viewModel.baseDailyBudget > 0 {
                RuleMark(y: .value("예산", viewModel.baseDailyBudget))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                    .foregroundStyle(Color.gagaeTextTertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
                    .font(.system(size: 8, design: .rounded))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text(FormatterUtils.shortCurrencyString(from: intVal))
                            .font(.system(size: 8, design: .rounded))
                    }
                }
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Dashed Line Shape
private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StatsView()
    }
}
