//
//  DesignSystem.swift
//  GagaeSsi
//
//  앱 전체 디자인 시스템 - 색상, 타이포그래피, 컴포넌트
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    // 주요 색상 (분홍 계열 - 돼지 테마)
    static let gagaePink = Color(red: 1.0, green: 0.686, blue: 0.686)
    static let gagaePinkDark = Color(red: 0.96, green: 0.44, blue: 0.55)
    static let gagaePinkLight = Color(red: 1.0, green: 0.88, blue: 0.90)

    // 포인트 색상
    static let gagaePoint = Color(red: 1.0, green: 0.843, blue: 0.4)
    static let gagaePointDark = Color(red: 0.96, green: 0.75, blue: 0.15)

    // 상태 색상
    static let gagaeGood = Color(red: 0.35, green: 0.78, blue: 0.55)      // 초록 - 여유
    static let gagaeWarning = Color(red: 1.0, green: 0.65, blue: 0.20)    // 주황 - 주의
    static let gagaeDanger = Color(red: 0.95, green: 0.35, blue: 0.35)    // 빨강 - 위험

    // 배경 색상
    static let gagaeBackground = Color(UIColor.systemBackground)
    static let gagaeCardBackground = Color(UIColor.secondarySystemBackground)
    static let gagaeSurface = Color(UIColor.tertiarySystemBackground)

    // 텍스트 색상
    static let gagaeText = Color(UIColor.label)
    static let gagaeTextSecondary = Color(UIColor.secondaryLabel)
    static let gagaeTextTertiary = Color(UIColor.tertiaryLabel)

    // 구분선
    static let gagaeDivider = Color(UIColor.separator)

    // 배경 그라디언트용
    static let gagaePinkGradientTop = Color(red: 1.0, green: 0.92, blue: 0.94)
    static let gagaePinkGradientBottom = Color(red: 0.98, green: 0.97, blue: 1.0)
}

extension ShapeStyle where Self == Color {
    // 주요 색상
    static var gagaePink: Color { .gagaePink }
    static var gagaePinkDark: Color { .gagaePinkDark }
    static var gagaePinkLight: Color { .gagaePinkLight }

    // 포인트 색상
    static var gagaePoint: Color { .gagaePoint }
    static var gagaePointDark: Color { .gagaePointDark }

    // 상태 색상
    static var gagaeGood: Color { .gagaeGood }
    static var gagaeWarning: Color { .gagaeWarning }
    static var gagaeDanger: Color { .gagaeDanger }

    // 배경 색상
    static var gagaeBackground: Color { .gagaeBackground }
    static var gagaeCardBackground: Color { .gagaeCardBackground }
    static var gagaeSurface: Color { .gagaeSurface }

    // 텍스트 색상
    static var gagaeText: Color { .gagaeText }
    static var gagaeTextSecondary: Color { .gagaeTextSecondary }
    static var gagaeTextTertiary: Color { .gagaeTextTertiary }

    // 구분선
    static var gagaeDivider: Color { .gagaeDivider }

    // 배경 그라디언트용
    static var gagaePinkGradientTop: Color { .gagaePinkGradientTop }
    static var gagaePinkGradientBottom: Color { .gagaePinkGradientBottom }
}

// MARK: - Typography

extension Font {
    // 타이틀
    static let gagaeLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let gagaeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let gagaeTitle2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let gagaeTitle3 = Font.system(size: 20, weight: .semibold, design: .rounded)

    // 본문
    static let gagaeHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let gagaeBody = Font.system(size: 17, weight: .regular, design: .rounded)
    static let gagaeBodyMedium = Font.system(size: 17, weight: .medium, design: .rounded)

    // 보조
    static let gagaeCallout = Font.system(size: 16, weight: .regular, design: .rounded)
    static let gagaeCalloutMedium = Font.system(size: 16, weight: .medium, design: .rounded)
    static let gagaeSubheadline = Font.system(size: 15, weight: .regular, design: .rounded)
    static let gagaeFootnote = Font.system(size: 13, weight: .regular, design: .rounded)
    static let gagaeCaption = Font.system(size: 12, weight: .regular, design: .rounded)
    static let gagaeCaptionMedium = Font.system(size: 12, weight: .medium, design: .rounded)

    // 금액 표시 전용
    static let gagaeAmountLarge = Font.system(size: 40, weight: .bold, design: .rounded)
    static let gagaeAmountMedium = Font.system(size: 24, weight: .bold, design: .rounded)
    static let gagaeAmountSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
}

// MARK: - Spacing

enum GagaeSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum GagaeRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let full: CGFloat = 100
}

// MARK: - Shadow

struct GagaeShadow: ViewModifier {
    var color: Color = .black.opacity(0.08)
    var radius: CGFloat = 12
    var x: CGFloat = 0
    var y: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius, x: x, y: y)
    }
}

extension View {
    func gagaeShadow(color: Color = .black.opacity(0.08), radius: CGFloat = 12, x: CGFloat = 0, y: CGFloat = 4) -> some View {
        modifier(GagaeShadow(color: color, radius: radius, x: x, y: y))
    }

