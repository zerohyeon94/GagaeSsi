//
//  CategoryEditSheet.swift
//  GagaeSsi
//
//  사용자 카테고리 추가·수정 시트 (같은 시트를 mode로 나눠 쓴다).
//

import SwiftUI
import UIKit

struct CategoryEditSheet: View {
    enum Mode {
        case add
        case edit(UserCategoryModel)
    }

    let mode: Mode
    /// 저장에 성공했을 때 (카탈로그는 이미 다시 읽은 뒤)
    let onSaved: (UserCategoryModel) -> Void
    /// 수정 모드의 '카테고리 삭제' — 확인창은 호출한 쪽(관리 화면)이 띄운다
    let onRequestDelete: ((UserCategoryModel) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @FocusState private var customEmojiFocused: Bool

    @State private var name: String
    @State private var emoji: String
    @State private var color: UserCategoryColor
    @State private var customEmojiText = ""
    @State private var showCustomEmoji = false
    @State private var showEmojiHint = false
    @State private var saveFailed = false
    @State private var isSaving = false
    @State private var showDiscardConfirm = false

    /// 추천 이모지 15개 (기본값 💸 포함)
    static let recommendedEmojis = ["💸", "🐶", "👶", "🎁", "📺", "💇", "🍺", "🏠",
                                    "📚", "💪", "✈️", "🎮", "🚗", "🧾", "💝"]

    init(mode: Mode, onSaved: @escaping (UserCategoryModel) -> Void,
         onRequestDelete: ((UserCategoryModel) -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        self.onRequestDelete = onRequestDelete
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _emoji = State(initialValue: UserCategoryRules.defaultEmoji)
            _color = State(initialValue: UserCategoryRules.defaultColor(
                used: CategoryCatalog.shared.userCategories.map(\.color)))
        case .edit(let model):
            _name = State(initialValue: model.name)
            _emoji = State(initialValue: model.emoji)
            _color = State(initialValue: model.color)
            _showCustomEmoji = State(initialValue: !Self.recommendedEmojis.contains(model.emoji))
        }
    }

    // MARK: - 파생값

    private var editingModel: UserCategoryModel? {
        if case .edit(let model) = mode { return model }
        return nil
    }

    private var isEdit: Bool { editingModel != nil }

    private var validationError: UserCategoryError? {
        let others = CategoryCatalog.shared.userCategories.filter { $0.id != editingModel?.id }
        return UserCategoryRules.validate(name: name,
                                          existingNames: others.map(\.name),
                                          excluding: isEdit ? "" : nil,
                                          currentCount: others.count + (isEdit ? 1 : 0))
    }

    private var isDirty: Bool {
        guard let model = editingModel else { return false }
        return UserCategoryRules.normalizedName(name) != model.name
            || emoji != model.emoji || color != model.color
    }

    private var canSave: Bool {
        validationError == nil && (!isEdit || isDirty) && !isSaving
    }

    private var isDuplicate: Bool { validationError == .duplicateName }

    private var previewName: String {
        let trimmed = UserCategoryRules.normalizedName(name)
        return trimmed.isEmpty ? "카테고리" : trimmed
    }

    private var nameBinding: Binding<String> {
        Binding(get: { name }, set: { name = UserCategoryRules.clamp($0) })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: GagaeSpacing.md) {
                        preview
                        VStack(spacing: GagaeSpacing.md) {
                            nameCard
                            Divider()
                            emojiCard
                            Divider()
                            colorCard
                        }
                        .padding(GagaeSpacing.md)
                        .background(Color.gagaeCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .gagaeCardShadow()

                        if saveFailed {
                            Text("저장하지 못했어요. 다시 시도해 주세요")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.gagaeDanger)
                        }
                        GagaePrimaryButton(title: "저장하기", isEnabled: canSave, action: save)

                        if let model = editingModel, let onRequestDelete {
                            Button {
                                dismiss()
                                onRequestDelete(model)
                            } label: {
                                Text("카테고리 삭제")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.gagaeDanger)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .padding(.top, GagaeSpacing.sm)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, GagaeSpacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEdit ? "카테고리 수정" : "카테고리 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        if isDirty { showDiscardConfirm = true } else { dismiss() }
                    }
                    .foregroundStyle(.gagaePinkDark)
                }
            }
            .alert("수정한 내용을 버릴까요?", isPresented: $showDiscardConfirm) {
                Button("버리기", role: .destructive) { dismiss() }
                Button("계속 수정", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(isDirty)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            guard !isEdit else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            nameFocused = true
        }
    }

    // MARK: - 미리보기

