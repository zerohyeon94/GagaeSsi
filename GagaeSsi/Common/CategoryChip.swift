//
//  CategoryChip.swift
//  GagaeSsi
//
//  카테고리 칩 공용 컴포넌트 — 소비 기록·내역 수정·페이백·카테고리 편집 미리보기가 같이 쓴다.
//

import SwiftUI

struct CategoryChip: View {
    enum Style {
        /// 선택 시 카테고리 색 배경
        case normal
        /// 선택 시 gagaePinkDark 배경 (페이백 화면의 다른 선택 요소와 맞춘다)
        case payback
    }

    /// nil이면 이모지 칸을 두지 않는다 ('안 씀' 칩)
    let emoji: String?
    let name: String
    let color: Color
    let isSelected: Bool
    var style: Style = .normal
    /// nil이면 버튼이 아닌 표시 전용 칩 (미리보기)
    var action: (() -> Void)?

    init(emoji: String?, name: String, color: Color, isSelected: Bool,
         style: Style = .normal, action: (() -> Void)? = nil) {
        self.emoji = emoji
        self.name = name
        self.color = color
        self.isSelected = isSelected
        self.style = style
        self.action = action
    }

    init(info: CategoryInfo, isSelected: Bool, style: Style = .normal, action: (() -> Void)? = nil) {
        self.init(emoji: info.emoji, name: info.name, color: info.color,
                  isSelected: isSelected, style: style, action: action)
    }

    var body: some View {
        if let action {
            Button(action: action) { chipBody }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: isSelected)
                .accessibilityLabel(name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            chipBody
        }
    }

    private var selectedFill: Color {
        style == .payback ? .gagaePinkDark : color
    }

    private var chipBody: some View {
        HStack(spacing: 5) {
            if let emoji {
                // 이모지 칸은 고정 폭 — 옛 데이터나 예외 값이 와도 칩 모양이 흔들리지 않게 한다
                Text(emoji.isEmpty ? UserCategoryRules.defaultEmoji : emoji)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .frame(width: 18)
                    .clipped()
            }
            Text(name)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color.gagaeTextSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(isSelected ? selectedFill : Color.gagaeSurfaceAlt)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(isSelected ? Color.clear : Color.gagaeDivider, lineWidth: 1.5)
        )
    }
}

/// 소비 기록 칩 줄 끝의 '＋ 추가' 칩 (점선 테두리)
struct CategoryAddChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("추가")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.gagaePinkDark)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .overlay(
                Capsule().strokeBorder(Color.gagaePinkDark,
                                       style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("추가")
        .accessibilityHint("새 카테고리 만들기")
    }
}
