//
//  SpendView.swift
//  GagaeSsi
//
//  소비 기록 화면
//

import SwiftUI

struct SpendView: View {
    // MARK: - Properties
    @State private var viewModel = SpendViewModel()
    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field {
        case title, amount
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    // 입력 카드
                    inputCard
                        .padding(.top, GagaeSpacing.sm)

                    // 저장 버튼
                    GagaePrimaryButton(
                        title: "저장하기",
                        isEnabled: viewModel.isValid
                    ) {
                        focusedField = nil
                        viewModel.saveSpending(eventBus: eventBus) { success in
                            if success {
                                let today = Calendar.current.startOfDay(for: Date())
                                viewModel.fetchSpending(on: today)
                            }
                        }
                    }

                    // 오늘 지출 목록
                    spendingListSection
                        .padding(.bottom, GagaeSpacing.xl)
                }
                .padding(.horizontal, GagaeSpacing.md)
            }
        }
        .navigationTitle("소비 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .onAppear {
            let today = Calendar.current.startOfDay(for: Date())
            viewModel.fetchSpending(on: today)
        }
        .alert("저장 완료", isPresented: $viewModel.showSuccessAlert) {
            Button("확인") {
                viewModel.clearForm()
            }
        } message: {
            Text("지출 내역이 저장되었습니다 🐷")
        }
        .alert("오류", isPresented: $viewModel.showErrorAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

// MARK: - Subviews
extension SpendView {

    /// 입력 카드
    private var inputCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.md) {
                // 카드 헤더
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.gagaePinkDark)
                    Text("오늘 쓴 거 기록해요")
                        .font(.gagaeHeadline)
                        .foregroundStyle(.gagaeText)
                    Spacer()
                }

                GagaeDivider()

                // 내용 입력
                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Label("내용", systemImage: "tag.fill")
                        .font(.gagaeFootnote)
                        .foregroundStyle(.gagaeTextSecondary)

                    TextField("예: 점심 식사, 카페라떼", text: $viewModel.tempTitle)
                        .font(.gagaeBody)
                        .focused($focusedField, equals: .title)
                        .padding(.horizontal, GagaeSpacing.md)
                        .padding(.vertical, GagaeSpacing.md)
                        .background(Color.gagaeSurface)
                        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: GagaeRadius.md)
                                .stroke(
                                    focusedField == .title ? Color.gagaePinkDark : Color.gagaeDivider,
                                    lineWidth: focusedField == .title ? 2 : 0.5
                                )
                        )
                }

                // 금액 입력
                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Label("금액", systemImage: "wonsign.circle.fill")
                        .font(.gagaeFootnote)
                        .foregroundStyle(.gagaeTextSecondary)

                    HStack(spacing: GagaeSpacing.sm) {
                        Text("₩")
                            .font(.gagaeTitle3)
                            .foregroundStyle(.gagaePinkDark)

                        TextField("0", text: $viewModel.tempAmountText)
                            .font(.gagaeTitle3)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: viewModel.tempAmountText) { _, newValue in
                                viewModel.updateAmountFromText(newValue)
                            }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.vertical, GagaeSpacing.md)
                    .background(Color.gagaeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: GagaeRadius.md)
                            .stroke(
                                focusedField == .amount ? Color.gagaePinkDark : Color.gagaeDivider,
                                lineWidth: focusedField == .amount ? 2 : 0.5
                            )
                    )
                }

                // 날짜 선택
                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Label("날짜", systemImage: "calendar.circle.fill")
                        .font(.gagaeFootnote)
                        .foregroundStyle(.gagaeTextSecondary)

                    HStack {
                        DatePicker(
                            "",
                            selection: $viewModel.tempDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accentColor(.gagaePinkDark)

                        Spacer()
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.vertical, GagaeSpacing.sm)
                    .background(Color.gagaeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: GagaeRadius.md)
                            .stroke(Color.gagaeDivider, lineWidth: 0.5)
                    )
                }
            }
        }
    }

    /// 오늘 지출 목록 섹션
    private var spendingListSection: some View {
        VStack(spacing: GagaeSpacing.sm) {
            // 섹션 헤더
            HStack {
                Text("오늘 지출 목록")
                    .font(.gagaeHeadline)
                    .foregroundStyle(.gagaeText)

                Spacer()

                if !viewModel.spendingRecords.isEmpty {
                    Text("총 \(FormatterUtils.currencyString(from: viewModel.totalSpentToday))")
                        .font(.gagaeCalloutMedium)
                        .foregroundStyle(.gagaeDanger)
                }
            }

            if viewModel.spendingRecords.isEmpty {
                // 빈 상태
                GagaeCard {
                    GagaeEmptyStateView(
                        icon: "🐷",
                        title: "아직 기록이 없어요",
                        subtitle: "위에서 오늘 쓴 금액을 기록해보세요!"
                    )
                }
            } else {
                // 지출 목록
                GagaeCard(padding: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.spendingRecords.enumerated()), id: \.element.id) { index, record in
                            spendingRow(record: record, isFirst: index == 0, isLast: index == viewModel.spendingRecords.count - 1)

                            if index < viewModel.spendingRecords.count - 1 {
                                GagaeDivider()
                                    .padding(.horizontal, GagaeSpacing.md)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 지출 행
    private func spendingRow(record: SpendingRecordModel, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: GagaeSpacing.md) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(Color.gagaePinkLight)
                    .frame(width: 38, height: 38)

                Text(spendingIcon(for: record.title))
                    .font(.system(size: 18))
            }

            // 내용
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.gagaeCalloutMedium)
                    .foregroundStyle(.gagaeText)

                Text(FormatterUtils.relativeDate(record.date))
                    .font(.gagaeCaption)
                    .foregroundStyle(.gagaeTextSecondary)
            }

            Spacer()

            // 금액
            Text("- \(FormatterUtils.currencyString(from: record.amount))")
                .font(.gagaeCalloutMedium)
                .foregroundStyle(.gagaeDanger)

            // 삭제 버튼
            Button {
                viewModel.deleteSpending(id: record.id, eventBus: eventBus)
                let today = Calendar.current.startOfDay(for: Date())
                viewModel.fetchSpending(on: today)
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.gagaeTextTertiary)
            }
        }
        .padding(.horizontal, GagaeSpacing.md)
        .padding(.vertical, GagaeSpacing.sm)
    }

    /// 지출 항목에 따른 이모지 아이콘
    private func spendingIcon(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("카페") || lower.contains("커피") || lower.contains("cafe") { return "☕️" }
        if lower.contains("식사") || lower.contains("밥") || lower.contains("점심") || lower.contains("저녁") || lower.contains("아침") { return "🍱" }
        if lower.contains("편의점") || lower.contains("마트") { return "🏪" }
        if lower.contains("술") || lower.contains("맥주") { return "🍺" }
        if lower.contains("교통") || lower.contains("버스") || lower.contains("지하철") || lower.contains("택시") { return "🚌" }
        if lower.contains("영화") || lower.contains("공연") { return "🎬" }
        if lower.contains("쇼핑") || lower.contains("옷") { return "🛍️" }
        if lower.contains("병원") || lower.contains("약") { return "💊" }
        return "💸"
    }
}

// MARK: - SpendViewModel Extension
extension SpendViewModel {
    var totalSpentToday: Int {
        spendingRecords.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SpendView()
    }
    .environment(AppEventBus())
}
