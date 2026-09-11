//
//  PaybackSheets.swift
//  GagaeSsi
//
//  페이백 추가/편집 · 수령 처리 시트
//

import SwiftUI

// MARK: - 추가/편집
struct PaybackEditView: View {
    enum Mode {
        case add
        case edit(PaybackModel)
        var title: String { switch self { case .add: return "페이백 추가"; case .edit: return "페이백 수정" } }
    }
    let mode: Mode
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: PaybackType = .transaction
    @State private var title = ""
    @State private var estText = ""
    @State private var est = 0
    @State private var confText = ""
    @State private var conf = 0
    @State private var hasExpectedDate = false
    @State private var expectedDate = Date()
    @State private var periodStart = Date()
    @State private var periodEnd = Date()
    /// 기간형에서 자동으로 묶을 카테고리 (nil이면 수동 입력)
    @State private var linkedCategory: SpendingCategory?
    @State private var refundRate = 0

    private var editingModel: PaybackModel? { if case .edit(let m) = mode { return m }; return nil }
    private var isValid: Bool { !title.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            Label("유형", systemImage: "creditcard.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            Picker("유형", selection: $type) {
                                ForEach(PaybackType.allCases) { t in Text(t.label).tag(t) }
                            }.pickerStyle(.segmented)

                            Label(type == .period ? "제목 (예: K-패스 7월)" : "제목", systemImage: "tag.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            TextField("제목", text: $title)
                                .font(.gagaeBody).padding(GagaeSpacing.md).background(Color.gagaeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            amountField("예상 환급액", "0", $estText) { est = $0 }
                            amountField("확정 환급액 (선택)", "확정되면 입력", $confText) { conf = $0 }

                            Toggle(isOn: $hasExpectedDate.animation()) {
                                Text("입금 예정일").font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                            }.tint(.gagaePinkDark)
                            if hasExpectedDate {
                                DatePicker("예정일", selection: $expectedDate, displayedComponents: .date)
                                    .font(.gagaeFootnote).tint(.gagaePinkDark)
                            }

                            if type == .period {
                                GagaeDivider()
                                Text("합산 기간").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                DatePicker("시작", selection: $periodStart, displayedComponents: .date).font(.gagaeFootnote).tint(.gagaePinkDark)
                                DatePicker("종료", selection: $periodEnd, displayedComponents: .date).font(.gagaeFootnote).tint(.gagaePinkDark)

                                GagaeDivider()
                                linkedCategoryField
                                if linkedCategory != nil { refundRateField }
                            }

                            Text("오늘 예산에는 실제 수령 후에만 반영돼요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) { save() }
                        .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark) } }
            .onAppear { loadIfEditing() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// 어떤 카테고리 소비를 묶을지 — K-패스처럼 한 달치를 직접 더하지 않아도 되게 한다
    private var linkedCategoryField: some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            Text("소비 자동 묶기 (선택)").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GagaeSpacing.sm) {
                    categoryChip(nil, label: "안 씀")
                    ForEach(SpendingCategory.allCases, id: \.self) { category in
                        categoryChip(category, label: "\(category.emoji) \(category.rawValue)")
                    }
                }
                .padding(.horizontal, 2)
            }
            Text("고른 카테고리의 기간 내 소비를 자동으로 합산해 보여줘요.")
                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
        }
    }

    private func categoryChip(_ category: SpendingCategory?, label: String) -> some View {
        let selected = linkedCategory == category
        return Button {
            linkedCategory = category
            if category == nil { refundRate = 0 }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: selected ? .heavy : .medium, design: .rounded))
                .foregroundStyle(selected ? .white : Color.gagaeTextSecondary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? AnyShapeStyle(Color.gagaePinkDark) : AnyShapeStyle(Color.gagaeSurface))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// 환급률 — 합산액 × 이 비율로 예상액을 자동 계산한다
    private var refundRateField: some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            HStack {
                Text("환급률 (선택)").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                Spacer()
                Text(refundRate > 0 ? "\(refundRate)%" : "미사용")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GagaeSpacing.sm) {
                    ForEach([0, 10, 15, 20, 25, 30, 40, 53], id: \.self) { rate in
                        Button { refundRate = rate } label: {
                            Text(rate == 0 ? "미사용" : "\(rate)%")
                                .font(.system(size: 12, weight: refundRate == rate ? .heavy : .medium, design: .rounded))
                                .foregroundStyle(refundRate == rate ? .white : Color.gagaeTextSecondary)
                                .frame(minWidth: 46).padding(.vertical, 7)
                                .background(refundRate == rate ? AnyShapeStyle(Color.gagaePinkDark) : AnyShapeStyle(Color.gagaeSurface))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            Text("K-패스는 유형에 따라 20~53%예요. 넣어두면 예상액을 자동으로 계산해 드려요.")
                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func amountField(_ label: String, _ placeholder: String, _ text: Binding<String>, set: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
            Text(label).font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
            HStack(spacing: GagaeSpacing.sm) {
                Text("₩").font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                TextField(placeholder, text: text)
                    .keyboardType(.numberPad)
                    .onChange(of: text.wrappedValue) { _, v in
                        if let r = FormatterUtils.formatCurrencyInput(v) { set(r.plainNumber); text.wrappedValue = r.formatted }
                        else if v.isEmpty { set(0) }
                    }
            }
            .padding(GagaeSpacing.md).background(Color.gagaeSurface).clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
        }
    }

    private func loadIfEditing() {
        guard let m = editingModel else { return }
        type = m.type; title = m.title
        est = m.estimatedAmount; estText = m.estimatedAmount > 0 ? FormatterUtils.inputAmountString(from: m.estimatedAmount) : ""
        conf = m.confirmedAmount; confText = m.confirmedAmount > 0 ? FormatterUtils.inputAmountString(from: m.confirmedAmount) : ""
        if let ed = m.expectedDate { hasExpectedDate = true; expectedDate = ed }
        if let ps = m.periodStart { periodStart = ps }
        if let pe = m.periodEnd { periodEnd = pe }
        linkedCategory = m.linkedCategory
        refundRate = m.refundRatePercent
    }

    private func save() {
        guard isValid else { return }
        // 상태: 수령/취소면 보존, 아니면 확정액 있으면 확정 else 예상
        let status: PaybackStatus = {
            if let m = editingModel, m.status == .received || m.status == .cancelled { return m.status }
            return conf > 0 ? .confirmed : .estimated
        }()
        let model = PaybackModel(
            id: editingModel?.id ?? UUID(),
            title: title, type: type, status: status,
            estimatedAmount: est, confirmedAmount: conf,
            receivedAmount: editingModel?.receivedAmount ?? 0,
            expectedDate: hasExpectedDate ? expectedDate : nil,
            receivedDate: editingModel?.receivedDate,
            periodStart: type == .period ? periodStart : nil,
            periodEnd: type == .period ? periodEnd : nil,
            createdAt: editingModel?.createdAt ?? Date(),
            linkedCategory: type == .period ? linkedCategory : nil,
            refundRatePercent: type == .period ? refundRate : 0)

        let ok = editingModel == nil
            ? CoreDataManager.shared.createPayback(model)
            : CoreDataManager.shared.updatePayback(model)
        if ok { onSave(); dismiss() }
    }
}

// MARK: - 수령 처리
struct PaybackReceiveView: View {
    let payback: PaybackModel
    let onReceive: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var amount = 0
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            Text("✅ \(payback.title)").font(.gagaeHeadline).foregroundStyle(.gagaeText)
                            Text("실제 입금된 금액을 입력하면 오늘 예산에 더해져요.")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            GagaeDivider()
                            Label("수령 금액", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad).focused($focused)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) { amount = r.plainNumber; amountText = r.formatted }
                                    }
                            }
                            .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                            Text("예상/확정: \(FormatterUtils.currencyString(from: payback.currentAmount))")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "수령 완료", isEnabled: amount > 0) {
                        onReceive(amount); dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("수령 처리").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark) } }
            .onAppear {
                amount = payback.currentAmount
                amountText = payback.currentAmount > 0 ? FormatterUtils.inputAmountString(from: payback.currentAmount) : ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
