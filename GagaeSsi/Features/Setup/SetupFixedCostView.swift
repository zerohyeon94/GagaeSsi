//
//  SetupFixedCostView.swift
//  GagaeSsi
//
//  초기 설정 - 고정비 입력 화면
//

import SwiftUI

struct SetupFixedCostView: View {
    // MARK: - Properties
    @Bindable var viewModel: SetupViewModel
    @Environment(AppState.self) private var appState

    @State private var showAddSheet = false
    @State private var showSaveErrorAlert = false

    // MARK: - Body
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gagaePinkGradientTop, Color.gagaePinkGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                headerSection
                    .padding(.top, GagaeSpacing.lg)

                // 고정비 추가 버튼 + 목록
                contentSection
                    .padding(.top, GagaeSpacing.md)
                    .padding(.horizontal, GagaeSpacing.md)

                Spacer()

                // 하단 버튼들
                bottomButtons
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.bottom, GagaeSpacing.xl)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddSheet) {
            AddFixedCostSheet(viewModel: viewModel)
        }
        .alert("저장 실패", isPresented: $showSaveErrorAlert) {
            Button("확인") { }
        } message: {
            Text("예산 설정 저장에 실패했습니다. 다시 시도해주세요.")
        }
    }
}

// MARK: - Subviews
extension SetupFixedCostView {

    /// 헤더 섹션
    private var headerSection: some View {
        VStack(spacing: GagaeSpacing.sm) {
            Text("📌")
                .font(.system(size: 44))

            VStack(spacing: GagaeSpacing.xs) {
                Text("고정비를 알려주세요")
                    .font(.gagaeTitle2)
                    .foregroundStyle(.gagaePinkDark)

                Text("매달 고정으로 나가는 비용을 등록하면\n더 정확한 일일 예산을 계산해드려요")
                    .font(.gagaeSubheadline)
                    .foregroundStyle(.gagaeTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 내용 섹션
    private var contentSection: some View {
        VStack(spacing: GagaeSpacing.md) {
            // 추가 버튼
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: GagaeSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("고정비 추가하기")
                        .font(.gagaeCalloutMedium)
                }
                .foregroundStyle(.gagaePinkDark)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.gagaePinkLight)
                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.full))
                .overlay(
                    RoundedRectangle(cornerRadius: GagaeRadius.full)
                        .stroke(Color.gagaePinkDark.opacity(0.3), lineWidth: 1)
                )
            }

            // 목록
            fixedCostList
        }
    }

    /// 고정비 목록
    private var fixedCostList: some View {
        Group {
            if viewModel.model.fixedCosts.isEmpty {
                GagaeCard {
                    GagaeEmptyStateView(
                        icon: "🪣",
                        title: "아직 없어요",
                        subtitle: "고정비가 없으면 건너뛰어도 돼요!\n나중에 설정에서 추가할 수 있어요."
                    )
                }
            } else {
                GagaeCard(padding: 0) {
                    VStack(spacing: 0) {
                        // 목록 아이템들
                        ForEach(Array(viewModel.model.fixedCosts.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: GagaeSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gagaePinkLight)
                                        .frame(width: 36, height: 36)
                                    Text("📌")
                                        .font(.system(size: 16))
                                }

                                Text(item.title)
                                    .font(.gagaeCalloutMedium)
                                    .foregroundStyle(.gagaeText)

                                Spacer()

                                Text(FormatterUtils.currencyString(from: item.amount))
                                    .font(.gagaeCalloutMedium)
                                    .foregroundStyle(.gagaeDanger)

                                Button {
                                    viewModel.removeFixedCost(at: IndexSet(integer: index))
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.gagaeTextTertiary)
                                }
                            }
                            .padding(.horizontal, GagaeSpacing.md)
                            .padding(.vertical, GagaeSpacing.sm)

                            if index < viewModel.model.fixedCosts.count - 1 {
                                GagaeDivider()
                                    .padding(.leading, 56)
                            }
                        }

                        GagaeDivider()

                        // 합계 행
                        HStack {
                            Text("월 고정 지출 합계")
                                .font(.gagaeCalloutMedium)
                                .foregroundStyle(.gagaeText)

                            Spacer()

                            Text(FormatterUtils.currencyString(from: viewModel.totalFixedCost))
                                .font(.gagaeAmountSmall)
                                .foregroundStyle(.gagaeDanger)
                        }
                        .padding(.horizontal, GagaeSpacing.md)
                        .padding(.vertical, GagaeSpacing.sm)
                    }
                }
            }
        }
    }

    /// 하단 버튼들
    private var bottomButtons: some View {
        VStack(spacing: GagaeSpacing.sm) {
            // 저장하고 시작 (메인 버튼)
            GagaePrimaryButton(title: "시작하기 🐷", isEnabled: true) {
                saveAndContinue()
            }

            // 건너뛰기
            Button {
                saveAndContinue()
            } label: {
                Text("고정비 없이 시작할게요")
                    .font(.gagaeSubheadline)
                    .foregroundStyle(.gagaeTextSecondary)
                    .underline()
            }
        }
    }

    // MARK: - Methods
    private func saveAndContinue() {
        viewModel.saveBudgetConfig { success in
            if success {
                appState.completeSetup()
            } else {
                showSaveErrorAlert = true
            }
        }
    }
}

