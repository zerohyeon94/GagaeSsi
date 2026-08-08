//
//  SettingsView.swift
//  GagaeSsi
//
//  설정 화면 (Claude Design 적용)
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @Environment(AppState.self) private var appState
    @Environment(AppEventBus.self) private var eventBus
    @State private var showConfirm = false
    @State private var showToast = false
    @State private var currentConfig: BudgetConfigModel?
    @State private var fixedCostsCount: Int = 0
    @State private var pigBreathing = false
    @State private var activeDebt: SpendingDebtModel?
    @State private var showMailUnavailable = false

    /// 상환 계획 행 우측 요약 (진행 중이면 남은 금액, 아니면 on/off)
    private var debtPlanRightText: String? {
        guard currentConfig?.debtPlanEnabled ?? true else { return "끔" }
        guard let activeDebt, activeDebt.isActive else { return nil }
        return FormatterUtils.currencyString(from: activeDebt.remainingAmount) + " 남음"
    }

    /// 소비 기록 알림 행 우측 요약 (켜져 있으면 알림 시각)
    private var spendReminderRightText: String? {
        guard let config = currentConfig, config.spendReminderEnabled else { return "끔" }
        let period = config.spendReminderHour < 12 ? "오전" : "오후"
        let hour12 = config.spendReminderHour % 12 == 0 ? 12 : config.spendReminderHour % 12
        return String(format: "%@ %d:%02d", period, hour12, config.spendReminderMinute)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: 0) {
                    largeTitle
                    profileCard
                        .padding(.bottom, 4)
                    budgetSection
                    notificationSection
                    dataSection
                    appInfoSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }

            // 초기화 확인 시트
            if showConfirm {
                confirmSheet
            }

            // 토스트
            if showToast {
                resetToast
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadConfig()
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                pigBreathing = true
            }
        }
        .onChange(of: eventBus.budgetChangedTrigger) { loadConfig() }
        .onChange(of: eventBus.fixedExpenseChangedTrigger) { loadConfig() }
        .onChange(of: eventBus.spendingAddedTrigger) { loadConfig() }
        .alert("메일 앱을 열 수 없어요", isPresented: $showMailUnavailable) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("기기에 메일 계정이 없는 것 같아요.\n\(FeedbackMail.supportEmail) 으로 직접 보내주셔도 됩니다.")
        }
    }

    private func loadConfig() {
        currentConfig = CoreDataManager.shared.fetchBudgetConfig()
        fixedCostsCount = CoreDataManager.shared.fetchFixedCosts().count
        activeDebt = CoreDataManager.shared.fetchActiveDebt()
    }

    /// 기본 메일 앱을 연다. 메일 계정이 없는 기기에서는 열리지 않으므로 안내한다.
    private func sendFeedback() {
        guard let url = FeedbackMail.url(), UIApplication.shared.canOpenURL(url) else {
            withAnimation { showMailUnavailable = true }
            return
        }
        UIApplication.shared.open(url)
    }

    private func handleReset() {
        CoreDataManager.shared.resetAllData()
        NotificationService.shared.cancelAllVariableCostReminders()
        NotificationService.shared.cancelAllSpendReminders()
        NotificationService.shared.cancelAllPaybackReminders()
        withAnimation { showConfirm = false }
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showToast = false }
            appState.resetSetup()
        }
    }
}