    func gagaeCardShadow() -> some View {
        modifier(GagaeShadow(color: Color.gagaePink.opacity(0.2), radius: 16, x: 0, y: 6))
    }
}

// MARK: - Budget Status

enum BudgetStatus {
    case good       // 여유 (50% 이상)
    case warning    // 주의 (20~50%)
    case critical   // 위험 (0~20%)
    case empty      // 소진 (0 이하)

    var color: Color {
        switch self {
        case .good: return .gagaeGood
        case .warning: return .gagaeWarning
        case .critical: return .gagaeDanger
        case .empty: return .gagaeDanger
        }
    }

    var pigMood: String {
        switch self {
        case .good: return "🐷"
        case .warning: return "😰"
        case .critical: return "😱"
        case .empty: return "😵"
        }
    }

    var message: String {
        switch self {
        case .good: return "오늘도 가게씨가 지켜볼게요!"
        case .warning: return "슬슬 줄여볼까요?"
        case .critical: return "조심해요, 거의 다 썼어요!"
        case .empty: return "오늘은 여기까지예요..."
        }
    }

    static func from(available: Int, base: Int) -> BudgetStatus {
        guard base > 0 else { return available <= 0 ? .empty : .good }
        let ratio = Double(available) / Double(base)
        if available <= 0 { return .empty }
        if ratio < 0.2 { return .critical }
        if ratio < 0.5 { return .warning }
        return .good
    }
}

// MARK: - Reusable Components

/// 기본 카드 컨테이너
struct GagaeCard<Content: View>: View {
    var content: Content
    var padding: CGFloat = GagaeSpacing.md
    var cornerRadius: CGFloat = GagaeRadius.lg
    var backgroundColor: Color = .gagaeCardBackground

    init(padding: CGFloat = GagaeSpacing.md,
         cornerRadius: CGFloat = GagaeRadius.lg,
         backgroundColor: Color = .gagaeCardBackground,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .gagaeShadow()
    }
}

/// 주요 액션 버튼
struct GagaePrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.gagaeHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    isEnabled
                        ? LinearGradient(colors: [.gagaePinkDark, .gagaePink], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.full))
                .gagaeShadow(color: isEnabled ? .gagaePink.opacity(0.4) : .clear, radius: 8, y: 4)
        }
        .disabled(!isEnabled)
    }
}

/// 보조 액션 버튼
struct GagaeSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.gagaeCalloutMedium)
                .foregroundStyle(.gagaePinkDark)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.gagaePinkLight)
                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.full))
        }
    }
}

/// 구분선
struct GagaeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.gagaeDivider)
            .frame(height: 0.5)
    }
}

/// 섹션 헤더
struct GagaeSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.gagaeFootnote)
                .foregroundStyle(Color.gagaeTextSecondary)
                .textCase(.uppercase)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.gagaeFootnote)
                    .foregroundStyle(.gagaePinkDark)
            }
        }
        .padding(.horizontal, GagaeSpacing.md)
        .padding(.top, GagaeSpacing.sm)
    }
}

/// 금액 입력 필드
struct GagaeAmountField: View {
    let placeholder: String
    @Binding var text: String
    var onChange: ((String) -> Void)? = nil
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(spacing: GagaeSpacing.sm) {
            Text("₩")
                .font(.gagaeTitle3)
                .foregroundStyle(.gagaePinkDark)

            TextField(placeholder, text: $text)
                .font(.gagaeTitle3)
                .keyboardType(.numberPad)
                .focused($focused)
                .onChange(of: text) { _, newValue in
                    onChange?(newValue)
                }
        }
        .padding(.horizontal, GagaeSpacing.md)
        .padding(.vertical, GagaeSpacing.md)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: GagaeRadius.md)
                .stroke(focused ? Color.gagaePinkDark : Color.gagaeDivider, lineWidth: focused ? 2 : 0.5)
        )
    }
}

/// 텍스트 입력 필드
struct GagaeTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState.Binding var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.gagaeBody)
            .keyboardType(keyboardType)
            .focused($focused)
            .padding(.horizontal, GagaeSpacing.md)
            .padding(.vertical, GagaeSpacing.md)
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: GagaeRadius.md)
                    .stroke(focused ? Color.gagaePinkDark : Color.gagaeDivider, lineWidth: focused ? 2 : 0.5)
            )
    }
}

/// 빈 상태 뷰
struct GagaeEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: GagaeSpacing.md) {
            Text(icon)
                .font(.system(size: 48))

            Text(title)
                .font(.gagaeHeadline)
                .foregroundStyle(.gagaeText)

            Text(subtitle)
                .font(.gagaeSubheadline)
                .foregroundStyle(.gagaeTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(GagaeSpacing.xl)
    }
}

/// 배경 그라디언트
struct GagaeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.gagaePinkGradientTop, .gagaePinkGradientBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
