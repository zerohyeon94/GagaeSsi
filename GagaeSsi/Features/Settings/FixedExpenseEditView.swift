//
//  FixedExpenseEditView.swift
//  GagaeSsi
//
//  고정비 추가/편집 화면
//

import SwiftUI

struct FixedExpenseEditView: View {
    // MARK: - Mode
    enum Mode {
        case add
        case edit(FixedCostModel)

        var title: String {
            switch self {
            case .add: return "고정비 추가"
            case .edit: return "고정비 수정"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .add: return "추가하기"
            case .edit: return "저장하기"
            }
        }
    }

    // MARK: - Properties
    let mode: Mode
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var amount: Int = 0
    @State private var isVariable: Bool = false
    @State private var dueDay: Int = 25

    @FocusState private var focusedField: Field?

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    enum Field { case title, amount }

    // MARK: - Computed
    private var isValid: Bool { !title.isEmpty && amount > 0 }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: GagaeSpacing.lg) {
                        // 입력 카드
                        inputCard
                            .padding(.top, GagaeSpacing.md)

                        // 저장 버튼
                        GagaePrimaryButton(title: mode.saveButtonTitle, isEnabled: isValid) {
                            save()
                        }
                        .padding(.bottom, GagaeSpacing.xl)
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear {
                loadExistingData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .title
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .alert("오류", isPresented: $showErrorAlert) {
                Button("확인") { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Subviews
extension FixedExpenseEditView {

    private var inputCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.md) {
                // 카드 헤더
                HStack {
                    Image(systemName: "pin.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.gagaePinkDark)
                    Text("고정비 정보")
                        .font(.gagaeHeadline)
                        .foregroundStyle(.gagaeText)
                    Spacer()
                }

                GagaeDivider()

                // 항목명 입력
                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Label("항목명", systemImage: "tag.fill")
                        .font(.gagaeFootnote)
                        .foregroundStyle(.gagaeTextSecondary)

                    TextField("예: 월세, 보험료, 구독료", text: $title)
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

                // 변동형 토글
                Toggle(isOn: $isVariable.animation()) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("변동형 (매달 금액이 달라요)")
                            .font(.gagaeCalloutMedium)
                            .foregroundStyle(.gagaeText)
                        Text("관리비·이자·환율처럼 지출일에 확정")
                            .font(.gagaeCaption)
                            .foregroundStyle(.gagaeTextTertiary)
                    }
                }
                .tint(.gagaePinkDark)

                // 지출일 (변동형만)
                if isVariable {
                    VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                        Label("지출일", systemImage: "calendar.circle.fill")
                            .font(.gagaeFootnote)
                            .foregroundStyle(.gagaeTextSecondary)

                        HStack {
                            Text("매월")
                                .font(.gagaeCallout)
                                .foregroundStyle(.gagaeTextSecondary)
                            Picker("지출일", selection: $dueDay) {
                                ForEach(1...31, id: \.self) { d in Text("\(d)일").tag(d) }
                            }
                            .tint(.gagaePinkDark)
                            Spacer()
                        }
                        .padding(.horizontal, GagaeSpacing.md)
                        .padding(.vertical, GagaeSpacing.xs)
                        .background(Color.gagaeSurface)
                        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                    }
                }

                // 금액 입력
                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Label(isVariable ? "예상 월 금액" : "월 금액", systemImage: "wonsign.circle.fill")
                        .font(.gagaeFootnote)
                        .foregroundStyle(.gagaeTextSecondary)

                    HStack(spacing: GagaeSpacing.sm) {
                        Text("₩")
                            .font(.gagaeTitle3)
                            .foregroundStyle(.gagaePinkDark)

                        TextField("0", text: $amountText)
                            .font(.gagaeTitle3)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: amountText) { _, newValue in
                                if let result = FormatterUtils.formatCurrencyInput(newValue) {
                                    amount = result.plainNumber
                                    amountText = result.formatted
                                }
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
    }
}

// MARK: - Methods
extension FixedExpenseEditView {
    private func loadExistingData() {
        if case .edit(let model) = mode {
            title = model.title
            amount = model.amount
            amountText = FormatterUtils.inputAmountString(from: model.amount)
            isVariable = model.isVariable
            if model.dueDay >= 1 && model.dueDay <= 31 { dueDay = model.dueDay }
        }
    }

    private func save() {
        guard isValid else {
            errorMessage = "항목명과 금액을 입력해주세요"
            showErrorAlert = true
            return
        }

        let success: Bool

        let variableDueDay = isVariable ? dueDay : 0

        switch mode {
        case .add:
            let newModel = FixedCostModel(id: UUID(), title: title, amount: amount,
                                          isVariable: isVariable, dueDay: variableDueDay)
            success = CoreDataManager.shared.createFixedCost(newModel)

        case .edit(let existing):
            let updatedModel = FixedCostModel(id: existing.id, title: title, amount: amount,
                                              isVariable: isVariable, dueDay: variableDueDay)
            success = CoreDataManager.shared.updateFixedCost(updatedModel)
        }

        if success {
            // 변동 고정비면 지출일 알림을 위해 권한 요청 (맥락에 맞게)
            if isVariable {
                NotificationService.shared.requestAuthorizationIfNeeded()
            }
            onSave()
            dismiss()
        } else {
            errorMessage = "저장에 실패했습니다"
            showErrorAlert = true
        }
    }
}

// MARK: - Preview
#Preview("Add Mode") {
    FixedExpenseEditView(mode: .add) { }
}

#Preview("Edit Mode") {
    FixedExpenseEditView(
        mode: .edit(FixedCostModel(id: UUID(), title: "월세", amount: 500000))
    ) { }
}
