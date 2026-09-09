# 여행 정산 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 여행 중 같이 쓴 돈을 "여행"으로 묶고, 내 몫만 예산에서 빼고, 정산 때 남의 몫을 지갑(또는 예산)으로 되돌린다.

**Architecture:** `Trip` 엔티티를 새로 만들고 `SpendingRecord`에 `trip` 관계 + `participants` + `paidByMe`를 붙인다. 내 몫(`myShare`)·예산 반영액(`budgetAmount`)·정산액(`receivable`)은 전부 `SpendingRecordModel`의 파생값이며 저장하지 않는다. 예산 엔진은 `DailyBudgetModel.budgetedSpending` 한 줄만 `budgetAmount` 기준으로 바뀌고, 내역·통계는 `myShare` 기준으로 합친다. 정산은 여행당 한 번이며 페이백 수령과 같은 통로(`CarryOverSource`)를 쓰되, 지갑이 연결돼 있으면 `WishSavingEntry(source: tripSettlement)`로 지갑 잔액을 회복한다.

**Tech Stack:** SwiftUI, CoreData (lightweight migration, `GagaeSsi 12`), `@Observable` MVVM, XCTest (인메모리 `CoreDataManager`)

**Spec:** [docs/superpowers/specs/2026-09-08-trip-settlement-design.md](../specs/2026-09-08-trip-settlement-design.md)

---

## 작업 전 알아둘 것

- 프로젝트는 Xcode **file-system synchronized group**을 쓴다. `GagaeSsi/` 아래에 파일을 만들면 자동으로 타겟에 포함된다. `.pbxproj`를 손대지 않는다.
- 빌드: `xcodebuild -project GagaeSsi.xcodeproj -scheme GagaeSsi -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' build -quiet`
- 테스트 한 클래스: `xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/<클래스> -quiet`
- **시뮬레이터 destination 주의**: 이 머신의 Xcode는 iOS 26.x 런타임만 eligible로 본다. CLAUDE.md에 적힌 `name=iPhone 16`(iOS 18.0 런타임)은 `Unable to find a device matching the provided destination specifier`로 실패하므로, 위 명령의 `name=iPhone 17,OS=26.0`을 그대로 쓴다.
- 테스트는 `CoreDataManager(inMemory: true)` + `setUp`에서 `resetAllData()`. 급여일이 테스트 구간에 걸리면 부채 흡수가 끼어드니 `WishWalletTests.safePayday` 패턴을 쓴다.
- 주석·문서는 한국어. 색은 `Color.gagaeXxx` 토큰만, hex 직접 사용 금지(설정 아이콘 배경은 예외적으로 기존 코드가 hex를 씀).
- 커밋 메시지는 `feat:`/`docs:` 접두 + 한국어 한 줄, 끝에 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## 파일 구조

| 파일 | 책임 |
|---|---|
| `GagaeSsi/Resources/GagaeSsi.xcdatamodeld/GagaeSsi 12.xcdatamodel/contents` (신규) | `Trip` 엔티티, `SpendingRecord`·`WishSavingEntry`·`WishItem` 확장 |
| `GagaeSsi/Models/TripModels.swift` (신규) | `TripStatus`, `TripModel`, `TripSettlementModel` (순수 계산) |
| `GagaeSsi/Models/BudgetModels.swift` | `SpendingRecordModel` 파생값, `budgetedSpending`, `CarryOverReason.tripSettlement` |
| `GagaeSsi/Models/WishModels.swift` | `WishSavingSource`, `WishSavingEntryModel.source`, `WishItemModel.returnedAmount` |
| `GagaeSsi/Core/CoreDataManager.swift` | 소비 CRUD에 여행 필드 저장, 지갑 잔액을 `budgetAmount` 기준으로, 여행 섹션(CRUD·정산) |
| `GagaeSsi/Core/Utils/FormatterUtils.swift` | `shortDateRange` |
| `GagaeSsi/Features/Spend/SpendViewModel.swift`, `SpendView.swift` | 여행 필드·인원·결제자·지갑 자동 선택 |
| `GagaeSsi/Features/History/HistorySpendEditView.swift`, `HistoryView.swift`, `HistoryViewModel.swift` | 편집 시 여행 필드, 내역 배지·내 몫 |
| `GagaeSsi/Features/Trip/TripListView.swift`, `TripEditView.swift`, `TripDetailView.swift`, `TripSettleSheet.swift` (신규) | 여행 목록·편집·상세·정산 |
| `GagaeSsi/Features/Settings/SettingsView.swift` | 진입점 |
| `GagaeSsi/Features/Stats/StatsViewModel.swift`, `Models/CategorySpendingModels.swift`, `Models/TimeSlot.swift`, `Models/SpendingCSVExporter.swift`, `Features/Home/HomeViewModel.swift` | 합산을 `myShare`로 |
| `GagaeSsi/Features/Wishlist/WishListView.swift` | 정산 회수 표시 |
| `GagaeSsiTests/TripSettlementTests.swift`, `TripTests.swift` (신규), `CoreDataMigrationTests.swift`, `DataExportTests.swift`, `CategorySpendingTests.swift` | 테스트 |

---

### Task 1: CoreData `GagaeSsi 12` + `SpendingRecordModel` 파생값

**Files:**
- Create: `GagaeSsi/Resources/GagaeSsi.xcdatamodeld/GagaeSsi 12.xcdatamodel/contents`
- Modify: `GagaeSsi/Resources/GagaeSsi.xcdatamodeld/.xccurrentversion`
- Modify: `GagaeSsi/Models/BudgetModels.swift` (`SpendingRecordModel`, 453~495행)
- Modify: `GagaeSsi/Core/CoreDataManager.swift` (`createSpendingRecord` 555행, `updateSpendingRecord` 606행, `resetAllData` 902행)
- Test: `GagaeSsiTests/TripSettlementTests.swift` (신규), `GagaeSsiTests/CoreDataMigrationTests.swift`

- [ ] **Step 1: 모델 버전 12 복제**

```bash
cd "GagaeSsi/Resources/GagaeSsi.xcdatamodeld" && cp -R "GagaeSsi 11.xcdatamodel" "GagaeSsi 12.xcdatamodel"
```

- [ ] **Step 2: `GagaeSsi 12.xcdatamodel/contents` 편집**

`SpendingRecord` 엔티티의 `<relationship name="wishItem" .../>` 줄 **뒤**에 다음을 넣는다 (기존 attribute들 사이 위치는 무관):

```xml
        <attribute name="paidByMe" optional="YES" attributeType="Boolean" defaultValueString="YES" usesScalarValueType="YES"/>
        <attribute name="participants" optional="YES" attributeType="Integer 16" defaultValueString="1" usesScalarValueType="YES"/>
        <relationship name="trip" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Trip" inverseName="spendingRecords" inverseEntity="Trip"/>
```

`WishSavingEntry` 엔티티의 `<attribute name="id" .../>` 줄 뒤에:

```xml
        <attribute name="source" optional="YES" attributeType="String"/>
```

`WishItem` 엔티티의 `<relationship name="spendingRecords" .../>` 줄 뒤에:

```xml
        <relationship name="trips" optional="YES" toMany="YES" deletionRule="Nullify" destinationEntity="Trip" inverseName="wishItem" inverseEntity="WishItem"/>
```

`</model>` 바로 앞에 새 엔티티:

```xml
    <entity name="Trip" representedClassName="Trip" syncable="YES" codeGenerationType="class">
        <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="defaultParticipants" optional="YES" attributeType="Integer 16" defaultValueString="2" usesScalarValueType="YES"/>
        <attribute name="endDate" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="settledAmount" optional="YES" attributeType="Integer 32" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="settledAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="settlementEntryId" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="startDate" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="status" optional="YES" attributeType="String" defaultValueString="진행중"/>
        <attribute name="title" optional="YES" attributeType="String"/>
        <relationship name="spendingRecords" optional="YES" toMany="YES" deletionRule="Nullify" destinationEntity="SpendingRecord" inverseName="trip" inverseEntity="SpendingRecord"/>
        <relationship name="wishItem" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="WishItem" inverseName="trips" inverseEntity="WishItem"/>
    </entity>
```

`settlementEntryId`는 스펙 7절의 "source·date로 식별"을 대체한다 — 같은 날 두 여행을 예산으로 정산하면 date만으로는 구분이 안 되므로 정산 때 만든 엔트리 id를 여행이 직접 들고 있는다. (Step 8에서 스펙에도 반영)

- [ ] **Step 3: 현재 버전 포인터 갱신**

`GagaeSsi/Resources/GagaeSsi.xcdatamodeld/.xccurrentversion`의 `<string>GagaeSsi 11.xcdatamodel</string>`을 `<string>GagaeSsi 12.xcdatamodel</string>`으로.

- [ ] **Step 4: `SpendingRecordModel`에 필드·파생값 추가**

`GagaeSsi/Models/BudgetModels.swift`의 `SpendingRecordModel`을 다음으로 교체한다 (struct 전체):

```swift
struct SpendingRecordModel: Identifiable {
    var id: UUID
    var title: String
    var amount: Int
    var date: Date
    var category: SpendingCategory
    /// 나중에 돌려받을 환급/페이백 예정 금액 (0이면 없음)
    var expectedPayback: Int
    /// 환급을 실제로 받았는지 여부
    var paybackReceived: Bool
    /// 모아둔 위시 지갑에서 쓴 소비면 그 위시 id. nil이면 평소 소비.
    /// 연결된 소비는 이미 저금으로 예산에서 빠진 돈이라 하루 예산에서 다시 빼지 않는다.
    var wishItemId: UUID?
    /// 여행에 묶인 소비면 그 여행 id. nil이면 평소 소비.
    var tripId: UUID?
    /// 이 소비를 나누는 인원. 1이면 공용이 아닌 내 소비.
    var participants: Int
    /// 내가 결제했는지. false면 다른 사람이 냈고 내 몫만 예산에서 빠진다.
    var paidByMe: Bool

    /// 순 지출 (실지출 − 환급 예정)
    var netAmount: Int { amount - expectedPayback }

    // MARK: 여행 파생값 — 저장하지 않는다. 여행이 아닌 소비는 셋 다 amount와 같다.

    /// 공용 소비인지 (N빵 대상)
    var isShared: Bool { participants > 1 }
    /// 내가 소비한 몫. 공용이면 인원으로 나눈다 (원 단위 내림). 내역·통계는 이 값을 합친다.
    var myShare: Int { participants > 1 ? amount / participants : amount }
    /// 그날 예산(또는 지갑)에서 빠지는 돈. 내가 냈으면 전액, 남이 냈으면 내 몫.
    var budgetAmount: Int { paidByMe ? amount : myShare }
    /// 정산 때 돌아오는 남의 몫. 남이 낸 소비는 0.
    var receivable: Int { paidByMe ? amount - myShare : 0 }

    init(id: UUID = UUID(), title: String, amount: Int, date: Date,
         category: SpendingCategory = .other,
         expectedPayback: Int = 0, paybackReceived: Bool = false,
         wishItemId: UUID? = nil,
         tripId: UUID? = nil, participants: Int = 1, paidByMe: Bool = true) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.expectedPayback = expectedPayback
        self.paybackReceived = paybackReceived
        self.wishItemId = wishItemId
        self.tripId = tripId
        self.participants = max(1, participants)
        self.paidByMe = paidByMe
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: SpendingRecord) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
        self.category = SpendingCategory.from(rawValue: entity.category)
        self.expectedPayback = Int(entity.expectedPayback)
        self.paybackReceived = entity.paybackReceived
        self.wishItemId = entity.wishItem?.id
        self.tripId = entity.trip?.id
        self.participants = max(1, Int(entity.participants))
        self.paidByMe = entity.paidByMe
    }
}
```

- [ ] **Step 5: 소비 CRUD가 새 필드를 저장하게**

`CoreDataManager.createSpendingRecord`에서 `newSpendingRecord.paybackReceived = model.paybackReceived` 줄 뒤에:

```swift
        newSpendingRecord.participants = Int16(clamping: model.participants)
        newSpendingRecord.paidByMe = model.paidByMe
```

`updateSpendingRecord`에서 `spendingRecord.paybackReceived = model.paybackReceived` 줄 뒤에:

```swift
        spendingRecord.participants = Int16(clamping: model.participants)
        spendingRecord.paidByMe = model.paidByMe
```

`resetAllData`의 `entityNames` 배열 끝에 `"Trip"` 추가:

```swift
        let entityNames = ["BudgetConfig", "FixedCost", "MonthlyFixedCostEntry", "Installment", "Payback", "DailyBudget", "SpendingRecord", "CarryOverSource", "CarryOverPoolEntry", "WishItem", "WishSavingEntry", "SpendingDebt", "DebtRepaymentEntry", "AssetTransfer", "Trip"]
```

- [ ] **Step 6: 파생값 테스트 작성**

`GagaeSsiTests/TripSettlementTests.swift` 신규:

```swift
//
//  TripSettlementTests.swift
//  GagaeSsi
//
//  여행 소비의 내 몫·예산 반영액·정산액은 저장하지 않고 계산한다.
//  여행이 아닌 소비는 셋 다 금액과 같아야 기존 동작이 바뀌지 않는다.
//

import XCTest
@testable import GagaeSsi

final class TripSettlementTests: XCTestCase {

    private func record(_ amount: Int, participants: Int = 1, paidByMe: Bool = true,
                        wishItemId: UUID? = nil) -> SpendingRecordModel {
        SpendingRecordModel(title: "지출", amount: amount, date: Date(),
                            wishItemId: wishItemId, tripId: UUID(),
                            participants: participants, paidByMe: paidByMe)
    }

    // MARK: - 파생값

    func test_여행이_아닌_소비는_내몫_예산반영_모두_금액과_같고_정산액은_0이다() {
        let r = SpendingRecordModel(title: "커피", amount: 4_500, date: Date())
        XCTAssertFalse(r.isShared)
        XCTAssertEqual(r.myShare, 4_500)
        XCTAssertEqual(r.budgetAmount, 4_500)
        XCTAssertEqual(r.receivable, 0)
    }

    func test_내가_낸_공용_소비는_전액이_예산에서_빠지고_남의_몫이_정산액이다() {
        let r = record(90_000, participants: 3, paidByMe: true)
        XCTAssertEqual(r.myShare, 30_000)
        XCTAssertEqual(r.budgetAmount, 90_000)
        XCTAssertEqual(r.receivable, 60_000)
    }

    func test_친구가_낸_공용_소비는_내_몫만_예산에서_빠지고_정산액은_0이다() {
        let r = record(300_000, participants: 3, paidByMe: false)
        XCTAssertEqual(r.myShare, 100_000)
        XCTAssertEqual(r.budgetAmount, 100_000)
        XCTAssertEqual(r.receivable, 0)
    }

    func test_나눗셈은_내림이고_나머지는_남의_몫에_붙는다() {
        let r = record(100_000, participants: 3, paidByMe: true)
        XCTAssertEqual(r.myShare, 33_333)
        XCTAssertEqual(r.receivable, 66_667)
    }

    func test_인원을_1로_내리면_공용이_아니다() {
        let r = record(50_000, participants: 1, paidByMe: false)
        XCTAssertFalse(r.isShared)
        XCTAssertEqual(r.myShare, 50_000)
        XCTAssertEqual(r.receivable, 0)
    }

    func test_인원_0은_1로_보정된다() {
        let r = SpendingRecordModel(title: "지출", amount: 10_000, date: Date(), participants: 0)
        XCTAssertEqual(r.participants, 1)
        XCTAssertEqual(r.myShare, 10_000)
    }
}
```

- [ ] **Step 7: 마이그레이션 테스트 추가**

`GagaeSsiTests/CoreDataMigrationTests.swift`의 마지막 테스트 뒤(클래스 닫는 `}` 앞)에:

