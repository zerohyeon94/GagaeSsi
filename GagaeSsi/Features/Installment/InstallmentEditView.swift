//
//  InstallmentEditView.swift
//  GagaeSsi
//
//  할부 추가/편집 시트
//

import SwiftUI

struct InstallmentEditView: View {
    enum Mode {
        case add
        case edit(InstallmentModel)
        var title: String { switch self { case .add: return "할부 추가"; case .edit: return "할부 수정" } }
    }

    let mode: Mode
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var totalText = ""
    @State private var total = 0
    @State private var months = 12
    @State private var startDate = Date()
    @FocusState private var focused: Bool

    private var isValid: Bool { !title.isEmpty && total > 0 && months > 0 }
    private var monthlyPreview: Int { months > 0 ? total / months : 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            // 항목명
                            Label("항목명", systemImage: "tag.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            TextField("예: 노트북, 냉장고", text: $title)
                                .font(.gagaeBody).focused($focused)
                                .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            // 총액
                            Label("총액 (이자 포함)", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $totalText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad)
                                    .onChange(of: totalText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) {
                                            total = r.plainNumber; totalText = r.formatted
                                        }
                                    }
                            }
                            .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            // 개월수
                            HStack {
                                Label("개월수", systemImage: "calendar")
                                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                Spacer()
                                Picker("개월수", selection: $months) {
                                    ForEach(1...36, id: \.self) { m in Text("\(m)개월").tag(m) }
                                }.tint(.gagaePinkDark)
                            }

                            // 시작 월
                            DatePicker("시작 월", selection: $startDate, displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                .tint(.gagaePinkDark)

                            GagaeDivider()

                            // 월 납입액 미리보기
                            HStack {
                                Text("월 납입액").font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                Spacer()
                                Text(FormatterUtils.currencyString(from: monthlyPreview))
                                    .font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                            }
                            Text("매월 하루 예산에서 미리 나눠 차감돼요 (소비 기록은 만들지 않아요)")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) { save() }
                        .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear {
                if case .edit(let m) = mode {
                    title = m.title
                    total = m.totalAmount
                    totalText = FormatterUtils.inputAmountString(from: m.totalAmount)
                    months = min(max(m.months, 1), 36)
                    startDate = Calendar.current.date(from: DateComponents(year: m.startYear, month: m.startMonth, day: 1)) ?? Date()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard isValid else { return }
        let c = Calendar.current.dateComponents([.year, .month], from: startDate)
        let model = InstallmentModel(
            id: {
                if case .edit(let m) = mode { return m.id }
                return UUID()
            }(),
            title: title, totalAmount: total, months: months,
            startYear: c.year ?? 2026, startMonth: c.month ?? 1)

        let ok: Bool
        switch mode {
        case .add: ok = CoreDataManager.shared.createInstallment(model)
        case .edit: ok = CoreDataManager.shared.updateInstallment(model)
        }
        if ok { onSave(); dismiss() }
    }
}
