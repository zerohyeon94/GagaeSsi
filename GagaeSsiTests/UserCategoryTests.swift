//
//  UserCategoryTests.swift
//  GagaeSsi
//
//  사용자 소비 카테고리 — 규칙(순수), 저장 키, CRUD, 이름 변경·삭제, 예산 불변 검증.
//  표시 정보는 CategoryCatalog.shared를 거치므로, 그걸 읽는 테스트는 먼저 sut로 reload한다.
//

import XCTest
@testable import GagaeSsi

final class UserCategoryTests: XCTestCase {
    var sut: CoreDataManager!

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(salary: 3_000_000, payday: 25, fixedCosts: []))
        CategoryCatalog.shared.reload(from: sut)
    }

    override func tearDownWithError() throws {
        sut.resetAllData()
        CategoryCatalog.shared.reload(from: sut)   // 전역 카탈로그가 다른 테스트로 새지 않게
        sut = nil
    }

    private func makeCategory(_ name: String = "반려동물", emoji: String = "🐶",
                              color: UserCategoryColor = .rose) throws -> UserCategoryModel {
        try sut.addUserCategory(name: name, emoji: emoji, color: color)
    }

    /// 오늘 날짜 소비를 만든다 (DailyBudget이 먼저 있어야 한다)
    @discardableResult
    private func spend(_ amount: Int, _ category: CategoryKey, title: String = "지출") -> SpendingRecordModel {
        _ = sut.fetchOrCreateTodayDailyBudget()
        let record = SpendingRecordModel(title: title, amount: amount, date: Date(), category: category)
        XCTAssertTrue(sut.createSpendingRecord(record))
        return record
    }

    // MARK: - 1. 규칙 (순수)

    func test_빈_이름과_공백_이름은_거부한다() {
        XCTAssertEqual(UserCategoryRules.validate(name: "", existingNames: [], currentCount: 0), .emptyName)
        XCTAssertEqual(UserCategoryRules.validate(name: "   ", existingNames: [], currentCount: 0), .emptyName)
    }

    func test_이름은_10자까지_허용하고_11자는_거부한다() {
        XCTAssertNil(UserCategoryRules.validate(name: "가나다라마바사아자차", existingNames: [], currentCount: 0))
        XCTAssertEqual(UserCategoryRules.validate(name: "가나다라마바사아자차카", existingNames: [], currentCount: 0),
                       .nameTooLong)
    }

    func test_글자수는_이모지를_한_글자로_센다() {
        XCTAssertNil(UserCategoryRules.validate(name: "반려동물🐶🐶🐶🐶🐶🐶", existingNames: [], currentCount: 0))
        XCTAssertEqual(UserCategoryRules.validate(name: "반려동물🐶🐶🐶🐶🐶🐶🐶", existingNames: [], currentCount: 0),
                       .nameTooLong)
        XCTAssertEqual(UserCategoryRules.clamp("가나다라마바사아자차카타").count, 10)
    }

    func test_내장_이름과_기존_이름은_대소문자와_앞뒤_공백을_무시하고_중복이다() {
        XCTAssertEqual(UserCategoryRules.validate(name: "식비", existingNames: [], currentCount: 0), .duplicateName)
        XCTAssertEqual(UserCategoryRules.validate(name: " 반려동물 ", existingNames: ["반려동물"], currentCount: 1),
                       .duplicateName)
        XCTAssertEqual(UserCategoryRules.validate(name: "ABC", existingNames: ["abc"], currentCount: 1),
                       .duplicateName)
    }

    func test_수정할_때는_자기_이름과_겹쳐도_허용한다() {
        XCTAssertNil(UserCategoryRules.validate(name: "반려동물", existingNames: [], excluding: "", currentCount: 1))
    }

    func test_21번째_추가는_거부한다() {
        XCTAssertNil(UserCategoryRules.validate(name: "새", existingNames: [], currentCount: 19))
        XCTAssertEqual(UserCategoryRules.validate(name: "새", existingNames: [], currentCount: 20), .limitReached)
    }

    func test_안_쓴_첫_색을_고르고_다_쓰면_장미로_돌아간다() {
        XCTAssertEqual(UserCategoryRules.defaultColor(used: []), .rose)
        XCTAssertEqual(UserCategoryRules.defaultColor(used: [.rose, .mustard]), .olive)
        XCTAssertEqual(UserCategoryRules.defaultColor(used: UserCategoryColor.allCases), .rose)
    }

    // MARK: - 2. firstEmoji

    func test_첫_이모지_하나만_남긴다() {
        XCTAssertNil(UserCategoryRules.firstEmoji(in: "ab"))
        XCTAssertNil(UserCategoryRules.firstEmoji(in: "1"), "단독 숫자는 이모지가 아니다")
        XCTAssertNil(UserCategoryRules.firstEmoji(in: "#"))
        XCTAssertNil(UserCategoryRules.firstEmoji(in: ""))
        XCTAssertEqual(UserCategoryRules.firstEmoji(in: "🐶🐱"), "🐶")
        XCTAssertEqual(UserCategoryRules.firstEmoji(in: "a🐶"), "🐶")
        XCTAssertEqual(UserCategoryRules.firstEmoji(in: "👨‍👩‍👧"), "👨‍👩‍👧")
        XCTAssertEqual(UserCategoryRules.firstEmoji(in: "☺️"), "☺️")
    }

    // MARK: - 3. CategoryKey

    func test_내장_카테고리_저장값이_왕복한다() {
        for category in SpendingCategory.allCases {
            let key = CategoryKey.builtIn(category)
            XCTAssertEqual(key.storageValue, category.rawValue, "내장은 지금까지처럼 한글 이름으로 저장한다")
            XCTAssertEqual(CategoryKey(storageValue: key.storageValue), key)
        }
    }

    func test_사용자_카테고리_저장값이_왕복한다() {
        let id = UUID()
        let key = CategoryKey.user(id)
        XCTAssertEqual(key.storageValue, "user:\(id.uuidString)")
        XCTAssertEqual(CategoryKey(storageValue: key.storageValue), key)
    }

    func test_모르는_저장값은_기타로_읽는다() {
        XCTAssertEqual(CategoryKey(storageValue: "user:xyz"), .other)
        XCTAssertEqual(CategoryKey(storageValue: nil), .other)
        XCTAssertEqual(CategoryKey(storageValue: ""), .other)
        XCTAssertEqual(CategoryKey(storageValue: "모르는값"), .other)
    }

    // MARK: - 4. CRUD

    func test_추가한_카테고리가_만든_순서로_조회된다() throws {
        let first = try makeCategory("반려동물", emoji: "🐶", color: .rose)
        let second = try makeCategory("구독", emoji: "📺", color: .navy)

        let fetched = sut.fetchUserCategories()
        XCTAssertEqual(fetched.map(\.id), [first.id, second.id])
        XCTAssertEqual(fetched[0].name, "반려동물")
        XCTAssertEqual(fetched[0].emoji, "🐶")
        XCTAssertEqual(fetched[1].color, .navy)
    }

    func test_추가할_때_이모지는_첫_하나만_저장하고_없으면_기본값이다() throws {
        XCTAssertEqual(try makeCategory("가", emoji: "🐶🐱").emoji, "🐶")
        XCTAssertEqual(try makeCategory("나", emoji: "ab").emoji, UserCategoryRules.defaultEmoji)
    }

    func test_이름은_앞뒤_공백을_제거해_저장한다() throws {
        XCTAssertEqual(try makeCategory("  육아  ").name, "육아")
    }

    func test_수정하면_이름_이모지_색이_바뀐다() throws {
        var model = try makeCategory()
        model.name = "펫"
        model.emoji = "🐱"
        model.color = .teal
        try sut.updateUserCategory(model)

        let fetched = try XCTUnwrap(sut.fetchUserCategories().first)
        XCTAssertEqual(fetched.name, "펫")
        XCTAssertEqual(fetched.emoji, "🐱")
        XCTAssertEqual(fetched.color, .teal)
        XCTAssertEqual(fetched.createdAt, model.createdAt, "수정은 순서를 바꾸지 않는다")
    }

    func test_다른_카테고리와_같은_이름으로_수정하면_거부하고_저장하지_않는다() throws {
        _ = try makeCategory("반려동물")
        var other = try makeCategory("구독")
        other.name = "반려동물"

        XCTAssertThrowsError(try sut.updateUserCategory(other)) {
            XCTAssertEqual($0 as? UserCategoryError, .duplicateName)
        }
        XCTAssertEqual(sut.fetchUserCategories().map(\.name), ["반려동물", "구독"])
    }

    func test_중복_빈_이름_초과_이름은_던지고_저장하지_않는다() throws {
        _ = try makeCategory("반려동물")
        let cases: [(String, UserCategoryError)] = [
            ("반려동물", .duplicateName), ("식비", .duplicateName),
            ("", .emptyName), ("가나다라마바사아자차카", .nameTooLong),
        ]
        for (name, expected) in cases {
            XCTAssertThrowsError(try sut.addUserCategory(name: name, emoji: "💸", color: .rose)) {
                XCTAssertEqual($0 as? UserCategoryError, expected, name)
            }
        }
        XCTAssertEqual(sut.fetchUserCategories().count, 1)
    }

    func test_21번째_추가는_던지고_20개로_유지된다() throws {
        for index in 1...UserCategoryRules.maxCount {
            _ = try makeCategory("카테고리\(index)")
        }
        XCTAssertThrowsError(try makeCategory("하나더")) {
            XCTAssertEqual($0 as? UserCategoryError, .limitReached)
        }
        XCTAssertEqual(sut.fetchUserCategories().count, UserCategoryRules.maxCount)
    }

    func test_없는_카테고리를_수정하거나_지우면_notFound다() {
        let ghost = UserCategoryModel(name: "유령")
        XCTAssertThrowsError(try sut.updateUserCategory(ghost)) {
            XCTAssertEqual($0 as? UserCategoryError, .notFound)
        }
        XCTAssertThrowsError(try sut.deleteUserCategory(id: ghost.id)) {
            XCTAssertEqual($0 as? UserCategoryError, .notFound)
        }
    }

    // MARK: - 5. 이름 변경

    func test_이름을_바꾸면_과거_기록과_CSV와_집계가_새_이름이고_합계는_그대로다() throws {
        var model = try makeCategory("반려동물")
        let key = CategoryKey.user(model.id)
        spend(10_000, key, title: "사료")
        spend(20_000, key, title: "병원")
        spend(30_000, key, title: "간식")
        CategoryCatalog.shared.reload(from: sut)

        let totalBefore = sut.fetchSpendingRecords(date: Date()).myShareTotal

        model.name = "펫"
        try sut.updateUserCategory(model)
        CategoryCatalog.shared.reload(from: sut)

        let records = sut.fetchSpendingRecords(date: Date())
        XCTAssertEqual(records.count, 3)
        XCTAssertTrue(records.allSatisfy { $0.category.info.name == "펫" })
        XCTAssertEqual(records.myShareTotal, totalBefore, "이름만 바뀌고 금액 합계는 그대로")

        let csv = SpendingCSVExporter.makeCSV(from: records)
        XCTAssertTrue(csv.contains("펫"))
        XCTAssertFalse(csv.contains("반려동물"))
        XCTAssertFalse(csv.contains("user:"), "CSV에 저장용 키가 새면 안 된다")

        // 통계처럼 키로 묶으면 옛 이름 행 없이 한 줄이다
        let grouped = Dictionary(grouping: records) { CategoryCatalog.shared.normalize($0.category) }
        XCTAssertEqual(grouped.count, 1)
    }

    func test_재조회해도_사용자_카테고리_기록이_유지된다() throws {
        let model = try makeCategory()
        spend(5_000, .user(model.id))

        let records = sut.fetchSpendingRecords(date: Date())
        XCTAssertEqual(records.first?.category, .user(model.id))
    }

    // MARK: - 6. 삭제

    func test_삭제하면_기록과_페이백_연결이_기타로_옮겨지고_합계는_같다() throws {
        let model = try makeCategory()
        let key = CategoryKey.user(model.id)
        spend(10_000, key)
        spend(20_000, key)

        let today = Calendar.current.startOfDay(for: Date())
        let payback = PaybackModel(title: "펫 환급", type: .period, periodStart: today, periodEnd: today,
                                   linkedCategory: key, refundRatePercent: 10)
        XCTAssertTrue(sut.createPayback(payback))

        let usage = sut.userCategoryUsage(id: model.id)
        XCTAssertEqual(usage.records, 2)
        XCTAssertEqual(usage.paybacks, 1)
        let linkedBefore = sut.linkedSpendingTotal(for: payback)
        XCTAssertEqual(linkedBefore.total, 30_000)

        let moved = try sut.deleteUserCategory(id: model.id)
        XCTAssertEqual(moved.records, 2)
        XCTAssertEqual(moved.paybacks, 1)

        let records = sut.fetchSpendingRecords(date: Date())
        XCTAssertTrue(records.allSatisfy { $0.category == .other })
        XCTAssertEqual(records.myShareTotal, 30_000)

        let reloaded = try XCTUnwrap(sut.fetchPaybacks().first)
        XCTAssertEqual(reloaded.linkedCategory, .other)
        XCTAssertEqual(sut.linkedSpendingTotal(for: reloaded).total, linkedBefore.total)
        XCTAssertTrue(sut.fetchUserCategories().isEmpty)
    }

    func test_쓰지_않던_카테고리는_0건으로_삭제된다() throws {
        let model = try makeCategory()
        XCTAssertEqual(sut.userCategoryUsage(id: model.id).records, 0)
        let moved = try sut.deleteUserCategory(id: model.id)
        XCTAssertEqual(moved.records, 0)
        XCTAssertEqual(moved.paybacks, 0)
    }

    func test_지워진_카테고리를_가리키는_기록은_기타로_표시되고_집계된다() throws {
        // 카탈로그에 없는 ID (다른 기기에서 지웠거나 옛 선택 값)
        let orphan = CategoryKey.user(UUID())
        XCTAssertEqual(CategoryCatalog.shared.normalize(orphan), .other)
        XCTAssertEqual(orphan.info.name, "기타")
        XCTAssertEqual(orphan.info.emoji, "💸")
    }

    func test_삭제_확인_문구는_건수에_따라_달라진다() {
        let none = CategoryDeleteMessage.make(name: "구독", records: 0, paybacks: 0)
        XCTAssertEqual(none.title, "‘구독’ 카테고리를 삭제할까요?")
        XCTAssertEqual(none.message, "삭제하면 되돌릴 수 없어요.")

        let records = CategoryDeleteMessage.make(name: "반려동물", records: 12, paybacks: 0)
        XCTAssertTrue(records.message.hasPrefix("기록 12건은 ‘기타’로 옮겨져요."))
        XCTAssertTrue(records.message.contains("다시 만들어도"))

        let both = CategoryDeleteMessage.make(name: "반려동물", records: 12, paybacks: 1)
        XCTAssertTrue(both.message.hasPrefix("기록 12건과 페이백 1개의 묶음은 ‘기타’로 옮겨져요."))
    }

    // MARK: - 7. 예산 불변

    func test_추가_수정_삭제_전후로_예산_값이_같다() throws {
        var model = try makeCategory()
        spend(12_000, .user(model.id))
        spend(8_000, .builtIn(.food))

        func snapshot() -> (available: Int?, outflow: Int, share: Int) {
            let records = sut.fetchSpendingRecords(date: Date())
            return (sut.fetchOrCreateTodayDailyBudget()?.availableAmount, records.budgetOutflow, records.myShareTotal)
        }
        let before = snapshot()

        _ = try makeCategory("구독", emoji: "📺", color: .navy)
        model.name = "펫"
        model.color = .plum
        try sut.updateUserCategory(model)
        let afterEdit = snapshot()
        XCTAssertEqual(afterEdit.available, before.available)
        XCTAssertEqual(afterEdit.outflow, before.outflow)
        XCTAssertEqual(afterEdit.share, before.share)

        try sut.deleteUserCategory(id: model.id)
        let afterDelete = snapshot()
        XCTAssertEqual(afterDelete.available, before.available)
        XCTAssertEqual(afterDelete.outflow, before.outflow)
        XCTAssertEqual(afterDelete.share, before.share)
    }

    // MARK: - 8. 초기화

    func test_데이터_초기화하면_사용자_카테고리도_사라진다() throws {
        _ = try makeCategory()
        _ = try makeCategory("구독")
        XCTAssertEqual(sut.fetchUserCategories().count, 2)

        sut.resetAllData()
        XCTAssertTrue(sut.fetchUserCategories().isEmpty)
    }

    // MARK: - 9. 카탈로그

    func test_카탈로그는_내장_7개_뒤에_만든_순서로_이어붙인다() {
        let first = UserCategoryModel(name: "반려동물", emoji: "🐶", color: .rose,
                                      createdAt: Date(timeIntervalSince1970: 1))
        let second = UserCategoryModel(name: "구독", emoji: "📺", color: .navy,
                                       createdAt: Date(timeIntervalSince1970: 2))
        let catalog = CategoryCatalog(userCategories: [first, second])

        XCTAssertEqual(catalog.all.map(\.name),
                       SpendingCategory.allCases.map(\.rawValue) + ["반려동물", "구독"])
        XCTAssertEqual(catalog.all.filter(\.isBuiltIn).count, 7)
        XCTAssertEqual(catalog.info(for: .user(first.id)).emoji, "🐶")
        XCTAssertTrue(catalog.canAddMore)
    }

    func test_카탈로그는_모르는_ID를_기타로_돌려준다() {
        let catalog = CategoryCatalog()
        let info = catalog.info(for: .user(UUID()))
        XCTAssertEqual(info.key, .other)
        XCTAssertEqual(info.name, "기타")
        XCTAssertEqual(info.emoji, "💸")
        XCTAssertEqual(catalog.normalize(.user(UUID())), .other)
        XCTAssertEqual(catalog.normalize(.builtIn(.food)), .builtIn(.food))
    }

    func test_카탈로그는_20개가_차면_더_추가할_수_없다고_알린다() {
        let full = (1...UserCategoryRules.maxCount).map { UserCategoryModel(name: "c\($0)") }
        XCTAssertFalse(CategoryCatalog(userCategories: full).canAddMore)
    }
}
