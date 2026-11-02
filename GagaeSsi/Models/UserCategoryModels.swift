//
//  UserCategoryModels.swift
//  GagaeSsi
//
//  사용자가 직접 만드는 소비 카테고리의 값 타입과 규칙.
//  기록·페이백은 기존 문자열 칸에 내장은 한글 이름("식비"), 사용자는 "user:<UUID>"를 저장한다.
//

import SwiftUI

// MARK: - 사용자 카테고리 모델

struct UserCategoryModel: Identifiable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var color: UserCategoryColor
    var createdAt: Date

    init(id: UUID = UUID(), name: String, emoji: String = UserCategoryRules.defaultEmoji,
         color: UserCategoryColor = .rose, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.createdAt = createdAt
    }

    /// CoreData Entity -> Model 변환 생성자. 모르는 colorKey는 첫 색(rose)으로 읽는다.
    init(entity: UserCategory) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        let emoji = entity.emoji ?? ""
        self.emoji = emoji.isEmpty ? UserCategoryRules.defaultEmoji : emoji
        self.color = UserCategoryColor(rawValue: entity.colorKey ?? "") ?? .rose
        self.createdAt = entity.createdAt ?? Date()
    }
}

// MARK: - 카테고리 키 (기록이 가리키는 카테고리)

enum CategoryKey: Hashable {
    case builtIn(SpendingCategory)
    case user(UUID)

    static let other = CategoryKey.builtIn(.other)
    static let userPrefix = "user:"

    /// 저장된 문자열을 키로 읽는다. 모르는 값·깨진 "user:"는 기타.
    init(storageValue: String?) {
        guard let raw = storageValue, !raw.isEmpty else {
            self = .other
            return
        }
        if raw.hasPrefix(CategoryKey.userPrefix) {
            let idString = String(raw.dropFirst(CategoryKey.userPrefix.count))
            if let id = UUID(uuidString: idString) {
                self = .user(id)
            } else {
                self = .other
            }
            return
        }
        self = .builtIn(SpendingCategory.from(rawValue: raw))
    }

    /// 저장용 문자열
    var storageValue: String {
        switch self {
        case .builtIn(let category): return category.rawValue
        case .user(let id): return CategoryKey.userPrefix + id.uuidString
        }
    }
}

// MARK: - 표시 정보

/// 화면이 읽는 표시 정보 — 내장/사용자를 구분하지 않고 이름·이모지·색만 쓴다.
struct CategoryInfo: Identifiable {
    let key: CategoryKey
    let name: String
    let emoji: String
    let color: Color
    let isBuiltIn: Bool

    var id: CategoryKey { key }
}

// MARK: - 오류

enum UserCategoryError: Error, Equatable {
    case emptyName
    case nameTooLong
    case duplicateName
    case limitReached
    case saveFailed
    case notFound
}

// MARK: - 규칙 (순수 함수)

enum UserCategoryRules {
    static let maxCount = 20
    static let maxNameLength = 10
    static let defaultEmoji = "💸"

    /// 앞뒤 공백·개행 제거
    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 입력칸 바인딩용 — 10자(grapheme)를 넘는 부분을 자른다.
    static func clamp(_ name: String) -> String {
        name.count > maxNameLength ? String(name.prefix(maxNameLength)) : name
    }

    /// 이름·개수 검사. `excluding`은 수정 중인 카테고리의 옛 이름(자기 자신과의 중복 제외).
    /// `excluding`이 nil이면 새로 만드는 것이므로 개수 한도도 검사한다.
    static func validate(name: String,
                         existingNames: [String],
                         excluding: String? = nil,
                         currentCount: Int) -> UserCategoryError? {
        let normalized = normalizedName(name)
        if normalized.isEmpty { return .emptyName }
        if normalized.count > maxNameLength { return .nameTooLong }

        let reserved = SpendingCategory.allCases.map(\.rawValue)
        let own = excluding.map(normalizedName)
        let others = existingNames.map(normalizedName).filter { existing in
            guard let own else { return true }
            return existing.localizedCaseInsensitiveCompare(own) != .orderedSame
        }
        let isDuplicate = (reserved + others).contains {
            $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame
        }
        if isDuplicate { return .duplicateName }

        if excluding == nil && currentCount >= maxCount { return .limitReached }
        return nil
    }

    /// 문자열에서 첫 이모지 하나를 돌려준다. 일반 글자·숫자뿐이면 nil.
    /// 단독 숫자·기호("1", "#")는 `isEmoji`가 true여도 이모지로 보지 않는다.
    static func firstEmoji(in text: String) -> String? {
        for character in text where isEmoji(character) {
            return String(character)
        }
        return nil
    }

    private static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first, first.properties.isEmoji else { return false }
        return first.properties.isEmojiPresentation || scalars.count > 1
    }

    /// 아직 안 쓴 첫 색. 모두 썼으면 rose.
    static func defaultColor(used: [UserCategoryColor]) -> UserCategoryColor {
        UserCategoryColor.allCases.first { !used.contains($0) } ?? .rose
    }
}
