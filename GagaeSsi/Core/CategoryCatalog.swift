//
//  CategoryCatalog.swift
//  GagaeSsi
//
//  카테고리 키를 이름·이모지·색으로 풀어 주는 곳.
//  @Observable이라 shared를 읽는 뷰는 reload() 뒤 자동으로 다시 그려진다.
//

import SwiftUI
import Observation

@Observable
final class CategoryCatalog {
    static let shared = CategoryCatalog()

    private(set) var userCategories: [UserCategoryModel]

    init(userCategories: [UserCategoryModel] = []) {
        self.userCategories = userCategories
    }

    /// CoreData에서 사용자 카테고리를 다시 읽는다.
    func reload(from manager: CoreDataManager = .shared) {
        userCategories = manager.fetchUserCategories()
    }

    /// 내장 7개 → 사용자 카테고리(만든 순서)
    var all: [CategoryInfo] {
        SpendingCategory.allCases.map { info(for: .builtIn($0)) }
            + userCategories.map { info(for: .user($0.id)) }
    }

    var canAddMore: Bool { userCategories.count < UserCategoryRules.maxCount }

    /// 모르는(삭제된) 사용자 ID는 기타로 돌려준다.
    func info(for key: CategoryKey) -> CategoryInfo {
        switch key {
        case .builtIn(let category):
            return CategoryInfo(key: key, name: category.rawValue, emoji: category.emoji,
                                color: category.color, isBuiltIn: true)
        case .user(let id):
            guard let user = userCategories.first(where: { $0.id == id }) else {
                return info(for: .other)
            }
            return CategoryInfo(key: key, name: user.name, emoji: user.emoji,
                                color: user.color.color, isBuiltIn: false)
        }
    }

    /// 모르는(삭제된) 사용자 ID는 .other로 바꾼다.
    func normalize(_ key: CategoryKey) -> CategoryKey {
        switch key {
        case .builtIn: return key
        case .user(let id):
            return userCategories.contains(where: { $0.id == id }) ? key : .other
        }
    }
}

extension CategoryKey {
    /// 현재 카탈로그 기준 표시 정보
    var info: CategoryInfo { CategoryCatalog.shared.info(for: self) }
}
