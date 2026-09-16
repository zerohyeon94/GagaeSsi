//
//  WishListViewModel.swift
//  GagaeSsi
//
//  위시리스트 저금 ViewModel
//

import SwiftUI
import Observation

@Observable
final class WishListViewModel {
    var items: [WishItemModel] = []

    /// 활성(저금중) 아이템
    var activeItem: WishItemModel? { items.first { $0.status == .saving } }
    /// 구매 가능(목표 도달) 아이템
    var purchasableItems: [WishItemModel] { items.filter { $0.status == .purchasable } }
    /// 대기 중 아이템 (희망/필수)
    var waitingItems: [WishItemModel] { items.filter { $0.status == .waiting } }
    /// 완료 아이템
    var completedItems: [WishItemModel] { items.filter { $0.status == .completed } }

    /// 다른 아이템이 저금 중이면 신규 활성화 불가
    var hasActiveSaving: Bool { activeItem != nil }

    func load() {
        items = CoreDataManager.shared.fetchWishItems()
    }

    // MARK: - Mutations
    @discardableResult
    func addWish(title: String, targetAmount: Int, kind: WishKind) -> Bool {
        let model = WishItemModel(title: title, targetAmount: targetAmount, kind: kind)
        let ok = CoreDataManager.shared.createWishItem(model)
        load()
        return ok
    }

    func updateWish(id: UUID, title: String, targetAmount: Int, kind: WishKind) {
        _ = CoreDataManager.shared.updateWishItem(id: id, title: title, targetAmount: targetAmount, kind: kind)
        load()
    }

    /// 활성화. 다른 아이템이 저금 중이면 false.
    @discardableResult
    func activate(id: UUID, dailySaving: Int, eventBus: AppEventBus) -> Bool {
        let ok = CoreDataManager.shared.activateWish(id: id, dailySaving: dailySaving)
        load()
        if ok { eventBus.notifyWishChanged() }
        return ok
    }

    func deactivate(id: UUID, eventBus: AppEventBus) {
        _ = CoreDataManager.shared.deactivateWish(id: id)
        load()
        eventBus.notifyWishChanged()
    }

    func complete(id: UUID, eventBus: AppEventBus) {
        _ = CoreDataManager.shared.completeWish(id: id)
        load()
        eventBus.notifyWishChanged()
    }

    func delete(id: UUID, eventBus: AppEventBus) {
        _ = CoreDataManager.shared.deleteWishItem(id: id)
        load()
        eventBus.notifyWishChanged()
    }

    // MARK: - Preview 계산
    /// 활성화 시 예상 D-day 미리보기 (일 저금액 기준)
    func daysPreview(target: Int, saved: Int, dailySaving: Int) -> Int? {
        guard dailySaving > 0 else { return nil }
        let remaining = max(0, target - saved)
        if remaining == 0 { return 0 }
        return Int((Double(remaining) / Double(dailySaving)).rounded(.up))
    }
}