```swift
    /// 여행 필드가 추가된 12로 올라와도 기존 소비는 "내 개인 소비"로 남아 숫자가 하나도 바뀌지 않아야 한다
    func test_GagaeSsi11에서_12로_마이그레이션되고_기존_소비는_내_몫이_전액이다() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi 11"))
        let oldContext = oldContainer.viewContext

        let budget = NSEntityDescription.insertNewObject(forEntityName: "DailyBudget", into: oldContext)
        budget.setValue(NSDecimalNumber(value: 50_000), forKey: "availableAmount")
        budget.setValue(Date(), forKey: "date")

        let record = NSEntityDescription.insertNewObject(forEntityName: "SpendingRecord", into: oldContext)
        record.setValue(UUID(), forKey: "id")
        record.setValue("점심", forKey: "title")
        record.setValue(NSDecimalNumber(value: 9_000), forKey: "amount")
        record.setValue(Date(), forKey: "date")
        record.setValue(budget, forKey: "dailyBudget")

        try oldContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try currentModel())
        let newContext = newContainer.viewContext

        let records = try newContext.fetch(NSFetchRequest<SpendingRecord>(entityName: "SpendingRecord"))
        XCTAssertEqual(records.count, 1)
        let migrated = SpendingRecordModel(entity: records[0])
        XCTAssertNil(migrated.tripId)
        XCTAssertEqual(migrated.participants, 1)
        XCTAssertTrue(migrated.paidByMe)
        XCTAssertEqual(migrated.myShare, 9_000)
        XCTAssertEqual(migrated.budgetAmount, 9_000)
        XCTAssertEqual(migrated.receivable, 0)

        // 신규 Trip 엔티티가 사용 가능한지
        let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: newContext)
        trip.setValue(UUID(), forKey: "id")
        trip.setValue("제주", forKey: "title")
        trip.setValue(Date(), forKey: "startDate")
        trip.setValue(Date(), forKey: "endDate")
        trip.setValue(Int16(3), forKey: "defaultParticipants")
        trip.setValue("진행중", forKey: "status")
        trip.setValue(Date(), forKey: "createdAt")
        records[0].setValue(trip, forKey: "trip")

        XCTAssertNoThrow(try newContext.save())
        try unload(newContainer)
    }
```

- [ ] **Step 8: 스펙에 `settlementEntryId` 반영**

`docs/superpowers/specs/2026-09-08-trip-settlement-design.md` 4절 `Trip (신규)` 블록의 `settledAt Date? · settledAmount Int32 · createdAt Date` 줄을 다음으로:

```
  settledAt Date? · settledAmount Int32 · settlementEntryId UUID? · createdAt Date
```

7절 `reopenTrip(id:)` 1번 항목을 다음으로:

```
1. 정산 때 만든 엔트리를 `settlementEntryId`로 찾아 삭제 — 지갑이면 `WishSavingEntry`, 예산이면 `CarryOverSource`. (같은 날 두 여행을 정산해도 섞이지 않게 id로 찾는다)
```

- [ ] **Step 9: 테스트 실행**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripSettlementTests -only-testing:GagaeSsiTests/CoreDataMigrationTests -quiet
```

Expected: `** TEST SUCCEEDED **`. 실패하면 `contents` XML의 inverse 이름(`trips`↔`wishItem`, `spendingRecords`↔`trip`)이 맞는지 먼저 본다.

- [ ] **Step 10: 커밋**

```bash
git add "GagaeSsi/Resources/GagaeSsi.xcdatamodeld" GagaeSsi/Models/BudgetModels.swift GagaeSsi/Core/CoreDataManager.swift GagaeSsiTests/TripSettlementTests.swift GagaeSsiTests/CoreDataMigrationTests.swift docs/superpowers/specs/2026-09-08-trip-settlement-design.md
git commit -m "feat: CoreData 12 — 여행 엔티티와 소비의 인원·결제자, 내 몫은 계산으로

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: `TripModel` · `TripSettlementModel` (순수 계산)

**Files:**
- Create: `GagaeSsi/Models/TripModels.swift`
- Test: `GagaeSsiTests/TripSettlementTests.swift`

- [ ] **Step 1: 정산 집계 테스트 추가**

`TripSettlementTests`에 다음 섹션을 추가한다:

```swift
    // MARK: - 정산 집계

    /// 3명, 내가 점심 10만·저녁 20만·아침 15만을 다 냈다.
    /// 10만·20만은 3으로 나누어떨어지지 않아 내 몫 합계가 15만에서 1원 모자란다 —
    /// 항목별로 버림하기 때문이고, 그 나머지는 돌려받을 돈에 붙는다.
    func test_내가_다_낸_여행은_인당_금액과_받을_돈이_나온다() {
        let s = TripSettlementModel.compute(records: [
            record(100_000, participants: 3), record(200_000, participants: 3), record(150_000, participants: 3),
        ])
        XCTAssertEqual(s.totalPaid, 450_000)
        XCTAssertEqual(s.sharedTotal, 450_000)
        XCTAssertEqual(s.myShareTotal, 149_999)
        XCTAssertEqual(s.paidByMeTotal, 450_000)
        XCTAssertEqual(s.receivable, 300_001)
        XCTAssertEqual(s.perPersonSpending, 150_000)   // 표시용 인당 금액은 합계를 나눈 값이라 15만이 맞다
    }

    func test_친구가_낸_숙소는_내_몫만_집계되고_받을_돈은_없다() {
        let s = TripSettlementModel.compute(records: [record(300_000, participants: 3, paidByMe: false)])
        XCTAssertEqual(s.totalPaid, 300_000)
        XCTAssertEqual(s.myShareTotal, 100_000)
        XCTAssertEqual(s.paidByMeTotal, 0)
        XCTAssertEqual(s.receivable, 0)
    }

    func test_항목별_인원이_섞이면_항목별_몫의_합이고_인당_금액은_없다() {
        let s = TripSettlementModel.compute(records: [
            record(300_000, participants: 3, paidByMe: false),   // 숙소 3명 → 내 몫 10만
            record(80_000, participants: 2, paidByMe: true),     // 저녁 2명 → 내 몫 4만, 4만 돌아옴
            record(3_000, participants: 1),                      // 기념품 → 내 몫 3천
        ])
        XCTAssertEqual(s.myShareTotal, 143_000)
        XCTAssertEqual(s.sharedTotal, 380_000)
        XCTAssertEqual(s.receivable, 40_000)
        XCTAssertNil(s.perPersonSpending)
    }

    func test_지갑에서_빠진_돈과_예산에서_빠진_돈이_갈린다() {
        let wallet = UUID()
        let s = TripSettlementModel.compute(records: [
            record(90_000, participants: 3, paidByMe: true, wishItemId: wallet),   // 지갑에서 9만
            record(60_000, participants: 3, paidByMe: false, wishItemId: wallet),  // 지갑에서 내 몫 2만
            record(30_000, participants: 3, paidByMe: true),                       // 예산에서 3만
        ])
        XCTAssertEqual(s.fromWallet, 110_000)
        XCTAssertEqual(s.fromBudget, 30_000)
    }

    func test_소비가_없으면_전부_0이다() {
        let s = TripSettlementModel.compute(records: [])
        XCTAssertEqual(s, TripSettlementModel(totalPaid: 0, sharedTotal: 0, myShareTotal: 0,
                                              paidByMeTotal: 0, receivable: 0,
                                              fromWallet: 0, fromBudget: 0, uniformParticipants: nil))
    }

    /// 정산이 끝나면 "예산에서 빠진 돈 − 돌려받은 돈"이 통계가 보여줄 내 소비와 정확히 같아야 한다.
    /// 합계를 한 번에 나누면 여기서 1원이 어긋난다.
    func test_예산_차감에서_정산액을_빼면_내_몫_합계와_정확히_같다() {
        let records = [
            record(100_000, participants: 3), record(200_000, participants: 3),
            record(150_000, participants: 3), record(70_000, participants: 4, paidByMe: false),
            record(3_000, participants: 1),
        ]
        let s = TripSettlementModel.compute(records: records)
        let budgetDeducted = records.reduce(0) { $0 + $1.budgetAmount }
        XCTAssertEqual(budgetDeducted - s.receivable, s.myShareTotal)
        XCTAssertEqual(s.myShareTotal, records.reduce(0) { $0 + $1.myShare },
                       "통계가 더하는 방식과 같아야 한다")
    }

    // MARK: - TripModel

    func test_여행_기간_포함_판정은_시작일과_종료일을_포함한다() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 2, to: start)!
        let trip = TripModel(title: "제주", startDate: start, endDate: end, defaultParticipants: 3)
        XCTAssertTrue(trip.contains(start))
        XCTAssertTrue(trip.contains(cal.date(byAdding: .hour, value: 30, to: start)!))
        XCTAssertTrue(trip.contains(end))
        XCTAssertFalse(trip.contains(cal.date(byAdding: .day, value: -1, to: start)!))
        XCTAssertFalse(trip.contains(cal.date(byAdding: .day, value: 3, to: start)!))
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripSettlementTests -quiet
```

Expected: 컴파일 에러 `cannot find 'TripSettlementModel' in scope`.

- [ ] **Step 3: `TripModels.swift` 작성**

```swift
//
//  TripModels.swift
//  GagaeSsi
//
//  여행 — 같이 쓴 돈을 묶고, 내 몫만 예산에서 빼고, 나중에 정산한다.
//  정산 단위는 소비 건이 아니라 여행이다. 소비에는 인원·결제자만 표시하고 나머지는 여기서 계산한다.
//

import Foundation

// MARK: - 여행 상태
enum TripStatus: String, Codable {
    case active = "진행중"
    case settled = "정산완료"

    static func from(_ raw: String?) -> TripStatus { TripStatus(rawValue: raw ?? "") ?? .active }
}

// MARK: - 여행 모델
struct TripModel: Identifiable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    /// 소비 입력 시 인원 기본값. 항목마다 바꿀 수 있다.
    var defaultParticipants: Int
    var status: TripStatus
    var settledAt: Date?
    /// 정산 때 실제로 돌려받은(되돌린) 금액
    var settledAmount: Int
    /// 정산 때 만든 크레딧(지갑 저금 엔트리 또는 이월 항목)의 id. 다시 열 때 이걸로 찾아 지운다.
    var settlementEntryId: UUID?
    var createdAt: Date
    /// 연결된 위시 지갑. 있으면 내가 내는 소비는 여기서 먼저 빠지고 정산 회수도 여기로 돌아온다.
    var wishItemId: UUID?

    var isSettled: Bool { status == .settled }

    /// 소비 날짜가 여행 기간(시작일·종료일 포함) 안인지. 자동 선택 판단에만 쓴다 — 기간 밖 소비도 묶을 수 있다.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return calendar.startOfDay(for: startDate) <= day && day <= calendar.startOfDay(for: endDate)
    }

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date,
         defaultParticipants: Int = 2, status: TripStatus = .active,
         settledAt: Date? = nil, settledAmount: Int = 0, settlementEntryId: UUID? = nil,
         createdAt: Date = Date(), wishItemId: UUID? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.defaultParticipants = max(1, defaultParticipants)
        self.status = status
        self.settledAt = settledAt
        self.settledAmount = settledAmount
        self.settlementEntryId = settlementEntryId
        self.createdAt = createdAt
        self.wishItemId = wishItemId
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: Trip) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.startDate = entity.startDate ?? Date()
        self.endDate = entity.endDate ?? self.startDate
        self.defaultParticipants = max(1, Int(entity.defaultParticipants))
        self.status = TripStatus.from(entity.status)
        self.settledAt = entity.settledAt
        self.settledAmount = Int(entity.settledAmount)
        self.settlementEntryId = entity.settlementEntryId
        self.createdAt = entity.createdAt ?? Date()
        self.wishItemId = entity.wishItem?.id
    }
}

// MARK: - 정산 집계 (순수 계산)

/// 여행에 묶인 소비들을 한 번에 집계한다. 정산 화면·목록 요약이 이 값을 그대로 보여준다.
struct TripSettlementModel: Equatable {
    /// 여행 소비 전액 합 (내가 낸 것 + 남이 낸 것)
    let totalPaid: Int
    /// 공용(인원 > 1) 소비의 전액 합
    let sharedTotal: Int
    /// Σ myShare — 내가 소비한 돈. 통계와 같은 값.
    let myShareTotal: Int
    /// 내가 실제로 낸 돈
    let paidByMeTotal: Int
    /// Σ receivable — 정산 때 돌아올 남의 몫
    let receivable: Int
    /// 지갑에 연결된 소비의 예산 반영액 합
    let fromWallet: Int
    /// 예산에서 빠진 소비의 예산 반영액 합
    let fromBudget: Int
    /// 공용 소비의 인원이 전부 같으면 그 값. 섞여 있으면 nil ("인당" 줄을 보여줄지 판단)
    let uniformParticipants: Int?

    /// 인원이 하나로 통일돼 있을 때의 인당 금액 (공용 합 ÷ 인원, 내림)
    var perPersonSpending: Int? {
        guard let n = uniformParticipants, n > 0 else { return nil }
        return sharedTotal / n
    }

    static func compute(records: [SpendingRecordModel]) -> TripSettlementModel {
        var totalPaid = 0, sharedTotal = 0, myShareTotal = 0, paidByMeTotal = 0
        var receivable = 0, fromWallet = 0, fromBudget = 0
        var participantSet = Set<Int>()

        for r in records {
            totalPaid += r.amount
            myShareTotal += r.myShare
            receivable += r.receivable
            if r.isShared {
                sharedTotal += r.amount
                participantSet.insert(r.participants)
            }
            if r.paidByMe { paidByMeTotal += r.amount }
            if r.wishItemId != nil { fromWallet += r.budgetAmount } else { fromBudget += r.budgetAmount }
        }

        return TripSettlementModel(totalPaid: totalPaid, sharedTotal: sharedTotal,
                                   myShareTotal: myShareTotal, paidByMeTotal: paidByMeTotal,
                                   receivable: receivable, fromWallet: fromWallet, fromBudget: fromBudget,
                                   uniformParticipants: participantSet.count == 1 ? participantSet.first : nil)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripSettlementTests -quiet
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add GagaeSsi/Models/TripModels.swift GagaeSsiTests/TripSettlementTests.swift
git commit -m "feat: 여행 모델과 정산 집계 — 인당 금액·받을 돈은 여행이 계산한다

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: 예산 엔진·지갑 잔액을 `budgetAmount` 기준으로

**Files:**
- Modify: `GagaeSsi/Models/BudgetModels.swift` (`budgetedSpending`, 339행)
- Modify: `GagaeSsi/Core/CoreDataManager.swift` (`updateSpendingRecord` 지갑 검사, `wishSpentAmount` 1906행, `wishSpendableLimit` 1920행, `linkSpendingToWish` 1940행)
- Test: `GagaeSsiTests/TripTests.swift` (신규)

- [ ] **Step 1: 테스트 파일 작성 (예산 차감)**

`GagaeSsiTests/TripTests.swift` 신규:

```swift
//
//  TripTests.swift
//  GagaeSsi
//
//  여행 소비는 내 몫만 예산에서 빠지고, 정산 때 남의 몫이 지갑(또는 예산)으로 돌아온다.
//

import XCTest
@testable import GagaeSsi

final class TripTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        setupConfig()
        makeDay(0)
    }
    override func tearDownWithError() throws { sut = nil }

    // MARK: - Helpers

    func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date())!)
    }
    /// 테스트 구간에 급여일이 걸리면 부채 흡수가 끼어들어 실행일에 따라 단정이 깨진다
    private var safePayday: Int {
        ((cal.component(.day, from: Date()) + 13 - 1) % 28) + 1
    }
    private func setupConfig() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: safePayday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
    }
    /// 이월 없이 그날 예산만 만든다 (before/after 차이로만 단정하므로 배정액은 임의)
    func makeDay(_ offset: Int, available: Int = 100_000) {
        guard sut.fetchDailyBudgetModel(date: day(offset)) == nil else { return }
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: available, date: day(offset),
                                                   carryOverSources: [], spendingRecords: []))
    }
    /// 목표를 이미 채운 지갑을 만든다 (WishWalletTests와 같은 방식)
    @discardableResult
    func seedWallet(_ amount: Int, title: String = "제주 여행") -> UUID {
        makeDay(-5)
        let wish = WishItemModel(title: title, targetAmount: amount, dailySaving: amount,
                                 status: .saving, activatedAt: day(-5))
        _ = sut.createWishItem(wish)
        _ = sut.activateWish(id: wish.id, dailySaving: amount)
        sut.processDailyBudgets(upTo: day(0))
        return wish.id
    }
    @discardableResult
    func spend(_ amount: Int, on offset: Int = 0, participants: Int = 1, paidByMe: Bool = true,
               tripId: UUID? = nil, title: String = "지출") -> UUID {
        makeDay(offset)
        let record = SpendingRecordModel(title: title, amount: amount, date: day(offset),
                                         tripId: tripId, participants: participants, paidByMe: paidByMe)
        XCTAssertTrue(sut.createSpendingRecord(record))
        return record.id
    }
    func available(_ offset: Int = 0) -> Int {
        sut.fetchDailyBudgetModel(date: day(offset))?.todayAvailable ?? 0
    }
    func outgoing(_ offset: Int = 0) -> Int {
        guard let budget = sut.fetchDailyBudgetModel(date: day(offset)) else { return 0 }
        return OverspendAnalyzer.evaluate(budget).outgoing
    }

    // MARK: - 예산 차감

    func test_내가_낸_공용_소비는_그날_예산에서_전액_빠진다() {
        let before = available()
        spend(90_000, participants: 3, paidByMe: true)
        XCTAssertEqual(available(), before - 90_000)
    }

    func test_친구가_낸_공용_소비는_내_몫만_빠진다() {
        let before = available()
        spend(90_000, participants: 3, paidByMe: false)
        XCTAssertEqual(available(), before - 30_000)
    }

    func test_초과_판정도_내_몫_기준이다() {
        spend(120_000, participants: 3, paidByMe: false)
        XCTAssertEqual(outgoing(), 40_000, "친구가 낸 소비는 내 몫만 그날 지출로 잡힌다")
        spend(120_000, participants: 3, paidByMe: true)
        XCTAssertEqual(outgoing(), 160_000, "내가 낸 소비는 전액")
    }

    func test_인원을_바꾸면_그날부터_다시_계산된다() {
        let id = spend(90_000, participants: 3, paidByMe: false)
        let before = available()
        var edited = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }!
        edited.participants = 2
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertEqual(available(), before - 15_000, "내 몫이 3만 → 4.5만으로 늘어난 만큼 더 빠진다")
    }

    // MARK: - 지갑

    func test_지갑에_연결한_친구_결제_소비는_내_몫만_지갑에서_빠진다() {
        let wallet = seedWallet(100_000)
        let id = spend(90_000, participants: 3, paidByMe: false)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertEqual(sut.wishBalance(for: wallet), 70_000)
    }

    func test_지갑_잔액_비교는_내_부담액_기준이다() {
        let wallet = seedWallet(50_000)
        let friendPaid = spend(120_000, participants: 3, paidByMe: false)   // 내 부담 4만
        XCTAssertTrue(sut.linkSpendingToWish(recordId: friendPaid, wishItemId: wallet))
        XCTAssertEqual(sut.wishBalance(for: wallet), 10_000)

        let iPaid = spend(120_000, participants: 3, paidByMe: true)         // 내 부담 12만
        XCTAssertFalse(sut.linkSpendingToWish(recordId: iPaid, wishItemId: wallet), "잔액을 넘으면 연결 안 됨")
    }

    func test_지갑_소비의_금액을_올려_잔액을_넘기면_연결이_끊긴다() {
        let wallet = seedWallet(50_000)
        let id = spend(90_000, participants: 3, paidByMe: false)            // 내 부담 3만
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))

        var edited = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }!
        edited.paidByMe = true                                              // 내 부담 9만 > 5만
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertNil(sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }?.wishItemId)
        XCTAssertEqual(sut.wishBalance(for: wallet), 50_000)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripTests -quiet
