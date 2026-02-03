//
//  HomeView.swift
//  GagaeSsi
//
//  홈 화면 (HomeViewController 대체)
//

import SwiftUI

struct HomeView: View {
    // MARK: - Properties
    @State private var viewModel = HomeViewModel()
    @Environment(AppEventBus.self) private var eventBus
    @State private var showRecordSpend = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 오늘 사용 가능 금액
            availableAmountSection
                .padding(.top, 32)
            
            // 계산 정보 라벨
            calculationInfoText
                .padding(.top, 8)
            
            // 최근 7일 요약 카드
            recentSummaryCard
                .padding(.top, 32)
                .padding(.horizontal, 20)
            
            Spacer()
            
            // 소비 기록 버튼
            recordButton
                .padding(.bottom, 32)
        }
        .navigationTitle("오늘 얼마?")
        .onAppear {
            viewModel.fetchTodayBudget()
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
}

// MARK: - Subviews
extension HomeView {
    /// 오늘 사용 가능 금액 (AttributedString 스타일링)
    private var availableAmountSection: some View {
        Text(availableAmountAttributedString)
    }
    
    private var availableAmountAttributedString: AttributedString {
        let title = "오늘 사용할 수 있는 금액: "
        let value = FormatterUtils.currencyString(from: viewModel.todayAvailableAmount)
        
        var titleAttr = AttributedString(title)
        titleAttr.font = .system(size: 20, weight: .regular)
        titleAttr.foregroundColor = .primary
        
        var valueAttr = AttributedString(value)
        valueAttr.font = .system(size: 28, weight: .bold)
        
        // 금액에 따른 색상 변경
        if viewModel.todayAvailableAmount < 0 {
            valueAttr.foregroundColor = .red
        } else if viewModel.todayAvailableAmount < viewModel.baseBudget / 2 {
            valueAttr.foregroundColor = .orange
        } else {
            valueAttr.foregroundColor = .blue
        }
        
        return titleAttr + valueAttr
    }
    
    /// 계산 정보 라벨
    private var calculationInfoText: some View {
        let carry = FormatterUtils.currencyString(from: viewModel.carryOverAmount)
        let base = FormatterUtils.currencyString(from: viewModel.baseBudget)
        let spent = FormatterUtils.currencyString(from: viewModel.spentAmount)
        
        return Text("(이월 \(carry) + 오늘 예산 \(base) - 소비 \(spent))")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    
    /// 최근 7일 요약 카드
    private var recentSummaryCard: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .frame(height: 120)
            .overlay {
                Text(recentSummaryAttributedString)
            }
    }
    
    /// AttributedString 부분 스타일링 예시
    private var recentSummaryAttributedString: AttributedString {
        var text = AttributedString("최근 7일 소비 요약")
        text.font = .system(size: 16, weight: .regular)
        text.foregroundColor = .primary
        
        // "7일" 부분만 다른 스타일 적용
        if let range = text.range(of: "7일") {
            text[range].font = .system(size: 18, weight: .bold)
            text[range].foregroundColor = .blue
        }
        
        return text
    }
    
    /// 소비 기록 버튼
    private var recordButton: some View {
        NavigationLink {
            SpendView()
        } label: {
            Text("소비 기록하기")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 200, height: 50)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
