//
//  ThemeSettingView.swift
//  GagaeSsi
//
//  화면 테마 설정 (기기 설정 / 밝게 / 어둡게)
//

import SwiftUI

struct ThemeSettingView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var mode: ThemeMode = .system

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    optionsCard
                    previewCard
                    noteCard
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("화면 테마")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { mode = CoreDataManager.shared.fetchBudgetConfig()?.themeMode ?? .system }
    }

    private var optionsCard: some View {
        VStack(spacing: 0) {
            ForEach(ThemeMode.allCases) { option in
                Button {
                    select(option)
                } label: {
                    HStack(spacing: 12) {
                        Text(option.emoji).font(.system(size: 18)).frame(width: 26)
                        Text(option.label)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.gagaeText)
                        Spacer()
                        if mode == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.gagaePinkDark)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if option != ThemeMode.allCases.last {
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 54)
                }
            }
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    /// 지금 화면이 어떻게 보이는지 바로 확인할 수 있게 대표 요소를 모아둔다
    private var previewCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("미리보기").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)

                HStack(spacing: GagaeSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.gagaeBudgetCardTop, .gagaeBudgetCardBottom],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 96, height: 62)
                        VStack(spacing: 1) {
                            Text("오늘 쓸 수 있는")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("₩38,000")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Circle().fill(Color.gagaeGood).frame(width: 7, height: 7)
                            Text("여유").font(.gagaeCaption).foregroundStyle(.gagaeGood)
                            Circle().fill(Color.gagaeWarning).frame(width: 7, height: 7)
                            Text("조심").font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                            Circle().fill(Color.gagaeDanger).frame(width: 7, height: 7)
                            Text("걱정").font(.gagaeCaption).foregroundStyle(.gagaeDanger)
                        }
                        Text("본문 글자")
                            .font(.gagaeFootnote).foregroundStyle(.gagaeText)
                        Text("보조 설명 글자")
                            .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        Text("칩 예시")
                            .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color.gagaeSurfaceAlt).clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var noteCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("‘기기 설정’을 고르면 iOS의 라이트/다크 설정을 그대로 따라가요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("가계씨는 원래 밝은 화면으로 고정돼 있었어요. 익숙한 화면을 그대로 쓰고 싶으면 ‘밝게’를 고르면 돼요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func select(_ option: ThemeMode) {
        mode = option
        CoreDataManager.shared.updateThemeMode(option)
        eventBus.notifyBudgetChanged()   // RootView가 즉시 반영
    }
}

#Preview {
    NavigationStack { ThemeSettingView() }
        .environment(AppEventBus())
}
