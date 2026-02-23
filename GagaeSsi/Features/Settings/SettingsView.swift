//
//  SettingsView.swift
//  GagaeSsi
//
//  설정 화면
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @Environment(AppState.self) private var appState
    @Environment(AppEventBus.self) private var eventBus
    @State private var showResetAlert = false
    @State private var currentConfig: BudgetConfigModel?
    @State private var fixedCostsCount: Int = 0

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    // 프로필 카드
                    profileCard
                        .padding(.top, GagaeSpacing.md)

                    // 예산 설정 섹션
                    budgetSection

                    // 데이터 섹션
                    dataSection

                    // 앱 정보 섹션
                    appInfoSection

                    Spacer(minLength: GagaeSpacing.xl)
                }
                .padding(.horizontal, GagaeSpacing.md)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadConfig()
        }
        .onChange(of: eventBus.budgetChangedTrigger) {
            loadConfig()
        }
        .onChange(of: eventBus.fixedExpenseChangedTrigger) {
            loadConfig()
        }
        .alert("데이터 초기화", isPresented: $showResetAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                CoreDataManager.shared.resetAllData()
                appState.resetSetup()
            }
        } message: {
            Text("모든 데이터가 삭제되고 초기 설정 화면으로 이동합니다.\n계속하시겠습니까?")
        }
    }

    private func loadConfig() {
        currentConfig = CoreDataManager.shared.fetchBudgetConfig()
        fixedCostsCount = CoreDataManager.shared.fetchFixedCosts().count
    }
}

// MARK: - Subviews
extension SettingsView {

    /// 프로필 카드 (현재 예산 요약)
    private var profileCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GagaeRadius.xxl)
                .fill(
                    LinearGradient(
                        colors: [Color.gagaePinkDark, Color.gagaePink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .gagaeCardShadow()

            HStack(spacing: GagaeSpacing.md) {
                // 돼지 아이콘
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 70, height: 70)

                    if UIImage(named: "characterPig") != nil {
                        Image("characterPig")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                    } else {
                        Text("🐷")
                            .font(.system(size: 38))
                    }
                }

                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Text("가계씨")
                        .font(.gagaeTitle3)
                        .foregroundStyle(.white)

                    if let config = currentConfig {
                        Text("월 \(FormatterUtils.currencyString(from: config.salary))")
                            .font(.gagaeCalloutMedium)
                            .foregroundStyle(.white.opacity(0.9))

                        Text("매월 \(config.payday)일 급여 · 고정비 \(fixedCostsCount)개")
                            .font(.gagaeCaption)
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        Text("설정이 필요합니다")
                            .font(.gagaeCallout)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                Spacer()
            }
            .padding(GagaeSpacing.lg)
        }
        .frame(height: 110)
    }

    /// 예산 설정 섹션
    private var budgetSection: some View {
        VStack(spacing: GagaeSpacing.sm) {
            GagaeSectionHeader(title: "예산 설정")

            GagaeCard(padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink {
                        EditBudgetView()
                    } label: {
                        settingRow(
                            icon: "wonsign.circle.fill",
                            iconColor: .gagaePinkDark,
                            title: "월급 & 급여일",
                            value: currentConfig.map { FormatterUtils.currencyString(from: $0.salary) }
                        )
                    }
                    .buttonStyle(.plain)

                    GagaeDivider()
                        .padding(.leading, 56)

                    NavigationLink {
                        FixedExpenseListView()
                    } label: {
                        settingRow(
                            icon: "repeat.circle.fill",
                            iconColor: Color(red: 0.35, green: 0.60, blue: 0.98),
                            title: "고정비 관리",
                            value: fixedCostsCount > 0 ? "\(fixedCostsCount)개 항목" : "없음"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 데이터 섹션
    private var dataSection: some View {
        VStack(spacing: GagaeSpacing.sm) {
            GagaeSectionHeader(title: "데이터")

            GagaeCard(padding: 0) {
                VStack(spacing: 0) {
                    Button {
                        // TODO: 백업 기능
                    } label: {
                        settingRow(
                            icon: "icloud.and.arrow.up.fill",
                            iconColor: Color(red: 0.20, green: 0.65, blue: 0.90),
                            title: "데이터 백업",
                            value: "준비 중",
                            isDisabled: true
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(true)

                    GagaeDivider()
                        .padding(.leading, 56)

                    Button {
                        showResetAlert = true
                    } label: {
                        settingRow(
                            icon: "trash.circle.fill",
                            iconColor: .gagaeDanger,
                            title: "데이터 초기화",
                            titleColor: .gagaeDanger
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 앱 정보 섹션
    private var appInfoSection: some View {
        VStack(spacing: GagaeSpacing.sm) {
            GagaeSectionHeader(title: "앱 정보")

            GagaeCard(padding: 0) {
                VStack(spacing: 0) {
                    Button {
                        // TODO: 피드백
                    } label: {
                        settingRow(
                            icon: "envelope.circle.fill",
                            iconColor: Color(red: 0.48, green: 0.36, blue: 0.90),
                            title: "피드백 보내기",
                            value: "준비 중",
                            isDisabled: true
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(true)

                    GagaeDivider()
                        .padding(.leading, 56)

                    settingRow(
                        icon: "info.circle.fill",
                        iconColor: .gagaeTextSecondary,
                        title: "버전",
                        value: appVersion,
                        showChevron: false
                    )
                }
            }

            // 앱 서명
            Text("🐷 가계씨가 여러분의 지갑을 지켜요")
                .font(.gagaeCaption)
                .foregroundStyle(.gagaeTextTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, GagaeSpacing.sm)
        }
    }

    /// 공통 설정 행
    private func settingRow(
        icon: String,
        iconColor: Color,
        title: String,
        titleColor: Color = .gagaeText,
        value: String? = nil,
        showChevron: Bool = true,
        isDisabled: Bool = false
    ) -> some View {
        HStack(spacing: GagaeSpacing.sm) {
            // 아이콘
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(isDisabled ? iconColor.opacity(0.4) : iconColor)
                .frame(width: 32, height: 32)

            // 타이틀
            Text(title)
                .font(.gagaeCalloutMedium)
                .foregroundStyle(isDisabled ? titleColor.opacity(0.4) : titleColor)

            Spacer()

            // 값 / 화살표
            if let value = value {
                Text(value)
                    .font(.gagaeCaption)
                    .foregroundStyle(.gagaeTextSecondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.gagaeTextTertiary)
            }
        }
        .padding(.horizontal, GagaeSpacing.md)
        .padding(.vertical, GagaeSpacing.md)
    }
}

// MARK: - Helpers
extension SettingsView {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
    .environment(AppEventBus())
}
