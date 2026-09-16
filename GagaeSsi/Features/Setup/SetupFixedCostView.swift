//
//  SetupFixedCostView.swift
//  GagaeSsi
//
//  초기 설정 - 고정비 입력 (Claude Design 적용)
//

import SwiftUI

struct SetupFixedCostView: View {
    // MARK: - Properties
    @Bindable var viewModel: SetupViewModel
    @Environment(AppState.self) private var appState

    @State private var showAdd = false
    @State private var showSaveErrorAlert = false
    @FocusState private var focusedField: Field?

    enum Field { case name, amount }

    private static let emojis = ["🏠", "📱", "🎮", "🚗", "⚡️", "💪", "📺", "🍕", "💈", "📚"]

    // MARK: - Body
    var body: some View {
        ZStack {
            GagaeBackground()

            VStack(spacing: 0) {
                SetupProgressDots(step: 2)

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 16)

                        itemsCard
                            .padding(.top, 20)

                        if !viewModel.model.fixedCosts.isEmpty {
                            totalSummary
                                .padding(.top, 12)
                        }
                    }
                }

                completeButton
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationBarHidden(true)
        .alert("저장 실패", isPresented: $showSaveErrorAlert) {
            Button("확인") { }
        } message: {
            Text("예산 설정 저장에 실패했습니다. 다시 시도해주세요.")
        }
        .onTapGesture { focusedField = nil }
    }
}

// MARK: - Subviews
extension SetupFixedCostView {

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("고정비를 등록해볼까요?")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Text("월세, 구독료 등 매달 나가는 돈이에요")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
            }
            Spacer()
            Button {
                saveAndContinue()
            } label: {
                Text("건너뛰기")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var itemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.model.fixedCosts.enumerated()), id: \.element.id) { index, item in
                itemRow(item: item, index: index)
                Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 66)
            }

            if showAdd {
                inlineAddForm
            } else {
                Button {
                    showAdd = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusedField = .name }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("고정비 추가하기")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.gagaePinkDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(Color.gagaePinkDark)
                    )
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func itemRow(item: FixedCostModel, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.gagaePinkDark.opacity(0.1)).frame(width: 38, height: 38)
                Text(Self.emojis[index % Self.emojis.count]).font(.system(size: 18))
            }
            Text(item.title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.gagaeText)
            Spacer()
            Text(FormatterUtils.currencyString(from: item.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeText)
            Button {
                viewModel.removeFixedCost(at: IndexSet(integer: index))
            } label: {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.gagaePinkPale)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.gagaeDanger)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var inlineAddForm: some View {
        HStack(spacing: 8) {
            TextField("항목명", text: $viewModel.newFixedCostTitle)
                .font(.system(size: 14, design: .rounded))
                .focused($focusedField, equals: .name)
                .frame(height: 40)
                .padding(.horizontal, 12)
                .background(Color.gagaeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gagaePinkDark, lineWidth: 1.5))

            HStack(spacing: 0) {
                Text("₩")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaePinkDark)
                    .padding(.leading, 8)
                TextField("금액", text: $viewModel.newFixedCostAmountText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .amount)
                    .padding(.horizontal, 6)
                    .onChange(of: viewModel.newFixedCostAmountText) { _, newValue in
                        viewModel.updateFixedCostAmountFromText(newValue)
                    }
            }
            .frame(height: 40)
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gagaeDivider, lineWidth: 1.5))

            Button {
                viewModel.addFixedCost()
                showAdd = false
                focusedField = nil
            } label: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gagaePinkDark)
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white))
            }
            .buttonStyle(.plain)
            .disabled(!isAddValid)
            .opacity(isAddValid ? 1 : 0.5)

            Button {
                viewModel.clearFixedCostInput()
                showAdd = false
                focusedField = nil
            } label: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gagaeSurfaceAlt)
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.gagaeTextTertiary))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private var totalSummary: some View {
        HStack(spacing: 6) {
            Spacer()
            Text("총 고정비")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
            Text("월 -" + FormatterUtils.currencyString(from: viewModel.totalFixedCost))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.gagaeDanger)
        }
        .padding(.horizontal, 2)
    }

    private var completeButton: some View {
        Button {
            saveAndContinue()
        } label: {
            Text("완료, 시작할게요! 🎉")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(LinearGradient(colors: [.gagaePinkDark, .gagaePink],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Capsule())
                .gagaeShadow(color: .gagaePinkDark.opacity(0.32), radius: 14, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var isAddValid: Bool {
        !viewModel.newFixedCostTitle.isEmpty && viewModel.newFixedCostAmount > 0
    }

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

// MARK: - Preview
#Preview {
    NavigationStack {
        SetupFixedCostView(viewModel: SetupViewModel())
    }
    .environment(AppState())
    .environment(AppEventBus())
}
