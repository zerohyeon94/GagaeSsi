//
//  SpendingTitleCleanupView.swift
//  GagaeSsi
//
//  소비 항목 이름 정리 — 갈라진 표기를 하나로 합친다.
//

import SwiftUI

struct SpendingTitleCleanupView: View {
    @Environment(AppEventBus.self) private var eventBus

    @State private var stats: [SpendingTitleStat] = []
    @State private var duplicateGroups: [SpendingTitleGroup] = []
    @State private var similarGroups: [SpendingTitleGroup] = []
    @State private var selected: Set<String> = []          // 소문자 제목 키
    @State private var pendingMerge: PendingMerge?
    @State private var toast: String?

    /// 합치기 확인용
    private struct PendingMerge: Identifiable {
        var id: String { titles.joined(separator: "|") }
        let titles: [String]
        let suggestedName: String
    }

    private var selectedStats: [SpendingTitleStat] {
        stats.filter { selected.contains($0.id) }
    }
    private var selectedRecordCount: Int {
        selectedStats.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    introCard
                    if !duplicateGroups.isEmpty { groupSection(duplicateGroups) }
                    if !similarGroups.isEmpty { groupSection(similarGroups) }
                    allTitlesCard
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.top, GagaeSpacing.md)
                .padding(.bottom, selected.isEmpty ? GagaeSpacing.md : 90)
            }

            if !selected.isEmpty { actionBar }
            if let toast { toastView(toast) }
        }
        .navigationTitle("항목 이름 정리")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .sheet(item: $pendingMerge) { merge in
            TitleMergeSheet(titles: merge.titles,
                            suggestedName: merge.suggestedName,
                            stats: stats) { newName in
                apply(titles: merge.titles, to: newName)
            }
        }
    }

    // MARK: - 안내

    private var introCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("같은 가게를 다르게 적어 갈라진 기록을 하나로 합쳐요.")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("이름만 바뀌어요. 금액·날짜·카테고리는 그대로라 예산이나 이월에는 영향이 없어요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 자동 감지 묶음

    private func groupSection(_ groups: [SpendingTitleGroup]) -> some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            let isDuplicate = groups.first?.kind == .duplicate
            Text(isDuplicate ? "합칠 수 있어요 (표기만 다름)" : "비슷한 이름이에요")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
                .padding(.horizontal, 4)

            if !isDuplicate {
                Text("이름이 겹치지만 다른 항목일 수도 있어요. 확인하고 합쳐주세요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                    .padding(.horizontal, 4)
            }

            ForEach(groups) { group in
                GagaeCard {
                    VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                        ForEach(group.stats) { stat in
                            HStack(spacing: 8) {
                                Text("•").foregroundStyle(.gagaeTextTertiary)
                                Text(stat.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.gagaeText).lineLimit(1)
                                Spacer()
                                Text("\(stat.count)건 · \(FormatterUtils.currencyString(from: stat.total))")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.gagaeTextSecondary)
                            }
                        }

                        GagaeDivider()

                        HStack {
                            Text("→ \(group.suggestedName)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.gagaePinkDark).lineLimit(1)
                            Spacer()
                            Button {
                                pendingMerge = PendingMerge(titles: group.stats.map(\.title),
                                                            suggestedName: group.suggestedName)
                            } label: {
                                Text("합치기")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Color.gagaePinkDark).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 전체 항목

    private var allTitlesCard: some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            Text("전체 항목 \(stats.count)개")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
                .padding(.horizontal, 4)

            if stats.isEmpty {
                GagaeCard {
                    Text("아직 소비 기록이 없어요")
                        .font(.gagaeCallout).foregroundStyle(.gagaeTextTertiary)
                        .frame(maxWidth: .infinity).padding(.vertical, GagaeSpacing.md)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(stats) { stat in
                        titleRow(stat)
                        if stat.id != stats.last?.id {
                            Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 48)
                        }
                    }
                }
                .background(Color.gagaeCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .gagaeCardShadow()
            }
        }
    }

    private func titleRow(_ stat: SpendingTitleStat) -> some View {
        let isSelected = selected.contains(stat.id)
        return Button {
            if isSelected { selected.remove(stat.id) } else { selected.insert(stat.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Color.gagaePinkDark : Color.gagaeDivider)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaeText).lineLimit(1)
                    Text("\(stat.count)건 · \(FormatterUtils.currencyString(from: stat.total))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 하단 액션

    private var actionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Button {
                    selected.removeAll()
                } label: {
                    Text("취소")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                        .frame(height: 50).padding(.horizontal, 20)
                        .background(Color.gagaeCardBackground).clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    let titles = selectedStats.map(\.title)
                    let suggested = selectedStats.max {
                        $0.count != $1.count ? $0.count < $1.count : $0.lastDate < $1.lastDate
                    }?.title ?? titles.first ?? ""
                    pendingMerge = PendingMerge(titles: titles, suggestedName: suggested)
                } label: {
                    Text(selected.count == 1
                         ? "이름 바꾸기 (\(selectedRecordCount)건)"
                         : "\(selected.count)개 합치기 (\(selectedRecordCount)건)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.gagaePinkDark).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, GagaeSpacing.md)
            .padding(.bottom, GagaeSpacing.md)
        }
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

    private func load() {
        let records = CoreDataManager.shared.fetchAllSpendingRecords()
        stats = SpendingTitleCleanup.titleStats(from: records)
        duplicateGroups = SpendingTitleCleanup.duplicateGroups(from: stats)
        similarGroups = SpendingTitleCleanup.similarGroups(from: stats)
        selected.removeAll()
    }

    private func apply(titles: [String], to newName: String) {
        let changed = CoreDataManager.shared.renameSpendingTitles(matching: titles, to: newName)
        load()
        eventBus.notifySpendingAdded()

        withAnimation { toast = changed > 0 ? "\(changed)건을 '\(newName)'으로 바꿨어요" : "바뀐 기록이 없어요" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - 합치기 확인 시트

private struct TitleMergeSheet: View {
    let titles: [String]
    let suggestedName: String
    let stats: [SpendingTitleStat]
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var focused: Bool

    private var affectedCount: Int {
        let keys = Set(titles.map { $0.lowercased() })
        return stats.filter { keys.contains($0.title.lowercased()) }
                    .reduce(0) { $0 + $1.count }
    }
    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: GagaeSpacing.md) {
                        GagaeCard {
                            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                                Text("바꿀 항목 \(titles.count)개 · \(affectedCount)건")
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                ForEach(titles, id: \.self) { title in
                                    Text("• \(title)")
                                        .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        GagaeCard {
                            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                                Text("새 이름")
                                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                TextField("항목 이름", text: $name)
                                    .font(.gagaeCalloutMedium)
                                    .focused($focused)
                                    .padding(GagaeSpacing.md)
                                    .background(Color.gagaeSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                                    .overlay(RoundedRectangle(cornerRadius: GagaeRadius.md)
                                        .stroke(focused ? Color.gagaePinkDark : Color.gagaeDivider,
                                                lineWidth: focused ? 2 : 0.5))

                                // 후보 중에서 빠르게 고르기
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: GagaeSpacing.sm) {
                                        ForEach(titles, id: \.self) { title in
                                            Button { name = title } label: {
                                                Text(title)
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundStyle(name == title ? .white : Color.gagaeTextSecondary)
                                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                                    .background(name == title
                                                                ? AnyShapeStyle(Color.gagaePinkDark)
                                                                : AnyShapeStyle(Color.gagaeSurface))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }

                                Text("⚠️ 되돌릴 수 없어요. 이전 이름은 남지 않아요.")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                            }
                        }

                        GagaePrimaryButton(title: "\(affectedCount)건 바꾸기", isEnabled: !trimmed.isEmpty) {
                            onConfirm(trimmed)
                            dismiss()
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.vertical, GagaeSpacing.md)
                }
            }
            .navigationTitle("이름 바꾸기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear { name = suggestedName }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack { SpendingTitleCleanupView() }
        .environment(AppEventBus())
}