```

Expected: `test_친구가_낸_공용_소비는_내_몫만_빠진다` 등 4~5개 FAIL (전액이 빠짐).

- [ ] **Step 3: `budgetedSpending` 한 줄 변경**

`GagaeSsi/Models/BudgetModels.swift`:

```swift
    /// 예산에서 실제로 빠지는 소비 합. 위시 지갑에서 쓴 소비는 저금 시점에 이미
    /// 빠진 돈이라 제외한다 (넣으면 모아둔 돈으로 쓴 여행이 이중 차감돼 빚이 된다).
    /// 여행에서 친구가 낸 소비는 내 몫만 — `budgetAmount`가 그 판단을 한다.
    var budgetedSpending: Int {
        spendingRecords.filter { $0.wishItemId == nil }.map(\.budgetAmount).reduce(0, +)
    }
```

- [ ] **Step 4: 지갑 잔액·연결을 `budgetAmount` 기준으로**

`CoreDataManager.wishSpentAmount`:

```swift
    /// 이 위시 지갑에서 쓴 소비 합 — 예산에서 빠졌을 금액(`budgetAmount`) 기준.
    /// 친구가 낸 여행 소비는 내 몫만 지갑에서 빠진다.
    func wishSpentAmount(for wishItemId: UUID) -> Int {
        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        request.predicate = NSPredicate(format: "wishItem.id == %@", wishItemId as CVarArg)
        let records = (try? context.fetch(request)) ?? []
        return records.reduce(0) { $0 + SpendingRecordModel(entity: $1).budgetAmount }
    }
```

`wishSpendableLimit`의 `limit += Int(truncating: record.amount ?? 0)` → `limit += SpendingRecordModel(entity: record).budgetAmount`.

`linkSpendingToWish`의 `let amount = Int(truncating: record.amount ?? 0)` → `let amount = SpendingRecordModel(entity: record).budgetAmount`.

- [ ] **Step 5: `updateSpendingRecord`의 지갑 검사를 부담액 기준으로**

기존 지갑 검사 블록을 다음으로 교체 (필드 대입 뒤, `spendingRecord.paidByMe = model.paidByMe` 다음):

```swift
        // 부담액을 올려 지갑 잔액을 넘기면 연결을 끊는다. 일부만 지갑에서 빼는 방식은
        // 같은 날 소비 순서에 따라 결과가 달라지므로 "전부 아니면 전무"로 유지한다.
        //
        // `wishSpentAmount`는 컨텍스트의 미저장 변경을 읽으므로 위에서 바꾼 값이 이미 반영돼 있다.
        // 따로 빼고 더할 필요 없이, 이 지갑에서 나간 총액이 모은 돈을 넘었는지만 보면 된다.
        if let wishId = spendingRecord.wishItem?.id,
           wishSpentAmount(for: wishId) > savedAmount(for: wishId) {
            spendingRecord.wishItem = nil
        }
```

(별도로 `이전 부담액을 빼는` 변수는 두지 않는다. `others = wishSpentAmount(for:) − 이전 부담액`, `others + 새 부담액`을 풀어보면 이전 부담액은 상쇄되어 그냥 `wishSpentAmount(for:)`가 남는다 — 애초에 뺐다 더할 필요가 없다. `wishSpentAmount`가 이미 컨텍스트의 미저장 변경(새 `participants`/`paidByMe`가 반영된 값)을 읽으므로, "이 지갑에서 나간 총액이 모은 돈을 넘었는가"만 보면 충분하다.)

**주의:** 이 Step은 실제로 `previousBudgetAmount`를 빼고 더하는 구현으로 한 번 배포되어 회귀를 냈다 (증가 방향 편집에서 `NEW − OLD`만큼 과다 계산되어 잔액 안인데도 연결이 끊김 — 자세한 내용은 커밋 로그의 수정 커밋 참고). 반드시 위 collapsed 형태로 구현한다.

- [ ] **Step 6: 테스트 통과 + 회귀 확인**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripTests -only-testing:GagaeSsiTests/WishWalletTests -only-testing:GagaeSsiTests/CarryOverChainTests -only-testing:GagaeSsiTests/OverspendHistoryTests -quiet
```

Expected: `** TEST SUCCEEDED **`. 여행이 아닌 소비는 `budgetAmount == amount`라 기존 테스트가 그대로 통과해야 한다.

`TripTests.swift`에 아래 회귀 테스트도 포함한다 — 금액을 올려도 잔액 안이면 연결이 유지되는 방향은 기존 테스트 목록에 없어 회귀가 그대로 배포됐던 지점이다:

```swift
    /// 금액을 올려도 잔액 안이면 연결이 유지돼야 한다.
    /// (연결이 끊기면 그 돈이 예산으로 되돌아와 그날을 초과로 만들고 이월까지 타고 내려간다)
    func test_금액을_올려도_잔액_안이면_연결이_유지된다() {
        let wallet = seedWallet(100_000)
        var record = SpendingRecordModel(title: "여행", amount: 50_000, date: day(0))
        XCTAssertTrue(sut.createSpendingRecord(record))
        XCTAssertTrue(sut.linkSpendingToWish(recordId: record.id, wishItemId: wallet))

        record.amount = 80_000
        XCTAssertTrue(sut.updateSpendingRecord(record))
        XCTAssertEqual(sut.wishSpentAmount(for: wallet), 80_000, "잔액 안이면 지갑에 그대로 붙어 있어야 한다")
        XCTAssertNotNil(sut.fetchSpendingRecords(date: day(0)).first { $0.id == record.id }?.wishItemId)
    }
```

- [ ] **Step 7: 커밋**

```bash
git add GagaeSsi/Models/BudgetModels.swift GagaeSsi/Core/CoreDataManager.swift GagaeSsiTests/TripTests.swift
git commit -m "feat: 예산과 지갑은 실제로 내 돈이 나간 만큼만 — 친구가 낸 여행 소비는 내 몫만

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: 내역·통계·CSV·홈 합산을 `myShare`로

**Files:**
- Modify: `GagaeSsi/Features/History/HistoryViewModel.swift` (`load()` 안 `monthTotal`·`totals`)
- Modify: `GagaeSsi/Features/Stats/StatsViewModel.swift` (`loadCategoryStats`·`loadDailyStats`·`loadMonthlyComparison`)
- Modify: `GagaeSsi/Models/CategorySpendingModels.swift` (`itemSummaries`)
- Modify: `GagaeSsi/Models/TimeSlot.swift` (71행 `bySlot[slot, default: 0] += record.amount`)
- Modify: `GagaeSsi/Models/SpendingCSVExporter.swift` (`header`, `makeCSV`)
- Modify: `GagaeSsi/Features/Home/HomeViewModel.swift` (195행)
- Modify: `GagaeSsi/Features/Spend/SpendView.swift` (`totalSpentToday`)
- Modify: `GagaeSsi/Core/CoreDataManager.swift` (`recentAverageDailySpending`, 1704행; `fetchDailyTotals` — `myShare`, 홈 "최근 7일 소비 흐름" 차트는 소비 기록 화면)
- Modify: `GagaeSsi/Features/History/HistoryView.swift` (`dayListCard`의 일별 합계 — `myShare`, 같은 화면 달력 셀과 렌즈를 맞춘다)
- Modify: `GagaeSsi/Features/Stats/CategoryDetailView.swift` (`total` — `myShare`, 같은 화면 `items` 목록·비중(`share`)과 렌즈를 맞춘다)
- Modify: `GagaeSsi/Features/Settings/DataExportView.swift` (`total` — `myShare`, CSV 미리보기이므로 CSV의 "내 몫" 열과 맞춘다)
- Modify: `GagaeSsi/Features/History/OverspendHistoryView.swift` (`detail`의 기록별 금액, `loadRecords`의 정렬 — `budgetAmount`, 이 화면은 예산 장부: 초과 판정 자체가 `budgetedSpending`(Σ`budgetAmount`)이라 그걸 설명하는 기록도 같은 렌즈여야 한다)
- Modify: `GagaeSsi/Models/SpendingTitleCleanup.swift` (`titleStats`의 `Accumulator` 두 곳 — `myShare`, "이 항목으로 얼마 썼는지"를 보여주는 소비 기록 화면)
- Test: `GagaeSsiTests/CategorySpendingTests.swift`, `GagaeSsiTests/DataExportTests.swift`, `GagaeSsiTests/SpendingTitleCleanupTests.swift`

- [ ] **Step 1: 실패하는 테스트 추가**

`SpendingTitleCleanupTests`에 추가 (`titleStats`를 직접 테스트하는 파일이라 여기가 맞다):

```swift
    /// 항목 이름 정리도 소비 기록 화면이므로 내 몫으로 묶인다
    func test_항목_정리_합계도_내_몫으로_묶인다() {
        let shared = SpendingRecordModel(title: "저녁", amount: 80_000, date: Date(),
                                         tripId: UUID(), participants: 4, paidByMe: true)
        let stats = SpendingTitleCleanup.titleStats(from: [shared])
        XCTAssertEqual(stats.first?.total, 20_000)
    }
```

`CategorySpendingTests`에 추가:

```swift
    /// 8만을 결제했어도 4명이 나눴으면 내가 쓴 건 2만이다
    func test_공용_소비는_내_몫으로_묶인다() {
        let shared = SpendingRecordModel(title: "저녁", amount: 80_000, date: Date(),
                                         tripId: UUID(), participants: 4, paidByMe: true)
        let items = CategorySpendingAnalyzer.itemSummaries(from: [shared])
        XCTAssertEqual(items.first?.total, 20_000)
    }
```

`DataExportTests`에서 헤더 단정을 바꾸고 테스트 하나를 추가:

```swift
        XCTAssertTrue(lines[0].hasSuffix("날짜,시각,카테고리,항목,금액,내 몫,환급 예정,환급 받음"))
```

```swift
    func test_공용_소비는_금액과_내_몫이_따로_들어간다() {
        let shared = SpendingRecordModel(title: "저녁", amount: 80_000, date: date(2026, 8, 7),
                                         tripId: UUID(), participants: 4, paidByMe: true)
        let csv = SpendingCSVExporter.makeCSV(from: [shared])
        XCTAssertTrue(csv.contains("80000,20000,,"))
    }
```

`test_환급_정보는_있을_때만_채워진다`의 두 단정도 열이 하나 늘어난 형태로:

```swift
        XCTAssertTrue(withPayback.contains("21000,21000,5000,Y"))
        ...
        XCTAssertTrue(without.contains("4000,4000,,"), "환급이 없으면 두 칸은 빈 값")
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/CategorySpendingTests -only-testing:GagaeSsiTests/DataExportTests -quiet
```

Expected: 새 테스트 2개 + 헤더/환급 단정 FAIL.

- [ ] **Step 3: 합산 치환**

`HistoryViewModel.load()`:

```swift
        monthTotal = records.reduce(0) { $0 + $1.myShare }
        var totals: [Date: Int] = [:]
        for r in records {
            let d = cal.startOfDay(for: r.date)
            totals[d, default: 0] += r.myShare
        }
```

`StatsViewModel`:
- `loadCategoryStats`: `monthlyTotal = records.reduce(0) { $0 + $1.myShare }` · `dict[record.category, default: 0] += record.myShare`
- `loadDailyStats`: `.reduce(0) { $0 + $1.myShare }`
- `loadMonthlyComparison`: `prevMonthTotal = records.reduce(0) { $0 + $1.myShare }`

`CategorySpendingAnalyzer.itemSummaries`: `accumulator.total += record.myShare` · `Accumulator(title: display, total: record.myShare, ...)`

`TimeSlot.swift` 71행: `bySlot[slot, default: 0] += record.myShare`

`HomeViewModel` 195행: `let spent = model.budgetedSpending`

(`myShare`가 아니라 `budgetedSpending`을 쓴다. 이 값은 홈 카드의 "🛒 오늘 소비" 줄이고, 그
카드는 기본 예산 / 이월 / 위시 저금 / 초과분 상환 / 저축·투자 / 오늘 소비 → 잔여 예산으로
이어지는 예산 장부라 각 줄이 `budgetAmount` 계열이어야 합이 맞는다. 내가 90,000을 결제하고
3명이 나눴으면 예산에서는 90,000이 빠지는데 `myShare`로는 30,000만 표시돼 60,000이 설명되지
않는 채로 남는다. 같은 값이 돼지 캐릭터 상태(`CharacterState.from(spent:base:)`)에도 들어가
실제로는 90,000이 나간 날에 30,000만 쓴 것처럼 웃는 얼굴을 보여주게 된다.
`myShare`는 통계·내역·CSV처럼 "내가 실제로 소비한 몫"을 보는 화면의 렌즈이고, 홈 카드는
"예산에서 얼마가 빠졌는가"를 보는 화면이라 렌즈가 다르다. `budgetAmount`는 지갑에서 쓴
소비를 제외하지 않으므로, 위시 지갑에 연결된 소비가 있으면 `budgetedSpending`을 함께 쓴다
— Task 3에서 지갑 연결 소비를 빼도록 이미 고쳐둔 계산이라, 기존에 있던 지갑 연결 소비와의
불일치도 이 변경이 덤으로 바로잡는다.)

`SpendView` 맨 아래 extension:

```swift
extension SpendViewModel {
    /// 오늘 내가 쓴 돈 — 공용 소비는 내 몫만
    var totalSpentToday: Int {
        spendingRecords.reduce(0) { $0 + $1.myShare }
    }
}
```

`SpendingCSVExporter`:

```swift
    static let header = ["날짜", "시각", "카테고리", "항목", "금액", "내 몫", "환급 예정", "환급 받음"]
