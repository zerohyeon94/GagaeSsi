//
//  CategoryManageViewModel.swift
//  GagaeSsi
//
//  카테고리 관리 화면의 상태 — 목록·사용 건수·삭제 확인.
//

import Foundation
import Observation

/// 삭제 확인 alert 문구 (순수 함수 — 테스트 대상)
enum CategoryDeleteMessage {
    static func make(name: String, records: Int, paybacks: Int) -> (title: String, message: String) {
        let title = "‘\(name)’ 카테고리를 삭제할까요?"
        guard records > 0 || paybacks > 0 else {
            return (title, "삭제하면 되돌릴 수 없어요.")
        }
        let moved: String
        if records > 0 && paybacks > 0 {
            moved = "기록 \(records)건과 페이백 \(paybacks)개의 묶음은 ‘기타’로 옮겨져요."
        } else if records > 0 {
            moved = "기록 \(records)건은 ‘기타’로 옮겨져요."
        } else {
            moved = "페이백 \(paybacks)개의 묶음은 ‘기타’로 옮겨져요."
        }
        return (title, moved + "\n같은 이름으로 다시 만들어도 옮겨진 기록은 돌아오지 않아요.")
    }
}

@Observable
final class CategoryManageViewModel {
    struct Row: Identifiable {
        let model: UserCategoryModel
        let usageCount: Int
        var id: UUID { model.id }
    }

    struct PendingDelete: Identifiable {
        let model: UserCategoryModel
        let records: Int
        let paybacks: Int
        var id: UUID { model.id }
    }

    private let manager: CoreDataManager
    private let catalog: CategoryCatalog

    private(set) var rows: [Row] = []
    var pendingDelete: PendingDelete?
    var deleteFailed = false
    var toast: String?

    init(manager: CoreDataManager = .shared, catalog: CategoryCatalog = .shared) {
        self.manager = manager
        self.catalog = catalog
    }

    /// 목록을 읽지 못했는지 ('불러오지 못했어요 + 다시 시도' 상태)
    private(set) var loadError = false

    /// 조회에 실패한 동안은 개수를 알 수 없으므로 추가를 막는다.
    var canAdd: Bool { !loadError && rows.count < UserCategoryRules.maxCount }

    /// 카탈로그를 다시 읽고 행별 사용 건수를 센다. 실패하면 오류 상태로 두고 목록은 비운다.
    func load() {
        catalog.reload(from: manager)
        loadError = catalog.loadFailed
        guard !loadError else {
            rows = []
            return
        }
        rows = catalog.userCategories.map {
            Row(model: $0, usageCount: manager.userCategoryUsage(id: $0.id).records)
        }
    }

    /// 확인창을 띄우는 순간 건수를 센다.
    func requestDelete(_ model: UserCategoryModel) {
        let usage = manager.userCategoryUsage(id: model.id)
        pendingDelete = PendingDelete(model: model, records: usage.records, paybacks: usage.paybacks)
    }

    /// - Returns: 지웠으면 true. 실패하면 목록은 그대로고 `deleteFailed`가 켜진다.
    @discardableResult
    func confirmDelete(_ pending: PendingDelete) -> Bool {
        pendingDelete = nil
        do {
            let moved = try manager.deleteUserCategory(id: pending.model.id)
            load()
            toast = moved.records > 0
                ? "기록 \(moved.records)건을 기타로 옮겼어요"
                : "‘\(pending.model.name)’을 삭제했어요"
            return true
        } catch {
            deleteFailed = true
            return false
        }
    }
}
