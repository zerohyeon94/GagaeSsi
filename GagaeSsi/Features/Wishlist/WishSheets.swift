//
//  WishSheets.swift
//  GagaeSsi
//
//  위시 추가/편집 · 저금 활성화 시트
//

import SwiftUI

// MARK: - 추가/편집
struct WishEditView: View {
    enum Mode {
        case add
        case edit(WishItemModel)
        var title: String {
            switch self { case .add: return "위시 추가"; case .edit: return "위시 수정" }
        }
    }

    let mode: Mode
    let onSave: (String, Int, WishKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amountText = ""
    @State private var amount = 0
    @State private var kind: WishKind = .want
    @FocusState private var focused: Bool

    private var isValid: Bool { !title.isEmpty && amount > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            // 종류
                            Label("종류", systemImage: "heart.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            Picker("종류", selection: $kind) {
                                ForEach(WishKind.allCases) { k in
                                    Text("\(k.emoji) \(k.label)").tag(k)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text(kind == .need ? "꼭 사야 하는 것" : "사고 싶은 것")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)

                            GagaeDivider()

                            // 이름
                            Label("이름", systemImage: "tag.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            TextField("예: 에어팟, 겨울 코트", text: $title)
                                .font(.gagaeBody).focused($focused)
                                .padding(GagaeSpacing.md)
                                .background(Color.gagaeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            // 목표 금액
                            Label("목표 금액", systemImage: "target")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) {
                                            amount = r.plainNumber; amountText = r.formatted
                                        }
                                    }
                            }
                            .padding(GagaeSpacing.md)
                            .background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) {
                        onSave(title, amount, kind)
                        dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)
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
                    title = m.title; amount = m.targetAmount
                    amountText = FormatterUtils.inputAmountString(from: m.targetAmount)
                    kind = m.kind
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 저금 활성화
struct WishActivateView: View {
    let item: WishItemModel
    let canActivate: Bool
    let onActivate: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var savingText = ""
    @State private var saving = 0
    @FocusState private var focused: Bool

    private var isValid: Bool { canActivate && saving > 0 }

    private var previewDays: Int? {
        guard saving > 0 else { return nil }
        let remaining = max(0, item.targetAmount - item.savedAmount)
        if remaining == 0 { return 0 }
        return Int((Double(remaining) / Double(saving)).rounded(.up))
    }

    private var previewDateLabel: String? {
        guard let d = previewDays, d > 0,
              let date = Calendar.current.date(byAdding: .day, value: d, to: Date()) else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일"
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            Text("\(item.kind.emoji) \(item.title)")
                                .font(.gagaeHeadline).foregroundStyle(.gagaeText)
                            Text("목표 \(FormatterUtils.currencyString(from: item.targetAmount))")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)

                            if !canActivate {
                                Text("이미 저금 중인 위시가 있어요.\n먼저 해지한 뒤 시작할 수 있어요.")
                                    .font(.gagaeFootnote).foregroundStyle(.gagaeDanger)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            GagaeDivider()

                            Label("하루 저금액", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $savingText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad).focused($focused)
                                    .disabled(!canActivate)
                                    .onChange(of: savingText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) {
                                            saving = r.plainNumber; savingText = r.formatted
                                        }
                                    }
                            }
                            .padding(GagaeSpacing.md)
                            .background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            if let d = previewDays {
                                HStack(spacing: 6) {
                                    Text(d == 0 ? "바로 구매 가능" : "D-\(d)")
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.gagaePinkDark)
                                    if let label = previewDateLabel {
                                        Text("· \(label) 구매 가능")
                                            .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                                    }
                                }
                            }
                            Text("매일 오늘 예산에서 이 금액만큼 모아둬요.\n저금은 소비 통계에 잡히지 않아요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저금 시작", isEnabled: isValid) {
                        onActivate(saving)
                        dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("저금 시작")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = canActivate }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
