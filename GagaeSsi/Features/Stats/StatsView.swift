//
//  StatsView.swift
//  GagaeSsi
//
//  통계 화면
//

import SwiftUI

struct StatsView: View {
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    // 준비 중 카드
                    comingSoonCard
                        .padding(.top, GagaeSpacing.md)

                    // 미리보기 카드들
                    previewCards

                    Spacer(minLength: GagaeSpacing.xl)
                }
                .padding(.horizontal, GagaeSpacing.md)
            }
        }
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Subviews
extension StatsView {

    /// 준비 중 메인 카드
    private var comingSoonCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GagaeRadius.xxl)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.6, green: 0.47, blue: 0.98), Color(red: 0.48, green: 0.36, blue: 0.90)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .gagaeCardShadow()

            // 장식 원
            GeometryReader { geo in
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .offset(x: geo.size.width - 50, y: -30)
            }

            VStack(spacing: GagaeSpacing.md) {
                Text("📊")
                    .font(.system(size: 56))

                VStack(spacing: GagaeSpacing.sm) {
                    Text("통계 기능 준비 중")
                        .font(.gagaeTitle2)
                        .foregroundStyle(.white)

                    Text("곧 가계씨가 여러분의\n소비 패턴을 분석해드릴게요!")
                        .font(.gagaeSubheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: GagaeSpacing.xs) {
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(GagaeSpacing.xl)
        }
        .frame(height: 240)
    }

    /// 미리보기 기능 카드들
    private var previewCards: some View {
        VStack(spacing: GagaeSpacing.md) {
            Text("앞으로 이런 기능이 추가돼요")
                .font(.gagaeHeadline)
                .foregroundStyle(.gagaeText)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: GagaeSpacing.sm) {
                ForEach(upcomingFeatures, id: \.title) { feature in
                    featurePreviewCard(feature: feature)
                }
            }
        }
    }

    private func featurePreviewCard(feature: UpcomingFeature) -> some View {
        GagaeCard(backgroundColor: feature.backgroundColor) {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text(feature.icon)
                    .font(.system(size: 32))

                Text(feature.title)
                    .font(.gagaeCalloutMedium)
                    .foregroundStyle(.gagaeText)

                Text(feature.description)
                    .font(.gagaeCaption)
                    .foregroundStyle(.gagaeTextSecondary)
                    .lineLimit(2)

                HStack {
                    Spacer()
                    Text("준비 중")
                        .font(.gagaeCaption)
                        .foregroundStyle(.gagaeTextTertiary)
                        .padding(.horizontal, GagaeSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.gagaeDivider)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Data
extension StatsView {
    struct UpcomingFeature {
        let icon: String
        let title: String
        let description: String
        let backgroundColor: Color
    }

    private var upcomingFeatures: [UpcomingFeature] {
        [
            UpcomingFeature(
                icon: "📅",
                title: "월별 소비",
                description: "한 달 동안 얼마나 썼는지 한눈에",
                backgroundColor: Color(red: 0.95, green: 0.93, blue: 1.0)
            ),
            UpcomingFeature(
                icon: "🏷️",
                title: "카테고리별",
                description: "어디에 가장 많이 쓰는지 분석",
                backgroundColor: Color(red: 0.93, green: 0.97, blue: 1.0)
            ),
            UpcomingFeature(
                icon: "📈",
                title: "절약 트렌드",
                description: "지난달 대비 얼마나 아꼈나요?",
                backgroundColor: Color(red: 0.93, green: 1.0, blue: 0.95)
            ),
            UpcomingFeature(
                icon: "🤖",
                title: "AI 피드백",
                description: "가계씨가 소비 패턴 조언을 드려요",
                backgroundColor: Color(red: 1.0, green: 0.95, blue: 0.88)
            )
        ]
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StatsView()
    }
}
