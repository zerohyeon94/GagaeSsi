//
//  HistorySpendEditView.swift
//  GagaeSsi
//
//  내역에서 과거 소비 수정 (저장 시 이월 체인 재계산 트리거)
//

import SwiftUI

struct HistorySpendEditView: View {
    let record: SpendingRecordModel
    /// 저장 완료 콜백
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amountText = ""
    @State private var amount = 0
    @State private var category: SpendingCategory = .other
    @State private var date = Date()
    @State private var hasPayback = false
    @State private var paybackText = ""
    @State private var payback = 0
    @FocusState private var amountFocused: Bool

    private var isValid: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            // 카테고리
                            Label("카테고리", systemImage: "square.grid.2x2.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 7) {
                                    ForEach(SpendingCategory.allCases, id: \.self) { c in
                                        Button { category = c } label: {
                                            Text("\(c.emoji) \(c.rawValue)")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(category == c ? .white : .gagaeTextSecondary)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(category == c ? c.color : Color.gagaeSurface)
                                                .clipShape(Capsule())
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }

                            // 항목명
                            Label("내용", systemImage: "tag.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            TextField("내용", text: $title)
                                .font(.gagaeBody).padding(GagaeSpacing.md)
                                .background(Color.gagaeSurface).clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            // 금액
                            Label("금액", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad).focused($amountFocused)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) { amount = r.plainNumber; amountText = r.formatted }
                                    }
                            }
                            .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            // 날짜
                            DatePicker("날짜", selection: $date, displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary).tint(.gagaePinkDark)

                            // 환급 예정
                            Toggle(isOn: $hasPayback.animation()) {
                                Text("💳 환급·페이백 예정")
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                            }.tint(.gagaePinkDark)
                            if hasPayback {
                                HStack(spacing: GagaeSpacing.sm) {
                                    Text("₩").font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                                    TextField("환급 예정 금액", text: $paybackText)
                                        .keyboardType(.numberPad)
                                        .onChange(of: paybackText) { _, v in
                                            if let r = FormatterUtils.formatCurrencyInput(v) { payback = r.plainNumber; paybackText = r.formatted }
                                        }
                                }
                                .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                            }

                            Text("바꾸면 이후 날짜의 사용 가능 금액과 이월금이 다시 계산돼요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) { save() }
                        .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("소비 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark) }
            }
            .onAppear { loadRecord() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func loadRecord() {
        title = record.title
        amount = record.amount
        amountText = FormatterUtils.inputAmountString(from: record.amount)
        category = record.category
        date = record.date
        payback = record.expectedPayback
        paybackText = record.expectedPayback > 0 ? FormatterUtils.inputAmountString(from: record.expectedPayback) : ""
        hasPayback = record.expectedPayback > 0
    }

    private func save() {
        guard isValid else { return }
        // date-only 피커라 시각 성분은 원래 기록의 것을 유지하려면 날짜만 교체
        let cal = Calendar.current
        let timeComps = cal.dateComponents([.hour, .minute, .second], from: record.date)
        let newDate = cal.date(bySettingHour: timeComps.hour ?? 0, minute: timeComps.minute ?? 0,
                               second: timeComps.second ?? 0, of: cal.startOfDay(for: date)) ?? date

        var updated = record
        updated.title = title.isEmpty ? category.rawValue : title
        updated.amount = amount
        updated.category = category
        updated.date = newDate
        updated.expectedPayback = hasPayback ? payback : 0
        // paybackReceived는 record 값 유지

        if CoreDataManager.shared.updateSpendingRecord(updated) {
            onSaved()
            dismiss()
        }
    }
}