```

`makeCSV`의 `fields` 배열에서 `String(record.amount),` 뒤에 `String(record.myShare),` 추가.

`CoreDataManager.recentAverageDailySpending`: `records.reduce(0) { $0 + $1.amount } / days` →
`records.reduce(0) { $0 + $1.budgetAmount } / days`.

(이 값은 통계가 아니라 `HomeViewModel.isDebtOffTrack`/`debtDailyCutNeeded`가 쓰는 "이대로면
부채가 줄지 않아요" 경고의 입력이라 예산 표면이다. 하루 예산과 비교하는 값이므로 실제로
예산에서 빠져나간 돈(`budgetAmount`) 기준이어야 한다 — 친구가 낸 여행비까지 `amount`로
합산하면 7일 평균이 부풀어 경고가 잘못 뜬다.)

**놓치기 쉬운 여섯 곳 — 화면 하나 안에서 두 합계가 서로 달라지는 자리.**
지금까지 바꾼 자리들은 "이 화면은 소비 기록이다/예산 장부다"를 판단해 렌즈를 골랐는데,
아래는 같은 화면 안에 이미 한쪽 렌즈로 바뀐 합계가 있는데 다른 합산이 그걸 놓친 경우다.
**원칙: 한 화면 안에서 두 합계가 서로 달라지면 안 된다 — 화면 단위로 렌즈를 정하고 그
화면의 모든 합산을 같은 렌즈로 맞춘다.**

`CoreDataManager.fetchDailyTotals(days:)`:

```swift
            let total = records
                .filter { $0.date >= startOfDay && $0.date < endOfDay }
                .reduce(0) { $0 + $1.myShare }
```

→ `myShare`. `HomeView`의 "최근 7일 소비 흐름" 카드가 이 값을 쓰는데, 이건 소비 기록 카드지
예산 카드가 아니다 (예산 카드는 `budgetedSpending` 기반으로 따로 있다). 주석으로 두 카드의
렌즈가 왜 다른지 남겨둔다.

`HistoryView.dayListCard`:

```swift
Text(FormatterUtils.currencyString(from: viewModel.selectedRecords.reduce(0) { $0 + $1.myShare }))
```

→ `myShare`. 같은 날짜의 달력 셀(`HistoryViewModel.load()`의 `dayTotals`, 이미 `myShare`)과
일별 카드 합계가 어긋나면 안 된다.

`CategoryDetailView.total`:

```swift
private var total: Int { records.reduce(0) { $0 + $1.myShare } }
```

→ `myShare`. 같은 화면의 `items`(항목별 목록, 이미 `myShare`로 바뀜)와 합이 맞아야 하고,
`share`가 이 값을 `StatsViewModel.monthlyTotal`(`myShare` 기준)로 나누므로 분자·분모 렌즈가
같아야 비중이 100%를 넘지 않는다.

`DataExportView.total`:

```swift
private var total: Int { records.reduce(0) { $0 + $1.myShare } }
```

→ `myShare`. 이 미리보기가 요약하는 CSV 자체가 "내 몫" 열을 따로 가진 소비 기록 표라
합계도 같은 렌즈여야 한다.

`OverspendHistoryView` — 기록별 금액 표시와 정렬 둘 다:

```swift
Text("-" + FormatterUtils.currencyString(from: record.budgetAmount))
...
records[date] = CoreDataManager.shared.fetchSpendingRecords(date: date)
    .sorted { $0.budgetAmount > $1.budgetAmount }
```

→ 여기만 `budgetAmount` (다른 다섯 곳과 다르다). 이 화면은 "왜 그날 예산을 넘겼는지"를
설명하는 예산 장부이고, 초과 판정 자체가 `OverspendDay`/`budgetedSpending`(Σ`budgetAmount`)
기준이다. 목록이 `myShare`를 쓰면 넘긴 금액의 합과 나열된 기록들이 설명하는 금액이 어긋난다.

`SpendingTitleCleanup.titleStats`의 `Accumulator` — **두 곳 모두**:

```swift
                accumulator.total += record.myShare
                ...
                map[key] = Accumulator(title: normalized, count: 1,
                                       total: record.myShare, lastDate: record.date)
```

→ `myShare`. `CategorySpendingAnalyzer.itemSummaries`와 같은 누적기 모양이고 "이 항목으로
얼마 썼는지"를 보여주는 소비 기록 화면이다. 두 곳 중 하나만 고치면 그룹의 첫 기록만 다른
렌즈로 세어져 조용히 틀린다.

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/CategorySpendingTests -only-testing:GagaeSsiTests/DataExportTests -only-testing:GagaeSsiTests/TimeSlotTests -quiet
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add GagaeSsi/Features/History/HistoryViewModel.swift GagaeSsi/Features/Stats/StatsViewModel.swift GagaeSsi/Models/CategorySpendingModels.swift GagaeSsi/Models/TimeSlot.swift GagaeSsi/Models/SpendingCSVExporter.swift GagaeSsi/Features/Home/HomeViewModel.swift GagaeSsi/Features/Spend/SpendView.swift GagaeSsi/Core/CoreDataManager.swift GagaeSsiTests/CategorySpendingTests.swift GagaeSsiTests/DataExportTests.swift
git commit -m "feat: 내역·통계는 내가 소비한 몫으로 — 결제 대행분은 소비가 아니다

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

#### Task 4 정정 (코드 리뷰 반영)

Task 4를 "합산하는 자리마다 렌즈를 정한다"로 실행했더니 결함이 났다. **원칙을 정정한다:
렌즈는 합산 지점이 아니라 그 숫자를 쓰는 곳이 정한다.** 같은 화면 안에서도 "내가 얼마나
썼나"를 보여주는 자리(소비 렌즈)와 "예산이 얼마나 줄었나"를 판정하는 자리(예산 렌즈)가
공존할 수 있고, 둘을 같은 시리즈 하나로 때우면 조용히 틀린다.

**예산 렌즈는 두 조건이 함께 걸린 값이다** — `filter { wishItemId == nil }` **AND**
`budgetAmount`. 위시 지갑에서 쓴 소비는 저금 시점에 이미 예산에서 빠졌으므로 절대 다시
세면 안 된다. 이 두 조건을 한 번에 적용하는 헬퍼를 `Sequence where Element ==
SpendingRecordModel`에 추가해뒀다 (`GagaeSsi/Models/BudgetModels.swift`):

- `myShareTotal: Int` — 소비 렌즈. `reduce(0) { $0 + $1.myShare }`와 동일.
- `budgetOutflow: Int` — 예산 렌즈. `filter { $0.wishItemId == nil }`로 지갑 연결 기록을
  뺀 뒤 `budgetAmount`를 합친다.

**두 렌즈가 필요한 자리를 "합산 지점"이 아니라 "화면의 질문"으로 다시 찾은 결과:**

- `StatsViewModel`은 `dailyTotals`/`monthlyTotal`을 `myShare` 기준(소비 렌즈, 차트·소비
  총액 표시용)으로 두되, 다음 **네 개의 예산 판정**은 별도의 예산 렌즈 시리즈
  (`dailyBudgetTotals`, `monthlyBudgetTotal` — `budgetOutflow`로 채운다)를 봐야 한다:
  1. `savingsAmount` (`monthBudget - 월 합계`)
  2. `budgetUsagePct` (월 합계 / `monthBudget`)
  3. `dominantState` (`CharacterState.from(spent:base:)`에 넘기는 일별 합계)
  4. `overBudgetDays` (일별 합계가 `baseDailyBudget`을 넘는 날 수)

  `loadDailyStats`가 한 달의 기록을 하루씩 필터링하는 패스는 한 번만 돌리고, 그 결과에서
  `myShareTotal`과 `budgetOutflow`를 함께 뽑아 두 시리즈를 같이 채운다 (기록을 두 번
  fetch하지 않는다). `StatsView`의 일별 차트도 막대 높이는 소비 렌즈를 쓰되, 막대를
  "초과"로 칠하는 색 판정은 예산 렌즈로 봐야 한다.

- `CoreDataManager.recentAverageDailySpending`은 `budgetAmount`만으로는 부족하다 —
  지갑 연결 필터까지 있어야 진짜 예산 렌즈다 (`.budgetOutflow`를 쓴다). 지갑 필터가
  빠지면 위시 지갑에서 쓴 여행비가 "이대로면 부채가 줄지 않아요" 경고를 오발동시킨다.

- `OverspendHistoryView.loadRecords(for:)`는 `budgetAmount`로 정렬하는 것만으로는
  부족하다 — 그 화면이 설명하는 합계(`budgetedSpending` = 지갑 필터 + `budgetAmount`)와
  맞추려면 지갑 연결 기록 자체를 목록에서 빼야 한다. "이 화면의 판정 함수가 두 조건을
  같이 쓰면, 이 화면의 모든 관련 합산·목록도 두 조건을 같이 써야 한다"가 일반 규칙이다.

- `CoreDataManager.fetchDailyTotals(days:)`의 렌즈(`myShare`, 전체 기록)는 정정 대상이
  아니다 — 홈 "최근 7일 소비 흐름" 차트는 의도적으로 소비 렌즈다. 다만 근처 주석이
  "같은 화면의 예산 카드는 헷갈릴 필요 없다"고 단정했던 건 틀렸다: 둘이 다른 건 렌즈
  차이가 아니라 예산 카드에 걸린 지갑 필터 때문이고, 위시 지갑을 쓰는 사용자에게는 두
  수치가 다르게 보이는 게 정상이라고 명시해야 한다.

**재실행 시 반드시 지킬 것:** 새 합산 자리를 추가할 때 "이 화면에 이미 있는 합계는
무슨 렌즈인가"부터 확인하고, 판정에 쓰이는 값과 표시에 쓰이는 값이 다른 렌즈일 수
있다는 걸 전제로 설계한다. 화면 하나에 렌즈 하나만 있다고 가정하면 이 결함들이 다시
난다.

---

### Task 5: `CoreDataManager` 여행 섹션 (CRUD · 소비 연결 · 집계)

**Files:**
- Modify: `GagaeSsi/Core/CoreDataManager.swift` (파일 끝에 여행 섹션 추가, `createSpendingRecord`·`updateSpendingRecord`에 `trip` 연결)
- Test: `GagaeSsiTests/TripTests.swift`

- [ ] **Step 1: 테스트 추가**

`TripTests`에 헬퍼와 섹션 추가:

```swift
    @discardableResult
    func makeTrip(_ title: String = "제주", from: Int = 0, to: Int = 2, participants: Int = 3,
                  wishItemId: UUID? = nil) -> TripModel {
        let trip = TripModel(title: title, startDate: day(from), endDate: day(to),
                             defaultParticipants: participants, wishItemId: wishItemId)
        XCTAssertTrue(sut.createTrip(trip))
        return trip
    }

    // MARK: - 여행 CRUD

    func test_여행을_만들고_읽고_고치고_지운다() {
        let trip = makeTrip()
        XCTAssertEqual(sut.fetchTrips().map(\.id), [trip.id])

        XCTAssertTrue(sut.updateTrip(id: trip.id, title: "부산", startDate: trip.startDate,
                                     endDate: trip.endDate, defaultParticipants: 4,
                                     wishItemId: trip.wishItemId))
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.title, "부산")
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.defaultParticipants, 4)

        XCTAssertTrue(sut.deleteTrip(id: trip.id))
        XCTAssertTrue(sut.fetchTrips().isEmpty)
    }

    /// 정산 완료 정렬과 자동 선택 제외는 `settleTrip`이 있어야 검증할 수 있어 Task 6에서
    /// 함께 확인한다. 여기서는 정산이 없는 상태에서 시작일 최근순 정렬과, 정산이 하나도
    /// 없을 때 `fetchActiveTrips`가 `fetchTrips`와 같다는 것만 고정한다.
    func test_진행_중_여행들은_시작일_최근순이고_전부_활성이다() {
        let old = makeTrip("작년", from: -400, to: -398)
        let recent = makeTrip("최근", from: -3, to: -1)
        let mid = makeTrip("중간", from: -30, to: -28)

        XCTAssertEqual(sut.fetchTrips().map(\.id), [recent.id, mid.id, old.id])
        XCTAssertEqual(sut.fetchActiveTrips().map(\.id), sut.fetchTrips().map(\.id))
    }

    func test_소비에_여행을_묶고_여행별로_읽는다() {
        let trip = makeTrip()
        let a = spend(90_000, participants: 3, tripId: trip.id)
        let b = spend(30_000, on: 1, participants: 3, paidByMe: false, tripId: trip.id)
        spend(5_000)   // 여행 아님

        let records = sut.fetchSpendingRecords(tripId: trip.id)
        XCTAssertEqual(records.map(\.id), [a, b], "날짜 오름차순")
        XCTAssertEqual(records.first { $0.id == a }?.participants, 3)
        XCTAssertEqual(records.first { $0.id == b }?.paidByMe, false)
    }

    func test_수정으로_여행_연결을_바꿀_수_있다() {
        let trip = makeTrip()
        let id = spend(50_000)
        var edited = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }!
        edited.tripId = trip.id; edited.participants = 2
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertEqual(sut.fetchSpendingRecords(tripId: trip.id).map(\.id), [id])

        edited.tripId = nil
        XCTAssertTrue(sut.updateSpendingRecord(edited))
        XCTAssertTrue(sut.fetchSpendingRecords(tripId: trip.id).isEmpty)
    }

    func test_여행을_지워도_소비와_예산_영향은_남는다() {
        let trip = makeTrip()
        let id = spend(90_000, participants: 3, paidByMe: false, tripId: trip.id)
        let before = available()

        XCTAssertTrue(sut.deleteTrip(id: trip.id))
        let record = sut.fetchSpendingRecords(date: day(0)).first { $0.id == id }
        XCTAssertNotNil(record)
        XCTAssertNil(record?.tripId)
        XCTAssertEqual(record?.participants, 3, "인원·결제자는 그대로")
        XCTAssertEqual(available(), before, "예산 영향 불변")
    }

    // MARK: - 날짜로 여행 찾기

    func test_기간에_드는_진행_중_여행이_하나면_그걸_준다() {
        let trip = makeTrip(from: 0, to: 2)
        XCTAssertEqual(sut.trip(containing: day(1))?.id, trip.id)
        XCTAssertNil(sut.trip(containing: day(3)))
    }

    func test_기간이_겹치는_여행이_둘이면_고르지_않는다() {
        makeTrip("A", from: 0, to: 2)
        makeTrip("B", from: 1, to: 3)
        XCTAssertNil(sut.trip(containing: day(1)))
    }

    // MARK: - 집계

    func test_여행_집계는_사용자_예시와_같다() {
        let trip = makeTrip(participants: 3)
        spend(100_000, participants: 3, tripId: trip.id)
        spend(200_000, participants: 3, tripId: trip.id)
        spend(150_000, on: 1, participants: 3, tripId: trip.id)

        let s = sut.tripSettlement(for: trip.id)
        XCTAssertEqual(s.perPersonSpending, 150_000)
        XCTAssertEqual(s.paidByMeTotal, 450_000)
        // 10만·20만은 3으로 나누어떨어지지 않아 항목별 버림의 나머지가 여기 붙는다
        XCTAssertEqual(s.receivable, 300_001)
    }
```

- [ ] **Step 2: 소비 CRUD에 `trip` 연결**

`createSpendingRecord`에서 `newSpendingRecord.paidByMe = model.paidByMe` 뒤에:

```swift
        newSpendingRecord.trip = model.tripId.flatMap { fetchTripEntity(id: $0) }
```

`updateSpendingRecord`에서 `spendingRecord.paidByMe = model.paidByMe` 뒤에:

```swift
        spendingRecord.trip = model.tripId.flatMap { fetchTripEntity(id: $0) }
