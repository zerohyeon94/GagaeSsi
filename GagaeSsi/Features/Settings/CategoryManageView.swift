//
//  CategoryManageView.swift
//  GagaeSsi
//
//  설정 > 데이터 > 카테고리 관리 — 기본 7개(읽기 전용)와 내가 만든 카테고리 목록.
//

import SwiftUI

struct CategoryManageView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var viewModel = CategoryManageViewModel()
    @State private var editTarget: EditTarget?

    private enum EditTarget: Identifiable {
        case add
        case edit(UserCategoryModel)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let model): return model.id.uuidString
            }
        }
    }

    var body: some View {
        ZStack {
            List {
                builtInSection
                userSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.gagaeBackground)

            if let toast = viewModel.toast { toastView(toast) }
        }
        .background(Color.gagaeBackground.ignoresSafeArea())
        .navigationTitle("카테고리 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editTarget = .add } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(viewModel.canAdd ? Color.gagaePinkDark : Color.gagaeTextTertiary)
                }
                .disabled(!viewModel.canAdd)
                .accessibilityLabel("카테고리 추가")
            }
        }
        .onAppear { viewModel.load() }
        .onChange(of: eventBus.categoryChangedTrigger) { viewModel.load() }
        .sheet(item: $editTarget) { target in
            switch target {
            case .add:
                CategoryEditSheet(mode: .add) { _ in afterChange() }
            case .edit(let model):
                CategoryEditSheet(mode: .edit(model), onSaved: { _ in afterChange() },
                                  onRequestDelete: { model in
                    // 시트가 완전히 내려간 뒤에 확인창을 띄운다
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        viewModel.requestDelete(model)
                    }
                })
            }
        }
        .alert(deleteAlertTitle,
               isPresented: Binding(get: { viewModel.pendingDelete != nil },
                                    set: { if !$0 { viewModel.pendingDelete = nil } }),
               presenting: viewModel.pendingDelete) { pending in
            Button("삭제", role: .destructive) {
                if viewModel.confirmDelete(pending) {
                    eventBus.notifyCategoryChanged()
                    showToastBriefly()
                }
            }
            Button("취소", role: .cancel) {}
        } message: { pending in
            Text(CategoryDeleteMessage.make(name: pending.model.name, records: pending.records,
                                            paybacks: pending.paybacks).message)
        }
        .alert("삭제하지 못했어요", isPresented: $viewModel.deleteFailed) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("다시 시도해 주세요")
        }
    }

    // MARK: - 삭제 확인 문구

    private var deleteAlertTitle: String {
        guard let p = viewModel.pendingDelete else { return "" }
        return CategoryDeleteMessage.make(name: p.model.name, records: p.records, paybacks: p.paybacks).title
    }

    // MARK: - 기본 섹션

    private var builtInSection: some View {
        Section {
            FlowLayout(spacing: 7) {
                ForEach(SpendingCategory.allCases, id: \.self) { category in
                    HStack(spacing: 5) {
                        Circle().fill(category.color).frame(width: 6, height: 6)
                        Text(category.emoji).font(.system(size: 14))
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.gagaeTextSecondary)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Color.gagaeSurfaceAlt)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.gagaeDivider, lineWidth: 1.5))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(category.rawValue), 기본 카테고리")
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.gagaeCardBackground)
        } header: {
            sectionTitle("기본")
        } footer: {
            Text("기본 카테고리는 바꾸거나 지울 수 없어요")
                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
        }
    }

    // MARK: - 내가 만든 카테고리 섹션

    private var userSection: some View {
        Section {
            if viewModel.rows.isEmpty {
                emptyRow.listRowBackground(Color.gagaeCardBackground)
            }
            ForEach(viewModel.rows) { row in
                userRow(row)
                    .listRowBackground(Color.gagaeCardBackground)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.requestDelete(row.model)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }
            Button { editTarget = .add } label: {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("카테고리 추가").font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(viewModel.canAdd ? Color.gagaePinkDark : Color.gagaeTextTertiary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canAdd)
            .listRowBackground(Color.gagaeCardBackground)
        } header: {
            HStack {
                sectionTitle("내가 만든 카테고리")
                Spacer()
                Text("\(viewModel.rows.count)/\(UserCategoryRules.maxCount)")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if !viewModel.canAdd {
                    Text("카테고리는 20개까지 만들 수 있어요")
                        .foregroundStyle(.gagaeTextSecondary)
                }
                Text("이름·이모지·색을 바꾸면 지난 기록에도 바로 반영돼요.")
                Text("예산·이월 계산에는 영향이 없어요.")
            }
            .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
        }
    }

    private func userRow(_ row: CategoryManageViewModel.Row) -> some View {
        Button { editTarget = .edit(row.model) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(row.model.color.color.opacity(0.13)).frame(width: 34, height: 34)
                    Text(row.model.emoji).font(.system(size: 16))
                }
                Text(row.model.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text("\(row.usageCount)건")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gagaeTextTertiary)
            }
            .padding(.vertical, 4)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.model.name), 내가 만든 카테고리, 기록 \(row.usageCount)건")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "삭제") { viewModel.requestDelete(row.model) }
    }

    private var emptyRow: some View {
        VStack(spacing: 6) {
            Text("🐷").font(.system(size: 32))
            Text("아직 만든 카테고리가 없어요")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.gagaeText)
            Text("반려동물, 육아, 구독처럼 자주 쓰는 지출을\n카테고리로 만들어 보세요")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .foregroundStyle(.gagaeTextSecondary)
    }

    private func toastView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(.bottom, 100)
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    /// 추가·수정이 끝난 뒤: 목록을 다시 읽고 열린 다른 화면에 알린다.
    private func afterChange() {
        viewModel.load()
        eventBus.notifyCategoryChanged()
    }

    private func showToastBriefly() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { viewModel.toast = nil }
        }
    }
}

// MARK: - 줄바꿈 칩 배치

private struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