// MARK: - Add Fixed Cost Sheet
struct AddFixedCostSheet: View {
    @Bindable var viewModel: SetupViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field { case title, amount }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: GagaeSpacing.lg) {
                        GagaeCard {
                            VStack(spacing: GagaeSpacing.md) {
                                HStack {
                                    Image(systemName: "pin.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.gagaePinkDark)
                                    Text("고정비 추가")
                                        .font(.gagaeHeadline)
                                        .foregroundStyle(.gagaeText)
                                    Spacer()
                                }

                                GagaeDivider()

                                // 항목명
                                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                                    Label("항목명", systemImage: "tag.fill")
                                        .font(.gagaeFootnote)
                                        .foregroundStyle(.gagaeTextSecondary)

                                    TextField("예: 월세, 보험료, 구독료", text: $viewModel.newFixedCostTitle)
                                        .font(.gagaeBody)
                                        .focused($focusedField, equals: .title)
                                        .padding(GagaeSpacing.md)
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

                                // 금액
                                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                                    Label("월 금액", systemImage: "wonsign.circle.fill")
                                        .font(.gagaeFootnote)
                                        .foregroundStyle(.gagaeTextSecondary)

                                    HStack(spacing: GagaeSpacing.sm) {
                                        Text("₩")
                                            .font(.gagaeTitle3)
                                            .foregroundStyle(.gagaePinkDark)

                                        TextField("0", text: $viewModel.newFixedCostAmountText)
                                            .font(.gagaeTitle3)
                                            .keyboardType(.numberPad)
                                            .focused($focusedField, equals: .amount)
                                            .onChange(of: viewModel.newFixedCostAmountText) { _, newValue in
                                                viewModel.updateFixedCostAmountFromText(newValue)
                                            }
                                    }
                                    .padding(GagaeSpacing.md)
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
                            }
                        }
                        .padding(.top, GagaeSpacing.md)

                        GagaePrimaryButton(title: "추가하기", isEnabled: isAddValid) {
                            viewModel.addFixedCost()
                            dismiss()
                        }
                        .padding(.bottom, GagaeSpacing.xl)
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                }
            }
            .navigationTitle("고정비 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        viewModel.clearFixedCostInput()
                        dismiss()
                    }
                    .foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .title
                }
            }
            .onTapGesture {
                focusedField = nil
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var isAddValid: Bool {
        !viewModel.newFixedCostTitle.isEmpty && viewModel.newFixedCostAmount > 0
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SetupFixedCostView(viewModel: SetupViewModel())
    }
    .environment(AppState())
    .environment(AppEventBus())
}