```

- [ ] **Step 3: 여행 섹션 작성**

`CoreDataManager.swift` 클래스 닫는 `}` 앞(파일 맨 끝, `refundWishSaving` 뒤)에:

```swift
    // MARK: - 여행 (같이 쓴 돈 묶기 · 정산)

    /// 진행 중이 먼저, 그다음 정산 완료. 각각 시작일 최근순 — 같은 날 시작한 여행은
    /// 최근 생성순으로 묶어 `fetchWishItems`와 같은 이유로 순서를 고정한다.
    func fetchTrips() -> [TripModel] {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false),
                                   NSSortDescriptor(key: "createdAt", ascending: false)]
        let models = ((try? context.fetch(request)) ?? []).map(TripModel.init)
        return models.filter { !$0.isSettled } + models.filter { $0.isSettled }
    }

    /// 소비 입력에서 고를 수 있는 여행들 (정산 완료는 제외)
    func fetchActiveTrips() -> [TripModel] {
        fetchTrips().filter { !$0.isSettled }
    }

    func fetchTrip(id: UUID) -> TripModel? {
        fetchTripEntity(id: id).map(TripModel.init)
    }

    private func fetchTripEntity(id: UUID) -> Trip? {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    @discardableResult
    func createTrip(_ model: TripModel) -> Bool {
        let trip = Trip(context: context)
        trip.id = model.id
        trip.createdAt = model.createdAt
        applyTripEditableFields(title: model.title, startDate: model.startDate, endDate: model.endDate,
                                defaultParticipants: model.defaultParticipants,
                                wishItemId: model.wishItemId, to: trip)
        // 정산 상태는 생성 시점 값 그대로 싣는다 — 이후로는 `settleTrip`/`reopenTrip`(Task 6)만 건드린다
        trip.status = model.status.rawValue
        trip.settledAt = model.settledAt
        trip.settledAmount = Int32(clamping: model.settledAmount)
        trip.settlementEntryId = model.settlementEntryId
        return saveContext()
    }

    /// 제목·기간·인원·지갑 연결만 수정한다 (정산 상태는 건드리지 않음 — `settleTrip`/`reopenTrip`만 쓴다).
    ///
    /// `TripModel`을 통째로 받아 덮으면, 폼 필드만 채운 새 모델이 `status`를 진행중으로,
    /// `settledAmount`를 0으로, `settlementEntryId`를 nil로 되돌려 이미 정산된 여행을 조용히
    /// 되돌리고, `settlementEntryId`가 가리키던 정산 크레딧을 되찾을 방법을 잃게 된다.
    @discardableResult
    func updateTrip(id: UUID, title: String, startDate: Date, endDate: Date,
                    defaultParticipants: Int, wishItemId: UUID?) -> Bool {
        guard let trip = fetchTripEntity(id: id) else { return false }
        applyTripEditableFields(title: title, startDate: startDate, endDate: endDate,
                                defaultParticipants: defaultParticipants,
                                wishItemId: wishItemId, to: trip)
        return saveContext()
    }

    /// 여행의 편집 가능한 필드(제목·기간·인원·지갑 연결)만 적용한다. 정산 상태 필드는
    /// `createTrip`과 `settleTrip`/`reopenTrip`(Task 6)에서만 쓴다.
    ///
    /// `wishItemId`가 이미 지워진 위시를 가리키면 연결은 조용히 nil이 되고 저장 자체는
    /// 그대로 성공한다 — `createSpendingRecord`가 `model.tripId`를 해석하는 것과 같은 규칙.
    private func applyTripEditableFields(title: String, startDate: Date, endDate: Date,
                                         defaultParticipants: Int, wishItemId: UUID?, to trip: Trip) {
        trip.title = title
        let start = Calendar.current.startOfDay(for: startDate)
        trip.startDate = start
        // 종료일이 시작일보다 앞서면 기간 판정이 모든 날짜에 대해 거짓이 된다 — 하루짜리로 접는다
        trip.endDate = max(start, Calendar.current.startOfDay(for: endDate))
        trip.defaultParticipants = Int16(clamping: defaultParticipants)
        trip.wishItem = wishItemId.flatMap { fetchWishItemEntity(id: $0) }
    }

    /// 여행을 지운다. 소비는 연결만 끊기고(Nullify) 그대로 남는다.
    ///
    /// `budgetAmount`는 `participants`·`paidByMe`만 보고 `trip`은 보지 않으므로 예산은 정확히
    /// 그대로다 — 위시 삭제와 달리 이월을 다시 계산할 이유가 없다. (재계산은 아직 전환되지 않은
    /// 과거 초과분을 뒤늦게 부채로 바꾸므로, 이유 없이 부르면 여행을 지웠을 뿐인데 빚이 생긴다.)
    @discardableResult
    func deleteTrip(id: UUID) -> Bool {
        guard let trip = fetchTripEntity(id: id) else { return false }
        context.delete(trip)
        return saveContext()
    }

    /// 소비 날짜가 기간 안인 진행 중 여행. 둘 이상 겹치면 고르지 않는다(nil) — 사용자가 직접 고르게.
    func trip(containing date: Date) -> TripModel? {
        let matches = fetchActiveTrips().filter { $0.contains(date) }
        return matches.count == 1 ? matches.first : nil
    }

    /// 여행에 묶인 소비 (날짜 오름차순)
    func fetchSpendingRecords(tripId: UUID) -> [SpendingRecordModel] {
        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        request.predicate = NSPredicate(format: "trip.id == %@", tripId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return ((try? context.fetch(request)) ?? []).map(SpendingRecordModel.init)
    }

    func tripSettlement(for tripId: UUID) -> TripSettlementModel {
        TripSettlementModel.compute(records: fetchSpendingRecords(tripId: tripId))
    }
```

- [ ] **Step 4: 테스트 확인**

`settleTrip`을 쓰지 않는 테스트만 있으므로 이 단계에서 바로 통과해야 한다 (정산 완료 정렬·자동 선택 제외 검증은 Task 6에서 이어서 한다).

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripTests -quiet
```

Expected: `TripTests` 전부 통과. 이어서 전체 스위트(`GagaeSsiTests`)도 회귀 없이 통과해야 한다.

- [ ] **Step 5: 커밋**

```bash
git add GagaeSsi/Core/CoreDataManager.swift GagaeSsiTests/TripTests.swift
git commit -m "feat: 여행 CRUD와 소비 묶기 — 날짜로 진행 중 여행 찾기, 여행별 집계

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: 정산 — `settleTrip` · `reopenTrip` · 지갑 회수

**Files:**
- Modify: `GagaeSsi/Models/BudgetModels.swift` (`CarryOverReason`)
- Modify: `GagaeSsi/Models/WishModels.swift` (`WishSavingSource`, `WishSavingEntryModel`, `WishItemModel.returnedAmount`,
  `WishItemModel.goalContribution` — 목표 진행률용 값)
- Modify: `GagaeSsi/Core/CoreDataManager.swift` (여행 섹션에 정산 추가, `fetchWishItems`·`fetchActiveWishItem`에
  `returnedAmount`, 지갑 생애주기(`deleteWishItem`·`refundWishSaving`·`activateWish`)의 정산금 환급 규칙,
  `applyWishSaving`의 목표 도달 판정)
- Test: `GagaeSsiTests/TripTests.swift`

> **지갑 생애주기와 정산금은 다른 환급 규칙이 필요하다.** 평소 저금 엔트리는 `DailyBudget`에 붙어 있어
> 그날의 라이브 차감을 이룬다 — 지울 때 "오늘 이전 것만" 명시 환급하면 되는 건, 오늘 것은 엔트리 삭제
> 자체가 라이브 차감을 풀어 자연 환급되기 때문이다(이중 환급 방지). 정산 엔트리(`source ==
> tripSettlement`)는 애초에 `DailyBudget`에 달지 않는다 — 그래서 "오늘 것은 자연 환급된다"는 전제가
> 정산 엔트리에는 성립하지 않는다. `deleteWishItem`(목표를 채워 `.purchasable`이 된 지갑도 포함해 항상)과
> `activateWish`(재활성화로 기존 엔트리를 지울 때)가 이 전제를 몰라 정산 엔트리를 그냥 지우면, 그 돈은
> 장부 어디에도 남지 않고 사라진다 — 아래 스텝들이 이 구멍을 막는다.

- [ ] **Step 1: 정산 테스트 추가**

`TripTests`에:

```swift
    // MARK: - 목록·자동 선택 (정산 완료 포함)
    //
    // `settleTrip`이 있어야 정산 완료 상태를 만들 수 있어 Task 5가 아니라 여기서 검증한다.

    func test_목록은_진행_중이_먼저_그다음_정산_완료다() {
        let old = makeTrip("작년", from: -400, to: -398)
        let settled = makeTrip("정산됨", from: -30, to: -28)
        XCTAssertTrue(sut.settleTrip(id: settled.id, actualAmount: 0))
        let recent = makeTrip("최근", from: -3, to: -1)

        XCTAssertEqual(sut.fetchTrips().map(\.id), [recent.id, old.id, settled.id])
    }

    func test_정산_완료_여행은_자동_선택_대상이_아니다() {
        let trip = makeTrip(from: 0, to: 2)
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 0))
        XCTAssertNil(sut.trip(containing: day(1)))
        XCTAssertTrue(sut.fetchActiveTrips().isEmpty)
    }

    // MARK: - 정산

    func test_정산하면_남의_몫이_오늘_예산으로_돌아온다() {
        let trip = makeTrip(participants: 3)
        spend(450_000, participants: 3, tripId: trip.id)
        let before = available()

        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: sut.tripSettlement(for: trip.id).receivable))
        XCTAssertEqual(available(), before + 300_000)
        let settled = sut.fetchTrip(id: trip.id)
        XCTAssertEqual(settled?.status, .settled)
        XCTAssertEqual(settled?.settledAmount, 300_000)
        XCTAssertNotNil(settled?.settledAt)
    }

    func test_실제_수령액을_덮어쓰면_그_금액이_반영된다() {
        let trip = makeTrip(participants: 3)
        spend(450_000, participants: 3, tripId: trip.id)
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 290_000))
        XCTAssertEqual(available(), before + 290_000)
    }

    func test_받을_돈이_없으면_크레딧_없이_상태만_바뀐다() {
        let trip = makeTrip(participants: 3)
        spend(90_000, participants: 3, paidByMe: false, tripId: trip.id)
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 0))
        XCTAssertEqual(available(), before)
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.status, .settled)
        XCTAssertNil(sut.fetchTrip(id: trip.id)?.settlementEntryId)
    }

    func test_이미_정산된_여행은_다시_정산되지_않는다() {
        let trip = makeTrip()
        spend(90_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        let before = available()
        XCTAssertFalse(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        XCTAssertEqual(available(), before)
    }

    func test_지갑_연결_여행은_정산금이_지갑으로_돌아온다() {
        let wallet = seedWallet(500_000)
        let trip = makeTrip(participants: 3, wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertEqual(sut.wishBalance(for: wallet), 50_000)
        let budgetBefore = available()

        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))
        XCTAssertEqual(sut.wishBalance(for: wallet), 350_000, "지갑 잔액이 회복된다")
        XCTAssertEqual(available(), budgetBefore, "예산에는 아무 변화 없다")
        XCTAssertEqual(sut.fetchWishItems().first { $0.id == wallet }?.returnedAmount, 300_000)
    }

    func test_지갑을_먼저_지운_여행은_정산금이_예산으로_온다() {
        let wallet = seedWallet(100_000)
        let trip = makeTrip(participants: 3, wishItemId: wallet)
        spend(90_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.deleteWishItem(id: wallet))
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        XCTAssertEqual(available(), before + 60_000)
    }

    // MARK: - 정산 다시 열기

    func test_예산으로_정산한_여행을_다시_열면_크레딧이_사라진다() {
        let trip = makeTrip()
        spend(90_000, participants: 3, tripId: trip.id)
        let before = available()
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 60_000))
        XCTAssertTrue(sut.reopenTrip(id: trip.id))
        XCTAssertEqual(available(), before)
        let reopened = sut.fetchTrip(id: trip.id)
        XCTAssertEqual(reopened?.status, .active)
        XCTAssertNil(reopened?.settledAt)
        XCTAssertEqual(reopened?.settledAmount, 0)
    }

    func test_지갑으로_정산한_여행을_다시_열면_지갑_잔액이_줄어든다() {
        let wallet = seedWallet(500_000)
        let trip = makeTrip(wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))

        XCTAssertTrue(sut.reopenTrip(id: trip.id))
        XCTAssertEqual(sut.wishBalance(for: wallet), 50_000)
        XCTAssertEqual(sut.fetchWishItems().first { $0.id == wallet }?.returnedAmount, 0)
    }

    func test_지갑_크레딧을_이미_써버렸으면_다시_열_수_없다() {
        let wallet = seedWallet(500_000)
        let trip = makeTrip(wishItemId: wallet)
        let id = spend(450_000, participants: 3, tripId: trip.id)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: id, wishItemId: wallet))
        XCTAssertTrue(sut.settleTrip(id: trip.id, actualAmount: 300_000))   // 잔액 35만

        let later = spend(320_000, on: 1)
        XCTAssertTrue(sut.linkSpendingToWish(recordId: later, wishItemId: wallet))   // 잔액 3만

        XCTAssertFalse(sut.reopenTrip(id: trip.id))
        XCTAssertEqual(sut.fetchTrip(id: trip.id)?.status, .settled, "아무것도 바뀌지 않는다")
        XCTAssertEqual(sut.wishBalance(for: wallet), 30_000)
    }

    func test_진행_중_여행은_다시_열_수_없다() {
        let trip = makeTrip()
        XCTAssertFalse(sut.reopenTrip(id: trip.id))
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripTests -quiet
```

Expected: 컴파일 에러 `has no member 'settleTrip'`.

- [ ] **Step 3: `CarryOverReason.tripSettlement`**

`GagaeSsi/Models/BudgetModels.swift`의 `CarryOverReason`에 케이스 추가 (`.refund` 뒤):

```swift
    /// 여행 정산으로 돌아온 남의 몫 (내가 대신 낸 돈이 실제로 돌아온 날)
    case tripSettlement
```

`countsTowardAllowance`:

```swift
        case .carryOver, .poolWithdraw, .refund, .tripSettlement: return true
```

- [ ] **Step 4: `WishModels.swift` — 저금 엔트리 출처와 회수액**

`WishSavingEntryModel` 위에 enum 추가하고 모델을 교체:

```swift
// MARK: - 저금 엔트리 출처
/// nil이면 매일 저금. 여행 정산으로 돌아온 돈은 저금이 아니라 회수라 구분해서 보여준다.
enum WishSavingSource: String, Codable {
    case tripSettlement

    static func from(_ raw: String?) -> WishSavingSource? {
        raw.flatMap(WishSavingSource.init(rawValue:))
    }
}

// MARK: - 위시 저금 엔트리 모델 (일자별)
struct WishSavingEntryModel: Identifiable {
    var id: UUID
    var date: Date
    var amount: Int
    var source: WishSavingSource?

    init(id: UUID = UUID(), date: Date, amount: Int, source: WishSavingSource? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.source = source
    }

    init(entity: WishSavingEntry) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.amount = Int(truncating: entity.amount ?? 0)
        self.source = WishSavingSource.from(entity.source)
    }
}
```

`WishItemModel`에 필드 추가 (`spentAmount` 선언 뒤):

```swift
    /// 여행 정산으로 이 지갑에 돌아온 돈 합계 (`savedAmount`에 포함돼 있다 — 표시용 구분값)
    var returnedAmount: Int