    private var preview: some View {
        HStack(spacing: 10) {
            CategoryChip(emoji: emoji, name: previewName, color: color.color, isSelected: true)
            CategoryChip(emoji: emoji, name: previewName, color: color.color, isSelected: false)
        }
        .opacity(UserCategoryRules.normalizedName(name).isEmpty ? 0.6 : 1)
        .padding(.vertical, GagaeSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("미리보기, \(previewName)")
    }

    // MARK: - 이름

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("이름").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                Spacer()
                Text("\(name.count)/\(UserCategoryRules.maxNameLength)")
                    .font(.gagaeCaption)
                    .foregroundStyle(name.count >= UserCategoryRules.maxNameLength
                                     ? Color.gagaePinkDark : Color.gagaeTextTertiary)
            }
            TextField("예: 반려동물", text: nameBinding)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.gagaeText)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
                .frame(height: 46)
                .padding(.horizontal, 14)
                .background(Color.gagaeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDuplicate ? Color.gagaeDanger
                                : (nameFocused ? Color.gagaePinkDark : Color.gagaeDivider),
                                lineWidth: nameFocused || isDuplicate ? 1.8 : 1.5)
                )
            if isDuplicate {
                Text("이미 있는 카테고리 이름이에요")
                    .font(.gagaeCaption).foregroundStyle(.gagaeDanger)
            }
        }
    }

    // MARK: - 이모지

    private var emojiCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이모지").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
                ForEach(Self.recommendedEmojis, id: \.self) { candidate in
                    emojiCell(candidate, selected: emoji == candidate && !showCustomEmoji) {
                        emoji = candidate
                        showCustomEmoji = false
                        customEmojiFocused = false
                    }
                }
                customEmojiCell
            }
            if showCustomEmoji {
                TextField("🙂 이모지 키보드로 하나 골라요", text: $customEmojiText)
                    .font(.system(size: 15, design: .rounded))
                    .focused($customEmojiFocused)
                    .frame(height: 40)
                    .padding(.horizontal, 12)
                    .background(Color.gagaeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: customEmojiText) { _, text in applyCustomEmoji(text) }
            }
            if showEmojiHint {
                Text("이모지만 넣을 수 있어요")
                    .font(.gagaeCaption).foregroundStyle(.gagaeDanger)
            }
        }
    }

    private func emojiCell(_ value: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(value)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(selected ? Color.gagaePinkLight : Color.gagaeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? Color.gagaePinkDark : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// '직접' 칸 — 추천에 없는 이모지를 골랐으면 그 이모지를 보여준다
    private var customEmojiCell: some View {
        let isCustomValue = !Self.recommendedEmojis.contains(emoji)
        return Button {
            showCustomEmoji = true
            customEmojiText = ""
            customEmojiFocused = true
        } label: {
            VStack(spacing: 0) {
                if isCustomValue {
                    Text(emoji).font(.system(size: 20))
                } else {
                    Text("⌨️").font(.system(size: 16))
                    Text("직접").font(.system(size: 9, design: .rounded)).foregroundStyle(.gagaeTextSecondary)
                }
            }
            .frame(width: 40, height: 40)
            .background(showCustomEmoji || isCustomValue ? Color.gagaePinkLight : Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCustomValue ? Color.gagaePinkDark : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이모지 직접 입력")
    }

    /// 들어온 글에서 첫 이모지 하나만 남긴다. 이모지가 없으면 이전 값을 유지하고 안내한다.
    private func applyCustomEmoji(_ text: String) {
        guard !text.isEmpty else { return }
        if let first = UserCategoryRules.firstEmoji(in: text) {
            emoji = first
            if customEmojiText != first { customEmojiText = first }
        } else {
            customEmojiText = ""
            showEmojiHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showEmojiHint = false }
        }
    }

    // MARK: - 색

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("색").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: GagaeSpacing.sm) {
                    ForEach(UserCategoryColor.allCases, id: \.self) { colorCircle($0) }
                }
                VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                    HStack(spacing: GagaeSpacing.sm) {
                        ForEach(Array(UserCategoryColor.allCases.prefix(4)), id: \.self) { colorCircle($0) }
                    }
                    HStack(spacing: GagaeSpacing.sm) {
                        ForEach(Array(UserCategoryColor.allCases.suffix(4)), id: \.self) { colorCircle($0) }
                    }
                }
            }
        }
    }

    private func colorCircle(_ value: UserCategoryColor) -> some View {
        let selected = color == value
        return Button { color = value } label: {
            Circle()
                .fill(value.color)
                .frame(width: 32, height: 32)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(3)
                .overlay(
                    Circle().stroke(selected ? value.color : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 저장

    private func save() {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved: UserCategoryModel
            if var model = editingModel {
                model.name = UserCategoryRules.normalizedName(name)
                model.emoji = emoji
                model.color = color
                try CoreDataManager.shared.updateUserCategory(model)
                saved = model
            } else {
                saved = try CoreDataManager.shared.addUserCategory(name: name, emoji: emoji, color: color)
            }
            CategoryCatalog.shared.reload()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved(saved)
            dismiss()
        } catch {
            // 검증 오류는 버튼이 이미 막고 있으므로 여기 오는 건 저장 실패(또는 그 사이 바뀐 상태)
            saveFailed = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
