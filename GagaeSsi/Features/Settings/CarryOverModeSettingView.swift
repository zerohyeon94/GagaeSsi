//
//  CarryOverModeSettingView.swift
//  GagaeSsi
//
//  이월 방식 선택 (전액 이월 / 모아둔 이월금 분리)
//

import SwiftUI

struct CarryOverModeSettingView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var selected: CarryOverMode = .full

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    infoCard
                    optionCard(.full,
                               emoji: "📥",
                               title: "전액 이월",
                               desc: "전날 남은 금액(그리고 초과분)을 다음 날 '오늘 쓸 수 있는 금액'에 모두 반영해요. 기본 방식이에요.")
                    optionCard(.separate,
                               emoji: "🐷",
                               title: "모아둔 이월금으로 분리",
                               desc: "남은 돈은 오늘 예산에 더하지 않고 '모아둔 이월금'으로 따로 쌓여요. 필요할 때 꺼내 쓰고, 과소비한 날은 다음 날 예산에서 차감돼요.")
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("이월 방식")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .onAppear {
            selected = CoreDataManager.shared.fetchBudgetConfig()?.carryOverMode ?? .full
        }
    }

    private var infoCard: some View {
        HStack(spacing: GagaeSpacing.md) {
            Image(systemName: "lightbulb.fill").font(.system(size: 20)).foregroundStyle(.gagaePoint)
            Text("변경하면 오늘부터 적용돼요.\n과거 기록과 이미 모아둔 이월금은 그대로 유지돼요.")
                .font(.gagaeSubheadline).foregroundStyle(.gagaeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(GagaeSpacing.md)
        .background(Color.gagaePoint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }

    private func optionCard(_ mode: CarryOverMode, emoji: String, title: String, desc: String) -> some View {
        Button {
            guard selected != mode else { return }
            selected = mode
            _ = CoreDataManager.shared.updateCarryOverMode(mode)
            eventBus.notifyBudgetChanged()
        } label: {
            HStack(alignment: .top, spacing: GagaeSpacing.md) {
                Text(emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.gagaeHeadline).foregroundStyle(.gagaeText)
                    Text(desc).font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: selected == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected == mode ? Color.gagaePinkDark : Color.gagaeDivider)
            }
            .padding(GagaeSpacing.md)
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
            .overlay(RoundedRectangle(cornerRadius: GagaeRadius.md)
                .stroke(selected == mode ? Color.gagaePinkDark : Color.clear, lineWidth: 2))
            .gagaeCardShadow()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { CarryOverModeSettingView() }
        .environment(AppEventBus())
}