// MARK: - Header & Profile
extension SettingsView {
    private var largeTitle: some View {
        HStack {
            Text("설정")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.gagaeText)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var profileCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [.gagaePinkDark, .gagaePink],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .gagaeShadow(color: .gagaePinkDark.opacity(0.32), radius: 18, y: 14)

            // 장식 블롭
            GeometryReader { geo in
                Circle().fill(.white.opacity(0.09)).frame(width: 110, height: 110)
                    .offset(x: geo.size.width - 90, y: -36)
                Circle().fill(.white.opacity(0.06)).frame(width: 80, height: 80)
                    .offset(x: 80, y: geo.size.height - 52)
                Circle().fill(.white.opacity(0.11)).frame(width: 28, height: 28)
                    .offset(x: geo.size.width - 88, y: 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))

            HStack(spacing: 18) {
                ZStack {
                    Circle().fill(.white.opacity(0.20)).frame(width: 70, height: 70)
                    pigContent.font(.system(size: 36))
                }
                .scaleEffect(pigBreathing ? 1.06 : 1.0)

                VStack(alignment: .leading, spacing: 3) {
                    Text("가계씨")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if let config = currentConfig {
                        Text("월 " + FormatterUtils.currencyString(from: config.salary))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                        Text("매월 \(config.payday)일 급여 · 고정비 \(fixedCostsCount)개")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                    } else {
                        Text("설정이 필요합니다")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 110)
    }

    @ViewBuilder
    private var pigContent: some View {
        if UIImage(named: "characterPig") != nil {
            Image("characterPig").resizable().scaledToFit().frame(width: 46, height: 46)
        } else {
            Text("🐷")
        }
    }
}

// MARK: - Sections
extension SettingsView {
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
                .textCase(.uppercase)
                .kerning(0.7)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private var budgetSection: some View {
        VStack(spacing: 0) {
            sectionHeader("예산 설정")
            VStack(spacing: 0) {
                NavigationLink {
                    BudgetModeSettingView()
                } label: {
                    settingRow(iconBg: Color(hex: "#7A5AF8"), iconContent: AnyView(Text("🧭").font(.system(size: 15))),
                               label: "예산 방식",
                               rightText: currentConfig?.budgetMode.label)
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    EditBudgetView()
                } label: {
                    settingRow(iconBg: .gagaePinkDark, iconContent: AnyView(
                        Text("₩").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    ), label: "월급 & 급여일",
                    rightText: currentConfig.map { FormatterUtils.currencyString(from: $0.salary) },
                    disabled: currentConfig?.budgetMode != .recurring)
                }
                .buttonStyle(.plain)
                .disabled(currentConfig?.budgetMode != .recurring)

                rowDivider
                NavigationLink {
                    FixedExpenseListView()
                } label: {
                    settingRow(iconBg: Color(hex: "#5999FA"), iconContent: AnyView(Text("🔄").font(.system(size: 16))),
                               label: "고정비 관리",
                               rightText: fixedCostsCount > 0 ? "\(fixedCostsCount)개 항목" : "없음")
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    WishListView()
                } label: {
                    settingRow(iconBg: Color(hex: "#F49AC1"), iconContent: AnyView(Text("🎁").font(.system(size: 16))),
                               label: "위시리스트")
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    InstallmentListView()
                } label: {
                    settingRow(iconBg: Color(hex: "#5D65E8"), iconContent: AnyView(Text("💳").font(.system(size: 15))),
                               label: "할부 관리")
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    PaybackListView()
                } label: {
                    settingRow(iconBg: Color(hex: "#3FB98F"), iconContent: AnyView(Text("💸").font(.system(size: 15))),
                               label: "페이백 관리")
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    CarryOverModeSettingView()
                } label: {
                    settingRow(iconBg: Color(hex: "#7BC67B"), iconContent: AnyView(Text("💰").font(.system(size: 15))),
                               label: "이월 방식",
                               rightText: currentConfig?.carryOverMode.label)
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    DebtPlanSettingView()
                } label: {
                    settingRow(iconBg: Color(hex: "#E8735D"), iconContent: AnyView(Text("💪").font(.system(size: 15))),
                               label: "초과분 상환 계획",
                               rightText: debtPlanRightText)
                }
                .buttonStyle(.plain)
            }
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gagaeCardShadow()
        }
    }

    private var notificationSection: some View {
        VStack(spacing: 0) {
            sectionHeader("알림 · 화면")
            VStack(spacing: 0) {
                NavigationLink {
                    SpendReminderSettingView()
                } label: {
                    settingRow(iconBg: Color(hex: "#FFB03A"), iconContent: AnyView(Text("🔔").font(.system(size: 15))),
                               label: "소비 기록 알림",
                               rightText: spendReminderRightText)
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    ThemeSettingView()
                } label: {
                    settingRow(iconBg: Color(hex: "#6B7280"), iconContent: AnyView(Text("🌗").font(.system(size: 15))),
                               label: "화면 테마",
                               rightText: currentConfig?.themeMode.label)
                }
                .buttonStyle(.plain)
            }
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gagaeCardShadow()
        }
    }

    private var dataSection: some View {
        VStack(spacing: 0) {
            sectionHeader("데이터")
            VStack(spacing: 0) {
                NavigationLink {
                    SpendingTitleCleanupView()
                } label: {
                    settingRow(iconBg: Color(hex: "#9B8BF4"), iconContent: AnyView(Text("🏷️").font(.system(size: 15))),
                               label: "항목 이름 정리")
                }
                .buttonStyle(.plain)

                rowDivider
                NavigationLink {
                    DataExportView()
                } label: {
                    settingRow(iconBg: Color(hex: "#5BC8FA"), iconContent: AnyView(Text("📤").font(.system(size: 15))),
                               label: "데이터 내보내기", rightText: "CSV")
                }
                .buttonStyle(.plain)

                rowDivider
                Button {
                    withAnimation { showConfirm = true }
                } label: {
                    settingRow(iconBg: Color.gagaeDanger.opacity(0.13),
                               iconContent: AnyView(Text("🗑️").font(.system(size: 16))),
                               label: "데이터 초기화", danger: true)
                }
                .buttonStyle(.plain)
            }
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gagaeCardShadow()
        }
    }

    private var appInfoSection: some View {
        VStack(spacing: 0) {
            sectionHeader("앱 정보")
            VStack(spacing: 0) {
                Button {
                    sendFeedback()
                } label: {
                    settingRow(iconBg: Color(hex: "#8C73E5"), iconContent: AnyView(Text("✉️").font(.system(size: 16))),
                               label: "피드백 보내기")
                }
                .buttonStyle(.plain)

                rowDivider
                settingRow(iconBg: Color.gagaeTextTertiary, iconContent: AnyView(Text("ℹ️").font(.system(size: 15))),
                           label: "버전", rightText: appVersion, showChevron: false)
            }
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gagaeCardShadow()

            Text("🐷 가계씨가 여러분의 지갑을 지켜요")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.gagaeTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .padding(.bottom, 8)
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 60)
    }

    private func settingRow(iconBg: Color, iconContent: AnyView, label: String,
                            rightText: String? = nil, showChevron: Bool = true,
                            disabled: Bool = false, danger: Bool = false) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconBg)
                .frame(width: 32, height: 32)
                .overlay(iconContent)
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(danger ? .gagaeDanger : .gagaeText)
            Spacer()
            if let rightText {
                Text(rightText)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(danger ? Color.gagaeDanger : Color.gagaeTextTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        // 행 전체(텍스트~chevron 사이 빈 영역 포함)를 탭 영역으로 만든다.
        // Spacer 빈 공간이 히트 테스트에서 빠져 "텍스트만 눌려야 동작"하던 버그 수정.
        .contentShape(Rectangle())
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - Reset Sheet & Toast
extension SettingsView {
    private var confirmSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { withAnimation { showConfirm = false } }

            VStack(spacing: 0) {
                Capsule().fill(Color.gagaeDivider).frame(width: 36, height: 4)
                    .padding(.top, 8).padding(.bottom, 20)

                Text("🗑️").font(.system(size: 36)).padding(.bottom, 10)
                Text("데이터를 초기화할까요?")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.gagaeText)
                    .padding(.bottom, 6)
                Text("모든 소비 기록과 예산 설정이\n영구적으로 삭제됩니다.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 22)

                Button {
                    handleReset()
                } label: {
                    Text("초기화하기")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.gagaeDanger)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .gagaeShadow(color: .gagaeDanger.opacity(0.30), radius: 10, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)

                Button {
                    withAnimation { showConfirm = false }
                } label: {
                    Text("취소")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaeText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.gagaeSurfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
            .background(Color.gagaeCardBackground)
            .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
            .transition(.move(edge: .bottom))
        }
        .ignoresSafeArea()
    }

    private var resetToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.gagaeGood).frame(width: 28, height: 28)
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
                Text("데이터가 초기화되었어요")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.black.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

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