```

두 init에 `returnedAmount: Int = 0` 파라미터를 추가하고 `self.returnedAmount = returnedAmount` 대입:

```swift
    init(id: UUID = UUID(), title: String, targetAmount: Int, dailySaving: Int = 0,
         status: WishStatus = .waiting, kind: WishKind = .want,
         createdAt: Date = Date(), activatedAt: Date? = nil, completedAt: Date? = nil,
         savedAmount: Int = 0, spentAmount: Int = 0, returnedAmount: Int = 0) {
```

```swift
    init(entity: WishItem, savedAmount: Int = 0, spentAmount: Int = 0, returnedAmount: Int = 0) {
```

- [ ] **Step 5: `fetchWishItems`·`fetchActiveWishItem`에 회수액 채우기**

`CoreDataManager` 위시 지갑 섹션(`wishBalance` 근처)에 추가:

```swift
    /// 여행 정산으로 이 지갑에 돌아온 돈 합계
    func wishReturnedAmount(for wishItemId: UUID) -> Int {
        let request: NSFetchRequest<WishSavingEntry> = WishSavingEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wishItem.id == %@ AND source == %@",
                                        wishItemId as CVarArg, WishSavingSource.tripSettlement.rawValue)
        let entries = (try? context.fetch(request)) ?? []
        return entries.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
    }

    private func fetchWishSavingEntryEntity(id: UUID) -> WishSavingEntry? {
        let request: NSFetchRequest<WishSavingEntry> = WishSavingEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
```

`fetchWishItems`와 `fetchActiveWishItem`의 `WishItemModel(entity:savedAmount:spentAmount:)` 호출에 `returnedAmount: wishReturnedAmount(for: id)`를 덧붙인다:

```swift
            return WishItemModel(entity: $0, savedAmount: savedAmount(for: id),
                                 spentAmount: wishSpentAmount(for: id),
                                 returnedAmount: wishReturnedAmount(for: id))
```

- [ ] **Step 6: `settleTrip` · `reopenTrip`**

여행 섹션의 `tripSettlement(for:)` 뒤에:

```swift
    /// 여행을 정산한다 — 내가 대신 낸 남의 몫(`actualAmount`)을 되돌린다.
    ///
    /// 지갑이 연결돼 있으면 지갑으로(저금 엔트리, `source = tripSettlement`), 아니면 오늘 예산으로
    /// (`CarryOverSource`, 페이백 수령과 같은 통로). 지갑 엔트리는 `DailyBudget`에 달지 않는다 —
    /// 달면 오늘 예산에서 저금으로 빠져버린다.
    /// - Parameter actualAmount: 실제 받은 금액. 계산값과 달라도 막지 않는다.
    /// - Parameter now: 테스트에서 다른 날짜로 정산하기 위한 훅 (`overduePaybacks(asOf:)`와 같은 관례).
    /// - Returns: 이미 정산됐거나 음수면 `false`
    @discardableResult
    func settleTrip(id: UUID, actualAmount: Int, now: Date = Date()) -> Bool {
        guard let trip = fetchTripEntity(id: id),
              TripStatus.from(trip.status) == .active, actualAmount >= 0 else { return false }
        let today = Calendar.current.startOfDay(for: now)

        var entryId: UUID?
        if actualAmount > 0 {
            if let wish = trip.wishItem {
                let entry = WishSavingEntry(context: context)
                entry.id = UUID()
                entry.date = today
                entry.amount = NSDecimalNumber(value: actualAmount)
                entry.source = WishSavingSource.tripSettlement.rawValue
                entry.wishItem = wish
                wish.addToSavingEntries(entry)
                entryId = entry.id
            } else {
                guard let budget = fetchOrCreateDailyBudgetEntity(date: today) else { return false }
                let source = addCarryOverSource(to: budget, amount: actualAmount,
                                                date: today, toDate: today, reason: .tripSettlement)
                entryId = source.id
            }
        }

        trip.status = TripStatus.settled.rawValue
        trip.settledAt = today
        trip.settledAmount = Int32(clamping: actualAmount)
        trip.settlementEntryId = entryId
        return saveContext()
    }

    /// 정산을 되돌린다 — 정산 때 만든 크레딧을 지우고 진행 중으로.
    ///
    /// 지갑으로 돌아간 돈을 이미 다른 소비가 써서 잔액이 부족하면 거부한다 (지갑 "잔액 한도" 규칙).
    /// 크레딧을 `settlementEntryId`로 찾으므로 정산 뒤 지갑을 붙이거나 뗐어도 제자리를 찾는다.
    /// 크레딧을 찾을 수 없으면(예: 지갑을 지워 정산금이 오늘 예산에 이름 없이 합쳐진 경우) 되돌릴
    /// 수 없다 — 상태만 바꾸면 그 돈은 장부에 남은 채로 사라진 셈이 되고, 나중에 다시 정산하면
    /// 없던 돈이 새로 생긴다. 그래서 이 경우는 항상 거부한다.
    /// - Parameter now: `settleTrip`의 `now`와 짝 — 본문에서 직접 쓰이진 않지만(이 함수는 이미 날짜가
    ///   박힌 크레딧만 다룬다) 정산일과 재오픈일을 갈라 테스트하는 훅으로 남겨 둔다.
    @discardableResult
    func reopenTrip(id: UUID, now: Date = Date()) -> Bool {
        guard let trip = fetchTripEntity(id: id),
              TripStatus.from(trip.status) == .settled else { return false }
        let settledAmount = Int(trip.settledAmount)
        var recalcFrom: Date?

        if let entryId = trip.settlementEntryId, settledAmount > 0 {
            if let entry = fetchWishSavingEntryEntity(id: entryId) {
                if let wishId = entry.wishItem?.id {
                    guard wishBalance(for: wishId) >= settledAmount else { return false }
                }
                // wishItem이 nil인 고아 엔트리는 잔액 검사 없이 그냥 지운다.
                context.delete(entry)
            } else if let source = fetchCarryOverSourceEntity(id: entryId) {
                recalcFrom = source.date
                context.delete(source)
            } else {
                // 크레딧을 찾을 수 없으면 되돌릴 수 없다 — 아무것도 바꾸지 않고 거부한다.
                return false
            }
        }

        trip.status = TripStatus.active.rawValue
        trip.settledAt = nil
        trip.settledAmount = 0
        trip.settlementEntryId = nil
        guard saveContext() else { return false }
        if let from = recalcFrom { recalculateCarryOverChain(from: from) }
        return true
    }
```

- [ ] **Step 6.5: 지갑 생애주기 — 정산금은 상태·날짜 무관 항상 환급**

`refundWishSaving`(위시 지갑 섹션, `deactivateWish`가 이미 쓰던 private 함수)을 정산 엔트리도 다루도록
바꾼다. 평소 저금(엔트리에 `source`가 없는 것)은 기존 규칙 그대로 "저금 중(`.saving`)일 때만, 오늘
이전 것만" 환급하고(오늘 것은 엔트리 삭제로 라이브 차감이 풀려 자연 환급 — 이중 환급 방지), 정산
엔트리(`source == tripSettlement`)는 상태·날짜 무관 전부 더한다:

```swift
    private func refundWishSaving(_ entity: WishItem) {
        let today = Calendar.current.startOfDay(for: Date())
        let entries = entity.savingEntries?.allObjects as? [WishSavingEntry] ?? []

        let ordinaryPastTotal = WishStatus.from(entity.status) == .saving
            ? entries
                .filter { WishSavingSource.from($0.source) == nil }
                .filter { Calendar.current.startOfDay(for: $0.date ?? today) < today }
                .reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
            : 0
        let settlementTotal = entries
            .filter { WishSavingSource.from($0.source) == .tripSettlement }
            .reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
        let refundTotal = ordinaryPastTotal + settlementTotal

        if refundTotal != 0, let budget = fetchOrCreateDailyBudgetEntity(date: today) {
            let refund = CarryOverSource(context: context)
            refund.id = UUID()
            refund.amount = NSDecimalNumber(value: refundTotal)
            refund.date = today
            refund.toDate = today
            refund.dailyBudget = budget
            budget.addToCarryOverSources(refund)
        }
        for e in entries { context.delete(e) }
    }
```

`deleteWishItem`은 `.saving`일 때만 부르던 호출을 상태 무관 항상 부르는 것으로 바꾼다 — 목표를 채워
`.purchasable`이 된 여행 지갑도 정산금을 들고 있을 수 있어, 상태로 거르면 그 돈이 삭제와 함께 그냥
사라진다 (평소 저금 쪽 규칙은 함수 내부에서 여전히 `.saving`으로 걸러지므로 기존 동작은 그대로다):

```swift
    func deleteWishItem(id: UUID) -> Bool {
        guard let entity = fetchWishItemEntity(id: id) else { return false }
        refundWishSaving(entity)   // 상태 무관 항상 — 정산금은 어떤 상태든 환급해야 한다
        ...
```

`activateWish`(재활성화로 기존 엔트리를 지우는 지점)에는 정산 엔트리만 골라 환급하는 별도 헬퍼
`refundSettlementEntries(_:)`를 추가해 엔트리를 지우기 전에 부른다 — 평소 저금은 재활성화 시 기존에도
환급 없이 지웠으므로(그대로 유지) 정산 엔트리만 다룬다:

```swift
        let entries = entity.savingEntries?.allObjects as? [WishSavingEntry] ?? []
        refundSettlementEntries(entries)
        for e in entries { context.delete(e) }
```

`applyWishSaving`의 목표 도달 판정도 `savedAmount`가 아니라 "목표를 향해 모은 돈"
(`savedAmount − wishReturnedAmount`) 기준으로 바꾼다 — Step 6.6에서 다루는
`WishItemModel.goalContribution`과 같은 규칙이며, 그러지 않으면 정산으로 돌아온 돈이 목표 진행으로
이중 계산돼 실제로 모은 돈보다 일찍 `.purchasable`로 넘어간다.

- [ ] **Step 6.6: `WishItemModel` — 목표 진행률은 정산금을 빼고 계산한다**

`savedAmount`는 정산 엔트리도 포함하지만(지갑이 실제로 쥔 돈이라 `balance`엔 그대로 들어가야 한다),
`progress`·`remainingAmount`·`daysLeft`가 그 값을 그대로 쓰면 여행 정산으로 돌아온 돈이 목표 진행으로
이중 계산된다(지출은 애초에 `savedAmount`를 줄이지 않으므로). `goalContribution = savedAmount −
returnedAmount`를 도입해 셋 다 이 값을 쓰게 한다:

```swift
    /// 목표를 향해 "내가 모은 돈" = `savedAmount − returnedAmount`.
    /// 여행 정산으로 돌아온 돈은 목표를 향해 새로 모은 돈이 아니다 — `progress`·`remainingAmount`·
    /// `daysLeft`는 반드시 이 값을 써야 한다. 지갑이 실제로 쥔 돈(`balance`)은 이와 다르다.
    var goalContribution: Int { max(0, savedAmount - returnedAmount) }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return max(0, min(1, Double(goalContribution) / Double(targetAmount)))
    }

    var remainingAmount: Int { max(0, targetAmount - goalContribution) }
```

- [ ] **Step 7: 전체 여행 테스트 + 위시 회귀**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:GagaeSsiTests/TripTests -only-testing:GagaeSsiTests/TripSettlementTests -only-testing:GagaeSsiTests/WishWalletTests -only-testing:GagaeSsiTests/WishListTests -only-testing:GagaeSsiTests/PaybackTests -quiet
```

Expected: `** TEST SUCCEEDED **`. `test_목록은_진행_중이_먼저…`가 순서로 실패하면 `fetchTrips`의 정렬 키(`startDate` 내림차순)를 확인한다.

- [ ] **Step 8: 커밋**

```bash
git add GagaeSsi/Models/BudgetModels.swift GagaeSsi/Models/WishModels.swift GagaeSsi/Core/CoreDataManager.swift GagaeSsiTests/TripTests.swift
git commit -m "feat: 여행 정산 — 대신 낸 남의 몫은 지갑으로, 지갑이 없으면 오늘 예산으로

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: 소비 입력 — 여행 필드 · 인원 · 결제자 · 지갑 자동 선택

**Files:**
- Modify: `GagaeSsi/Core/Utils/FormatterUtils.swift` (`shortDateRange` 추가)
- Modify: `GagaeSsi/Features/Spend/SpendViewModel.swift`
- Modify: `GagaeSsi/Features/Spend/SpendView.swift`

UI 로직이라 단위 테스트 대신 빌드 + 시뮬레이터 확인으로 검증한다. 모델·데이터 계층은 앞 태스크에서 이미 테스트됐다.

- [ ] **Step 1: 기간 포맷터**

`FormatterUtils.swift`의 `relativeDate` 뒤에:

```swift
    /// 여행 기간 표시 (예: 9.12–9.14). 같은 날이면 한 번만.
    static func shortDateRange(_ from: Date, _ to: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M.d"
        let start = formatter.string(from: from)
        let end = formatter.string(from: to)
        return start == end ? start : "\(start)–\(end)"
    }
```

- [ ] **Step 2: `SpendViewModel` 여행 상태**

`spendableWishes` 선언 뒤에 추가:

```swift
    // MARK: 여행
    /// 이 소비를 묶을 여행 (nil이면 평소 소비)
    var tempTripId: UUID?
    /// 나누는 인원 (1 = 내 개인 소비)
    var tempParticipants: Int = 1
    /// 내가 냈는지
    var tempPaidByMe: Bool = true
    /// 고를 수 있는 여행들 — 진행 중 + (편집 중이면) 그 기록이 묶인 정산 완료 여행
    var activeTrips: [TripModel] = []
    /// 사용자가 "여행 아님"을 직접 골랐으면 날짜를 바꿔도 다시 자동 선택하지 않는다
    private var tripAutoSelectDismissed = false
    /// 지갑이 여행 때문에 자동으로 골라졌는지 — 금액이 잔액을 넘으면 조용히 풀어준다
    private var walletAutoSelected = false

    var selectedTrip: TripModel? {
        activeTrips.first { $0.id == tempTripId }
    }
    /// 정산 완료 여행의 소비는 여행·인원·결제자를 못 바꾼다
    var isTripLocked: Bool { selectedTrip?.isSettled == true }
    /// 공용 소비면 환급 필드를 숨긴다 — 정산과 겹치면 이중 반영
    var isSharedSpending: Bool { tempTripId != nil && tempParticipants > 1 }

    /// 지금 입력값으로 만든 임시 기록 — 내 몫·부담액 미리보기용
    var previewRecord: SpendingRecordModel {
        SpendingRecordModel(title: tempTitle, amount: tempAmount, date: tempDate,
                            tripId: tempTripId,
                            participants: tempTripId == nil ? 1 : tempParticipants,
                            paidByMe: tempTripId == nil ? true : tempPaidByMe)
    }

    /// 인원·결제자에 따라 이 소비가 어떻게 잡히는지 한 줄
    var tripPreviewText: String {
        let p = previewRecord
        guard p.isShared, p.amount > 0 else { return "" }
        let share = FormatterUtils.currencyString(from: p.myShare)
        if p.paidByMe {
            return "내 몫 \(share) · 정산 때 \(FormatterUtils.currencyString(from: p.receivable)) 돌아와요"
        }
        return "내 몫 \(share)만 오늘 예산에서 빠져요"
    }
```

`wishCoversAmount`와 `selectedWishLimit`을 부담액 기준으로 교체:

```swift
    /// 고른 지갑으로 이 소비의 부담액을 감당할 수 있는지 (친구가 낸 소비는 내 몫만)
    var wishCoversAmount: Bool {
        guard let wishId = tempWishItemId else { return true }
        return previewRecord.budgetAmount <= CoreDataManager.shared.wishSpendableLimit(for: wishId,
                                                                                      excluding: editingRecordId)
    }
```

(`selectedWishLimit`은 그대로.)

`loadSpendableWishes()` 뒤에 여행 메서드들 추가:

```swift
    /// 고를 수 있는 여행을 불러온다 (화면 진입·편집 시작·저장 후)
    func loadActiveTrips() {
        var trips = CoreDataManager.shared.fetchActiveTrips()
        // 편집 중인 기록이 정산 완료 여행에 묶여 있으면 그 여행도 보여야 한다 (잠긴 채로)
        if let id = tempTripId, !trips.contains(where: { $0.id == id }),
           let linked = CoreDataManager.shared.fetchTrip(id: id) {
            trips.append(linked)
        }
        activeTrips = trips
        autoSelectTrip()
    }

    /// 소비 날짜가 진행 중 여행 하나의 기간 안이면 그 여행을 미리 고른다
    func autoSelectTrip() {
        guard !isEditing, tempTripId == nil, !tripAutoSelectDismissed,
              let trip = CoreDataManager.shared.trip(containing: tempDate) else { return }
        selectTrip(trip.id)
    }

    /// 여행을 고르거나(id) 푼다(nil). 고르면 인원 기본값과 지갑을 채운다.
    func selectTrip(_ id: UUID?) {
        tempTripId = id
        if let trip = activeTrips.first(where: { $0.id == id }) {
            tempParticipants = max(1, trip.defaultParticipants)
            tempPaidByMe = true
            autoSelectWallet(for: trip)
        } else {
            tripAutoSelectDismissed = true
            tempParticipants = 1
            tempPaidByMe = true
            if walletAutoSelected { tempWishItemId = nil; walletAutoSelected = false }
        }
    }

    /// 사용자가 지갑을 직접 고름 — 자동 선택 상태를 푼다
    func pickWallet(_ id: UUID?) {
        tempWishItemId = id
        walletAutoSelected = false
    }

    /// 여행에 지갑이 있고 잔액이 내 부담액을 덮으면 지갑을 미리 고른다. 부족하면 예산에서.
    private func autoSelectWallet(for trip: TripModel) {
        guard let wishId = trip.wishItemId, tempWishItemId == nil else { return }
        let limit = CoreDataManager.shared.wishSpendableLimit(for: wishId, excluding: editingRecordId)
        if previewRecord.budgetAmount <= limit {
            tempWishItemId = wishId
            walletAutoSelected = true
        }
    }

    /// 금액·인원·결제자가 바뀐 뒤 — 자동으로 골라둔 지갑이 더는 못 덮으면 조용히 예산으로 돌린다
    func revalidateAutoWallet() {
        guard walletAutoSelected else { return }
        if !wishCoversAmount { tempWishItemId = nil; walletAutoSelected = false }
        else if tempWishItemId == nil, let trip = selectedTrip { autoSelectWallet(for: trip) }
    }
```

`updateAmountFromText` 끝에 `revalidateAutoWallet()` 호출 추가:

```swift
    func updateAmountFromText(_ text: String) {
        if let result = FormatterUtils.formatCurrencyInput(text) {
            tempAmount = result.plainNumber
            tempAmountText = result.formatted
        }
        revalidateAutoWallet()
    }
```

`saveSpending`에서 `model.paybackReceived = ...` 줄 뒤에:

```swift
        model.tripId = tempTripId
        model.participants = tempTripId == nil ? 1 : tempParticipants
        model.paidByMe = tempTripId == nil ? true : tempPaidByMe
        // 공용 소비는 정산이 환급 역할을 하므로 환급 필드를 비운다
        if model.isShared { model.expectedPayback = 0 }
```

`beginEdit`에서 `tempWishItemId = record.wishItemId` 뒤에:

```swift
        tempTripId = record.tripId
        tempParticipants = record.participants
        tempPaidByMe = record.paidByMe
        walletAutoSelected = false
        loadActiveTrips()
```

`clearForm`에 초기화 추가 (`editingRecordId = nil` 앞):

```swift
        tempTripId = nil
        tempParticipants = 1
        tempPaidByMe = true
        tripAutoSelectDismissed = false
        walletAutoSelected = false
```

그리고 `clearForm` 맨 끝(`model = ...` 뒤)에 `autoSelectTrip()` — 저장 직후 같은 날 두 번째 소비도 자동으로 여행에 묶이게.

- [ ] **Step 3: `SpendView` — 여행 필드**

`onAppear`에 `viewModel.loadActiveTrips()` 추가 (`loadSpendableWishes()` 뒤). 날짜 변경 감지를 `.onAppear` 체인 뒤에 추가:

```swift
        .onChange(of: viewModel.tempDate) { _, _ in viewModel.autoSelectTrip() }
        .onChange(of: viewModel.tempParticipants) { _, _ in viewModel.revalidateAutoWallet() }
        .onChange(of: viewModel.tempPaidByMe) { _, _ in viewModel.revalidateAutoWallet() }
```

`inputCard`의 필드 목록을 다음으로 (환급 필드는 공용 소비에서 숨김, 여행 필드는 날짜 뒤):

```swift
            VStack(spacing: 18) {
                categoryField
                contentField
                amountField
                if !viewModel.isSharedSpending { paybackField }
                dateField
                if !viewModel.activeTrips.isEmpty { tripField }
                if !viewModel.spendableWishes.isEmpty { wishWalletField }
            }
```

`wishWalletField`의 두 `walletRow` 액션을 `viewModel.pickWallet(nil)` / `viewModel.pickWallet(wish.id)`로 바꾼다.

`wishWalletField` 앞에 여행 필드 추가:

```swift
    /// ⑥ 여행 — 같이 쓴 돈이면 인원과 결제자를 표시한다. 내 몫은 여행이 계산한다
    private var tripField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("🧳", "여행")

            VStack(spacing: 0) {
                walletRow(title: "여행 아님", detail: "평소 소비예요",
                          selected: viewModel.tempTripId == nil) {
                    viewModel.selectTrip(nil)
                }
                ForEach(viewModel.activeTrips) { trip in
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 14)
                    walletRow(title: trip.isSettled ? "\(trip.title) (정산 완료)" : trip.title,
                              detail: "\(FormatterUtils.shortDateRange(trip.startDate, trip.endDate)) · \(trip.defaultParticipants)명",
                              selected: viewModel.tempTripId == trip.id) {
                        viewModel.selectTrip(trip.id)
                    }
                }
            }
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gagaeDivider, lineWidth: 1.5)
            )
            .disabled(viewModel.isTripLocked)

            if viewModel.tempTripId != nil { tripShareFields }
        }
    }

    /// 인원 · 누가 냈나 · 미리보기
    private var tripShareFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("나누는 인원")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                Stepper(value: $viewModel.tempParticipants, in: 1...20) {
                    Text(viewModel.tempParticipants == 1 ? "내 개인 소비" : "\(viewModel.tempParticipants)명")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                }
                .fixedSize()
            }

            if viewModel.tempParticipants > 1 {
                Picker("누가 냈나", selection: $viewModel.tempPaidByMe) {
                    Text("내가 냈어요").tag(true)
                    Text("다른 사람이 냈어요").tag(false)
                }
                .pickerStyle(.segmented)

                if !viewModel.tripPreviewText.isEmpty {
                    Text(viewModel.tripPreviewText)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeGood)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if viewModel.isTripLocked {
                Text("정산이 끝난 여행이라 여행·인원·결제자는 바꿀 수 없어요. 여행 상세에서 정산을 다시 열면 돼요.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.gagaeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(viewModel.isTripLocked)
    }
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project GagaeSsi.xcodeproj -scheme GagaeSsi -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' build -quiet
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 시뮬레이터 수동 확인 (여행 화면은 아직 없으니 테스트 데이터로)**

여행 목록 화면이 Task 9에서 생기므로, 지금은 여행이 없을 때 **여행 필드가 아예 안 보이는지**와 기존 소비 저장이 그대로 되는지만 확인한다. 이후 Task 9 완료 후 Task 9 Step 6에서 전체 흐름을 확인한다.

- [ ] **Step 6: 커밋**

```bash
git add GagaeSsi/Core/Utils/FormatterUtils.swift GagaeSsi/Features/Spend/SpendViewModel.swift GagaeSsi/Features/Spend/SpendView.swift
git commit -m "feat: 소비 입력에 여행 — 인원·결제자만 적으면 내 몫은 앱이 계산

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: 내역 편집 시트에 여행 필드

**Files:**
- Modify: `GagaeSsi/Features/History/HistorySpendEditView.swift`

- [ ] **Step 1: 상태 추가**

`@State private var payback = 0` 뒤에:

```swift
    // 여행
    @State private var tripId: UUID?
    @State private var participants = 1
    @State private var paidByMe = true
    @State private var trips: [TripModel] = []

    private var selectedTrip: TripModel? { trips.first { $0.id == tripId } }
    private var isTripLocked: Bool { selectedTrip?.isSettled == true }
    private var isShared: Bool { tripId != nil && participants > 1 }
    /// 미리보기용 임시 기록
    private var preview: SpendingRecordModel {
        SpendingRecordModel(title: title, amount: amount, date: date, tripId: tripId,
                            participants: tripId == nil ? 1 : participants,
                            paidByMe: tripId == nil ? true : paidByMe)
    }
```

- [ ] **Step 2: 화면 — 날짜 피커와 환급 토글 사이에 여행 블록**

`DatePicker("날짜", ...)` 줄 뒤, `// 환급 예정` 주석 앞에:

```swift
                            // 여행 (진행 중 여행이 있거나 이미 묶여 있을 때만)
                            if !trips.isEmpty {
                                Label("여행", systemImage: "suitcase.fill")
                                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                Picker("여행", selection: $tripId) {
                                    Text("여행 아님").tag(UUID?.none)
                                    ForEach(trips) { t in
                                        Text(t.isSettled ? "\(t.title) (정산 완료)" : t.title).tag(UUID?.some(t.id))
                                    }
                                }
                                .pickerStyle(.menu).tint(.gagaePinkDark)
                                .disabled(isTripLocked)
                                .onChange(of: tripId) { _, newValue in
                                    if let t = trips.first(where: { $0.id == newValue }) {
                                        participants = max(1, t.defaultParticipants); paidByMe = true
                                    } else { participants = 1; paidByMe = true }
                                }

                                if tripId != nil {
                                    HStack {
                                        Text("나누는 인원").font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                        Spacer()
                                        Stepper(value: $participants, in: 1...20) {
                                            Text(participants == 1 ? "내 개인 소비" : "\(participants)명")
                                                .font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                                        }.fixedSize()
                                    }
                                    if participants > 1 {
                                        Picker("누가 냈나", selection: $paidByMe) {
                                            Text("내가 냈어요").tag(true)
                                            Text("다른 사람이 냈어요").tag(false)
                                        }.pickerStyle(.segmented)
                                        if amount > 0 {
                                            Text(paidByMe
                                                 ? "내 몫 \(FormatterUtils.currencyString(from: preview.myShare)) · 정산 때 \(FormatterUtils.currencyString(from: preview.receivable)) 돌아와요"
                                                 : "내 몫 \(FormatterUtils.currencyString(from: preview.myShare))만 그날 예산에서 빠져요")
                                                .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    if isTripLocked {
                                        Text("정산이 끝난 여행이라 여행·인원·결제자는 바꿀 수 없어요.")
                                            .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                    }
                                }
                            }
```

환급 토글 블록 전체(`Toggle(isOn: $hasPayback...)`부터 `if hasPayback { ... }` 끝까지)를 `if !isShared { ... }`로 감싼다.

인원·결제자 컨트롤은 `isTripLocked`일 때 잠근다 — `Stepper`와 `Picker("누가 냈나")` 각각에 `.disabled(isTripLocked)`.

- [ ] **Step 3: 로드·저장**

`loadRecord()` 끝에:

```swift
        tripId = record.tripId
        participants = record.participants
        paidByMe = record.paidByMe
        var active = CoreDataManager.shared.fetchActiveTrips()
        if let id = record.tripId, !active.contains(where: { $0.id == id }),
           let linked = CoreDataManager.shared.fetchTrip(id: id) {
            active.append(linked)
        }
        trips = active
```

`save()`의 `updated.expectedPayback = hasPayback ? payback : 0` 를 다음으로:

```swift
        updated.tripId = tripId
        updated.participants = tripId == nil ? 1 : participants
        updated.paidByMe = tripId == nil ? true : paidByMe
        // 공용 소비는 정산이 환급 역할을 하므로 환급 필드를 비운다
        updated.expectedPayback = (hasPayback && !updated.isShared) ? payback : 0
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project GagaeSsi.xcodeproj -scheme GagaeSsi -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' build -quiet
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add GagaeSsi/Features/History/HistorySpendEditView.swift
git commit -m "feat: 내역에서 소비를 고칠 때도 여행·인원·결제자를 바꿀 수 있게

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: 여행 목록 · 추가/편집 시트 · 설정 진입점

**Files:**
- Create: `GagaeSsi/Features/Trip/TripListView.swift`
- Create: `GagaeSsi/Features/Trip/TripEditView.swift`
- Modify: `GagaeSsi/Features/Settings/SettingsView.swift` (페이백 관리 행 뒤)

기존 `PaybackListView`처럼 View + `@State` + `load()` 패턴을 따른다 (별도 ViewModel 없음 — 화면이 데이터 계층 API를 그대로 보여주기만 한다).

- [ ] **Step 1: `TripEditView.swift`**

```swift
//
//  TripEditView.swift
//  GagaeSsi
//
//  여행 추가/편집 시트 — 제목·기간·인원·지갑 연결
//

import SwiftUI

struct TripEditView: View {
    enum Mode {
        case add
        case edit(TripModel)
        var title: String { switch self { case .add: return "여행 추가"; case .edit: return "여행 수정" } }
    }

    let mode: Mode
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var participants = 2
    @State private var wishItemId: UUID?
    @State private var wallets: [WishItemModel] = []
    @FocusState private var focused: Bool

    private var isValid: Bool { !title.isEmpty && endDate >= startDate && participants >= 1 }
    private var selectedWallet: WishItemModel? { wallets.first { $0.id == wishItemId } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            Label("여행 이름", systemImage: "suitcase.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            TextField("예: 제주 여행, 부산 친구들", text: $title)
                                .font(.gagaeBody).focused($focused)
                                .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary).tint(.gagaePinkDark)
                            DatePicker("종료일", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary).tint(.gagaePinkDark)

                            HStack {
                                Label("인원", systemImage: "person.2.fill")
                                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                Spacer()
                                Stepper(value: $participants, in: 1...20) {
                                    Text("\(participants)명").font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                                }.fixedSize()
                            }
                            Text("소비를 적을 때 인원 기본값이에요. 항목마다 바꿀 수 있어요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)

                            GagaeDivider()

                            // 지갑 연결
                            Label("모아둔 위시 지갑", systemImage: "gift.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            Picker("지갑", selection: $wishItemId) {
                                Text("연결 안 함").tag(UUID?.none)
                                ForEach(wallets) { w in
                                    Text("\(w.title) · 남은 \(FormatterUtils.currencyString(from: w.balance))")
                                        .tag(UUID?.some(w.id))
                                }
                            }
                            .pickerStyle(.menu).tint(.gagaePinkDark)
                            if let w = selectedWallet {
                                Text("이 여행에서 내가 내는 소비는 \(w.title) 지갑(남은 \(FormatterUtils.currencyString(from: w.balance)))에서 먼저 빠지고, 정산으로 돌아온 돈도 지갑으로 와요.")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("연결하지 않으면 평소처럼 하루 예산에서 빠져요.")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) { save() }
                        .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear { load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func load() {
        var list = CoreDataManager.shared.fetchSpendableWishItems()
        if case .edit(let t) = mode {
            title = t.title
            startDate = t.startDate
            endDate = t.endDate
            participants = t.defaultParticipants
            wishItemId = t.wishItemId
            // 연결된 지갑은 잔액이 0이 됐어도 후보로 남겨야 한다
            if let id = t.wishItemId, !list.contains(where: { $0.id == id }),
               let linked = CoreDataManager.shared.fetchWishItems().first(where: { $0.id == id }) {
                list.append(linked)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
        wallets = list
    }

    private func save() {
        guard isValid else { return }
        let ok: Bool
        switch mode {
        case .add:
            ok = CoreDataManager.shared.createTrip(TripModel(
                title: title, startDate: startDate, endDate: endDate,
                defaultParticipants: participants, wishItemId: wishItemId))
        case .edit(let t):
            // updateTrip은 편집 필드만 받는다 — TripModel을 통째로 덮으면 정산 상태
            // (status·settledAmount·settlementEntryId)가 폼 기본값으로 조용히 되돌아간다.
            ok = CoreDataManager.shared.updateTrip(
                id: t.id, title: title, startDate: startDate, endDate: endDate,
                defaultParticipants: participants, wishItemId: wishItemId)
        }
        if ok { onSave(); dismiss() }
    }
}
```

- [ ] **Step 2: `TripListView.swift`**

```swift
//
//  TripListView.swift
//  GagaeSsi
//
//  여행 목록 — 진행 중 / 정산 완료
//

import SwiftUI

struct TripListView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var trips: [TripModel] = []
    @State private var summaries: [UUID: TripSettlementModel] = [:]
    @State private var showAdd = false

    private var active: [TripModel] { trips.filter { !$0.isSettled } }
    private var settled: [TripModel] { trips.filter { $0.isSettled } }

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    infoCard.padding(.top, GagaeSpacing.md)
                    if trips.isEmpty {
                        GagaeCard {
                            GagaeEmptyStateView(icon: "🧳", title: "여행이 없어요",
                                                subtitle: "여행을 만들고 소비를 묶으면\n내 몫만 예산에서 빠지고 나중에 정산할 수 있어요")
                        }
                    } else {
                        section("진행 중", active)
                        section("정산 완료", settled)
                    }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.bottom, GagaeSpacing.xl)
            }
        }
        .navigationTitle("여행")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .onAppear { load() }
        .onChange(of: eventBus.spendingAddedTrigger) { _, _ in load() }
        .sheet(isPresented: $showAdd) { TripEditView(mode: .add) { load() } }
    }

    private var infoCard: some View {
        HStack(spacing: GagaeSpacing.md) {
            Image(systemName: "lightbulb.fill").font(.system(size: 20)).foregroundStyle(.gagaePoint)
            Text("같이 쓴 돈은 내 몫만 예산에서 빠져요.\n내가 대신 낸 돈은 정산 때 돌아와요.")
                .font(.gagaeSubheadline).foregroundStyle(.gagaeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(GagaeSpacing.md).background(Color.gagaePoint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }

    @ViewBuilder
    private func section(_ title: String, _ list: [TripModel]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text(title).font(.gagaeHeadline).foregroundStyle(.gagaeText)
                ForEach(list) { trip in
                    NavigationLink { TripDetailView(tripId: trip.id) } label: { row(trip) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ trip: TripModel) -> some View {
        let s = summaries[trip.id]
        return GagaeCard {
            HStack(spacing: GagaeSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(trip.title).font(.gagaeHeadline).foregroundStyle(.gagaeText)
                        if trip.wishItemId != nil {
                            Text("🎁").font(.system(size: 13))
                        }
                    }
                    Text("\(FormatterUtils.shortDateRange(trip.startDate, trip.endDate)) · \(trip.defaultParticipants)명")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    if trip.isSettled, let at = trip.settledAt {
                        Text("\(FormatterUtils.shortDateRange(at, at)) 정산 · +\(FormatterUtils.currencyString(from: trip.settledAmount)) 돌아옴")
                            .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("내 몫").font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                    Text(FormatterUtils.currencyString(from: s?.myShareTotal ?? 0))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaeText)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    private func load() {
        trips = CoreDataManager.shared.fetchTrips()
        summaries = Dictionary(uniqueKeysWithValues: trips.map {
            ($0.id, CoreDataManager.shared.tripSettlement(for: $0.id))
        })
    }
}
```

`TripDetailView`는 Task 10에서 만든다. 이 태스크만 빌드하려면 임시로 빈 뷰를 두지 말고 **Task 10까지 이어서 진행한 뒤** 빌드한다.

- [ ] **Step 3: 설정 진입점**

`SettingsView.swift`에서 `PaybackListView()` NavigationLink 블록(`.buttonStyle(.plain)`까지) 뒤에:

```swift
                rowDivider
                NavigationLink {
                    TripListView()
                } label: {
                    settingRow(iconBg: Color(hex: "#4FB0C6"), iconContent: AnyView(Text("🧳").font(.system(size: 15))),
                               label: "여행")
                }
                .buttonStyle(.plain)
```

- [ ] **Step 4: 커밋은 Task 10 Step 4에서 함께**

---

### Task 10: 여행 상세 · 정산 시트

**Files:**
- Create: `GagaeSsi/Features/Trip/TripDetailView.swift`
- Create: `GagaeSsi/Features/Trip/TripSettleSheet.swift`

- [ ] **Step 1: `TripSettleSheet.swift`**

```swift
//
//  TripSettleSheet.swift
//  GagaeSsi
//
//  정산 시트 — 계산된 받을 돈을 보여주고, 실제 금액을 고칠 수 있게 한다
//

import SwiftUI

struct TripSettleSheet: View {
    let trip: TripModel
    let settlement: TripSettlementModel
    /// 연결된 지갑 이름 (nil이면 예산으로)
    let walletTitle: String?
    let onSettle: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var amount = 0

    private var differsFromComputed: Bool { amount != settlement.receivable }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            Text("🧳 \(trip.title)").font(.gagaeHeadline).foregroundStyle(.gagaeText)

                            line("공용 지출", settlement.sharedTotal)
                            if let n = settlement.uniformParticipants, let per = settlement.perPersonSpending {
                                HStack {
                                    Text("÷ \(n)명").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                    Spacer()
                                    Text("인당 \(FormatterUtils.currencyString(from: per))")
                                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                }
                            } else {
                                line("내 몫 합계", settlement.myShareTotal)
                            }
                            line("내가 낸 돈", settlement.paidByMeTotal)

                            GagaeDivider()

                            Label("받을 돈", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) {
                                            amount = r.plainNumber; amountText = r.formatted
                                        } else if v.isEmpty { amount = 0 }
                                    }
                            }
                            .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            if differsFromComputed {
                                Text("계산과 다른 금액이에요 (계산: \(FormatterUtils.currencyString(from: settlement.receivable)))")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                            }

                            if let walletTitle {
                                Text("→ 🎁 \(walletTitle) 지갑으로 돌아가요")
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeGood)
                            } else {
                                Text("→ 오늘 예산으로 들어와요")
                                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeGood)
                            }
                            Text("정산하면 이 여행에 소비를 더 넣거나 고칠 수 없어요. 필요하면 정산을 다시 열 수 있어요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: amount > 0 ? "정산 완료" : "받을 돈 없이 정산 완료", isEnabled: true) {
                        onSettle(amount); dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("정산").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark) } }
            .onAppear {
                amount = settlement.receivable
                amountText = settlement.receivable > 0 ? FormatterUtils.inputAmountString(from: settlement.receivable) : ""
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func line(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
            Spacer()
            Text(FormatterUtils.currencyString(from: value)).font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
        }
    }
}
```

- [ ] **Step 2: `TripDetailView.swift`**

```swift
//
//  TripDetailView.swift
//  GagaeSsi
//
//  여행 상세 — 총 지출 / 내 몫 / 내가 낸 돈 / 받을 돈, 소비 목록, 정산
//

import SwiftUI

struct TripDetailView: View {
    let tripId: UUID

    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss
    @State private var trip: TripModel?
    @State private var records: [SpendingRecordModel] = []
    @State private var settlement = TripSettlementModel.compute(records: [])
    @State private var walletTitle: String?
    @State private var showEdit = false
    @State private var showSettle = false
    @State private var showDeleteConfirm = false
    @State private var showReopenFailed = false
    @State private var editingRecord: SpendingRecordModel?

    private let cal = Calendar.current

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()
            if let trip {
                ScrollView {
                    VStack(spacing: GagaeSpacing.lg) {
                        if trip.isSettled { settledCard(trip) } else { summaryCard }
                        recordsSection(trip)
                        if !trip.isSettled {
                            GagaePrimaryButton(title: "정산하기", isEnabled: !records.isEmpty) { showSettle = true }
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)
                    .padding(.bottom, GagaeSpacing.xl)
                }
            }
        }
        .navigationTitle(trip?.title ?? "여행")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("여행 수정") { showEdit = true }
                    Button("여행 삭제", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 18)).foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .onAppear { load() }
        .onChange(of: eventBus.spendingAddedTrigger) { _, _ in load() }
        .sheet(isPresented: $showEdit) {
            if let trip { TripEditView(mode: .edit(trip)) { load() } }
        }
        .sheet(isPresented: $showSettle) {
            if let trip {
                TripSettleSheet(trip: trip, settlement: settlement, walletTitle: walletTitle) { amount in
                    if CoreDataManager.shared.settleTrip(id: trip.id, actualAmount: amount) {
                        eventBus.notifySpendingAdded()   // 예산·지갑 크레딧 → 홈 갱신
                        load()
                    }
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            HistorySpendEditView(record: record) {
                eventBus.notifySpendingAdded()
                load()
            }
        }
        .confirmationDialog("여행을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if CoreDataManager.shared.deleteTrip(id: tripId) {
                    eventBus.notifySpendingAdded()
                    dismiss()
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("소비 기록은 그대로 남고 여행 연결만 풀려요. 이미 정산한 돈은 돌려받지 않아요.")
        }
        .alert("되돌릴 수 없어요", isPresented: $showReopenFailed) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("지갑으로 돌아온 정산금을 이미 다른 소비에 써서 정산을 다시 열 수 없어요.")
        }
    }

    // MARK: - 요약

    private var summaryCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.md) {
                HStack(spacing: GagaeSpacing.sm) {
                    cell("총 지출", settlement.totalPaid, .gagaeText)
                    cell("내 몫", settlement.myShareTotal, .gagaeText)
                }
                HStack(spacing: GagaeSpacing.sm) {
                    cell("내가 낸 돈", settlement.paidByMeTotal, .gagaeText)
                    cell(settlement.receivable > 0 ? "받을 돈" : "받을 돈 없음", settlement.receivable,
                         settlement.receivable > 0 ? .gagaeGood : .gagaeTextTertiary)
                }
                if walletTitle != nil {
                    Text("🎁 지갑에서 \(FormatterUtils.currencyString(from: settlement.fromWallet)) · 예산에서 \(FormatterUtils.currencyString(from: settlement.fromBudget))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                }
            }
        }
    }

    private func cell(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
            Text(FormatterUtils.currencyString(from: value))
                .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(color)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GagaeSpacing.sm)
        .background(Color.gagaeSurface)
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }

    private func settledCard(_ trip: TripModel) -> some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("✅ 정산 완료").font(.gagaeHeadline).foregroundStyle(.gagaeGood)
                if let per = settlement.perPersonSpending, let n = settlement.uniformParticipants {
                    Text("인당 \(FormatterUtils.currencyString(from: per)) (\(n)명)")
                        .font(.gagaeSubheadline).foregroundStyle(.gagaeText)
                } else {
                    Text("내 몫 \(FormatterUtils.currencyString(from: settlement.myShareTotal))")
                        .font(.gagaeSubheadline).foregroundStyle(.gagaeText)
                }
                Text("받은 돈 \(FormatterUtils.currencyString(from: trip.settledAmount)) · \(walletTitle.map { "🎁 \($0) 지갑으로 돌아감" } ?? "오늘 예산으로 들어옴")")
                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let at = trip.settledAt {
                    Text(FormatterUtils.formattedDate(at)).font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                }
                GagaeSecondaryButton(title: "정산 다시 열기") {
                    if CoreDataManager.shared.reopenTrip(id: trip.id) {
                        eventBus.notifySpendingAdded()
                        load()
                    } else {
                        showReopenFailed = true
                    }
                }
            }
        }
    }

    // MARK: - 소비 목록

    private func recordsSection(_ trip: TripModel) -> some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            Text("소비 \(records.count)건").font(.gagaeHeadline).foregroundStyle(.gagaeText)
            if records.isEmpty {
                GagaeCard {
                    GagaeEmptyStateView(icon: "🧳", title: "아직 묶인 소비가 없어요",
                                        subtitle: "기록 탭에서 소비를 적을 때 이 여행을 고르면 여기 모여요")
                }
            } else {
                ForEach(groupedByDay, id: \.day) { group in
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                            Text(FormatterUtils.formattedDate(group.day))
                                .font(.gagaeCaptionMedium).foregroundStyle(.gagaeTextSecondary)
                            ForEach(group.records) { r in
                                recordRow(r, locked: trip.isSettled)
                                if r.id != group.records.last?.id { GagaeDivider() }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedByDay: [(day: Date, records: [SpendingRecordModel])] {
        let dict = Dictionary(grouping: records) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted().map { (day: $0, records: dict[$0] ?? []) }
    }

    private func recordRow(_ r: SpendingRecordModel, locked: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(r.category.color.opacity(0.13)).frame(width: 34, height: 34)
                Text(r.category.emoji).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.title.isEmpty ? r.category.rawValue : r.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.gagaeText).lineLimit(1)
                HStack(spacing: 4) {
                    if r.isShared {
                        chip("\(r.participants)명")
                        chip(r.paidByMe ? "내가 냄" : "친구가 냄")
                    } else {
                        chip("개인")
                    }
                    if r.wishItemId != nil { chip("🎁 지갑") }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(FormatterUtils.currencyString(from: r.amount))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.gagaeText)
                if r.isShared {
                    Text("내 몫 \(FormatterUtils.currencyString(from: r.myShare))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !locked { editingRecord = r } }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.gagaeTextSecondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.gagaeSurfaceAlt).clipShape(Capsule())
    }

    // MARK: - Load

    private func load() {
        trip = CoreDataManager.shared.fetchTrip(id: tripId)
        records = CoreDataManager.shared.fetchSpendingRecords(tripId: tripId)
        settlement = TripSettlementModel.compute(records: records)
        walletTitle = trip?.wishItemId.flatMap { id in
            CoreDataManager.shared.fetchWishItems().first { $0.id == id }?.title
        }
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project GagaeSsi.xcodeproj -scheme GagaeSsi -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' build -quiet
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋 (Task 9 파일 포함)**

```bash
git add GagaeSsi/Features/Trip GagaeSsi/Features/Settings/SettingsView.swift
git commit -m "feat: 여행 화면 — 목록·추가·상세·정산 시트, 설정 진입점

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 5: 시뮬레이터로 전체 흐름 확인**

`mcp__Claude_Code_iOS_Simulator__control`로 앱을 띄워 아래를 순서대로 확인한다. 한 항목이라도 어긋나면 해당 태스크로 돌아간다.

1. 설정 › 여행 › + → "제주" / 오늘~모레 / 3명 / 지갑 연결 안 함 → 저장 → 진행 중 섹션에 나타남
2. 기록 탭 → 소비 입력에 🧳 여행 필드가 보이고 "제주"가 **자동 선택**돼 있음, 인원 3명
3. 금액 90,000 · "내가 냈어요" → 미리보기 "내 몫 30,000원 · 정산 때 60,000원 돌아와요" → 저장
4. 홈: 오늘 잔액이 90,000 줄었음
5. 기록 탭 → 30,000 · "다른 사람이 냈어요" → "내 몫 10,000원만 오늘 예산에서 빠져요" → 저장 → 홈 잔액 10,000 추가 감소
6. 설정 › 여행 › 제주 → 총 지출 120,000 / 내 몫 40,000 / 내가 낸 돈 90,000 / 받을 돈 60,000
7. 정산하기 → 시트에 인당 40,000 · 받을 돈 60,000 → 정산 완료 → 홈 잔액 +60,000, 목록이 정산 완료로 이동
8. 상세에서 소비 행을 탭해도 편집이 열리지 않음 (잠김) → "정산 다시 열기" → 진행 중으로 복귀, 홈 잔액 −60,000
9. 여행 삭제 → 기록 탭 오늘 목록에 소비 2건이 그대로 있음

---

### Task 11: 내역 배지 · 내 몫 표시 · 위시 정산 회수 표시

**Files:**
- Modify: `GagaeSsi/Features/History/HistoryViewModel.swift` (여행 제목 맵)
- Modify: `GagaeSsi/Features/History/HistoryView.swift` (`recordRow`)
- Modify: `GagaeSsi/Features/Spend/SpendView.swift` (`spendingRow`)
- Modify: `GagaeSsi/Features/Stats/CategoryDetailView.swift` ("전체 기록" 행의 금액 표시)
- Modify: `GagaeSsi/Features/Wishlist/WishListView.swift` (지갑 표시)

> **개별 기록 행의 금액 표시도 `myShare`로 통일한다.** Task 4에서 합계는 전부 렌즈를 맞췄지만
> 행 단위 표시는 그대로 `amount`인 곳이 남아 있다 — 합계는 내 몫인데 그 아래 행들은 결제 전액이면
> 더해봐도 합이 안 맞는다. 내역(`HistoryView.recordRow`)·기록 탭(`SpendView.spendingRow`)·
> 카테고리 상세("전체 기록") 세 곳을 같이 바꾸고, 공용 소비에는 결제 전액을 보조 줄로 따로 보여준다.

- [ ] **Step 1: `HistoryViewModel`에 여행 제목 맵**

`private(set) var monthTotal: Int = 0` 뒤에:

```swift
    /// 여행 배지용 — 기록의 tripId → 여행 이름
    private(set) var tripTitles: [UUID: String] = [:]
```

`load()`에서 `let records = CoreDataManager.shared.fetchSpendingRecords(year: year, month: month)` 줄 앞에:

```swift
        tripTitles = Dictionary(uniqueKeysWithValues: CoreDataManager.shared.fetchTrips().map { ($0.id, $0.title) })
```

- [ ] **Step 2: `HistoryView.recordRow` — 내 몫과 배지**

`recordRow`의 `VStack(alignment: .leading, spacing: 1)` 안, 🎁 배지 블록 뒤에:

```swift
                // 여행 소비 — 배지는 여행 상세로, 공용이면 결제 정보를 한 줄 더
                if let tripId = record.tripId {
                    NavigationLink {
                        TripDetailView(tripId: tripId)
                    } label: {
                        Text("🧳 \(viewModel.tripTitles[tripId] ?? "여행")")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.gagaePinkDark)
                    }
                    .buttonStyle(.plain)
                }
                if record.isShared {
                    Text("결제 \(FormatterUtils.currencyString(from: record.amount)) · \(record.participants)명 · \(record.paidByMe ? "내가 냄" : "친구가 냄")")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
```

금액 표시를 내 몫으로:

```swift
            Text("-" + FormatterUtils.currencyString(from: record.myShare))
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.gagaeDanger)
```

- [ ] **Step 3: `SpendView.spendingRow` — 오늘 목록도 같은 규칙**

`spendingRow`에서 금액 `Text("-" + FormatterUtils.currencyString(from: record.amount))`를 `record.myShare`로 바꾸고, 제목 아래 `if record.expectedPayback > 0 { ... } else { ... }` 블록 **앞**에:

```swift
                if record.isShared {
                    Text("🧳 결제 \(FormatterUtils.currencyString(from: record.amount)) · \(record.participants)명 · \(record.paidByMe ? "내가 냄" : "친구가 냄")")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                } else if record.tripId != nil {
                    Text("🧳 여행 개인 소비")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
```

- [ ] **Step 4: `WishListView` — 정산으로 돌아온 돈**

`Text("모은 \(...) 중 \(...) 썼어요")` 줄 뒤에:

```swift
                    if item.returnedAmount > 0 {
                        Text("🧳 여행 정산으로 \(FormatterUtils.currencyString(from: item.returnedAmount)) 돌아왔어요")
                            .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                    }
```

- [ ] **Step 5: 빌드 + 전체 테스트**

```bash
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -quiet
```

Expected: `** TEST SUCCEEDED **` — 전체 스위트.

- [ ] **Step 6: 시뮬레이터 확인**

1. 기록 탭 오늘 목록: 공용 소비 행이 내 몫 금액 + "🧳 결제 90,000 · 3명 · 내가 냄"
2. 내역 탭: 같은 행에 `🧳 제주` 배지 → 탭하면 여행 상세로 이동
3. 캘린더 일별 합계가 내 몫 합(40,000)
4. 지갑 연결 여행을 정산한 뒤 설정 › 위시리스트: "🧳 여행 정산으로 X 돌아왔어요"

- [ ] **Step 7: 커밋**

```bash
git add GagaeSsi/Features/History/HistoryViewModel.swift GagaeSsi/Features/History/HistoryView.swift GagaeSsi/Features/Spend/SpendView.swift GagaeSsi/Features/Wishlist/WishListView.swift
git commit -m "feat: 내역엔 내 몫과 여행 배지, 지갑엔 정산으로 돌아온 돈

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## 마무리

- [ ] 스펙 `상태`를 `설계 (구현 전)` → `구현 완료`로 바꾸고 커밋 (`docs:`)
- [ ] `develop`에서 `main`으로 PR. 본문에 스펙·계획 링크와 시뮬레이터 확인 항목(Task 10 Step 5, Task 11 Step 6) 결과를 적는다.
