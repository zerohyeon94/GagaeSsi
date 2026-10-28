# 설계: 사용자가 직접 만드는 소비 카테고리 (#35)

- 기획서: `docs/기획/35-custom-spending-category.md`
- 화면 디자인: `docs/디자인/35-custom-spending-category.md`
- 변경 유형: 기능 변경 (feature_change) · 대상 기능: 가게씨 - 소비 기록과 과거 내역
- 작성: 개발팀(Alpha), 2026-10-29

---

## 1. 목표와 범위

### 목표
- 사용자가 이름·이모지·색을 정해 카테고리를 만들고, 기록·내역 수정·목록 행·통계·페이백·자동완성·CSV에서
  내장 7개와 똑같이 쓴다.
- 이름 변경·삭제가 과거 기록·통계 합계·예산/이월 계산을 깨지 않는다.

### 범위 (기획 3장 그대로)
- 카테고리 관리 화면, 추가·수정 시트, 삭제 확인, 소비 기록 칩 끝 "＋ 추가"
- 사용자 카테고리를 쓰는 모든 표시 지점 반영
- 데이터 초기화 시 사용자 카테고리 삭제

### 범위 밖
- 기획 4장 표 전부(내장 변경, 정렬, 하위 분류, 카테고리 예산, 다른 엔티티에 카테고리, 기타 일괄 이동)
- 디자인 9장 제안(도넛 "그 외" 묶기, 내장 7색 다크 대응) — 이번에 손대지 않는다
- 예산 계산 코드(`DailyBudgetCalculator`, `processDailyBudgets`, 장부)는 **한 줄도 바꾸지 않는다.**
  계산 규칙 문서도 바뀌지 않는다.

---

## 2. 핵심 결정: 저장 방식 = 안정 ID 참조

### 지금 상태 (코드에서 확인)
- `SpendingRecord.category: String`에 한글 이름("식비")을 저장한다. 읽을 때
  `SpendingCategory.from(rawValue:)`로 enum으로 바꾸고, 모르는 값은 `.other`.
- `Payback.linkedCategory: String?`도 같은 한글 이름. 읽을 때 `SpendingCategory(rawValue:)` — 모르는 값은
  **nil**(연결 해제)이 된다. 이 차이에 주의한다.
- 화면·집계는 모두 `SpendingCategory` enum 값을 직접 쓴다(`dict[record.category]`, `$0.category == category`,
  `.emoji/.color/.rawValue`).

### 결정
기존 문자열 칸을 그대로 쓰되 값의 형식을 하나 늘린다.

| 종류 | 저장 값 (`SpendingRecord.category`, `Payback.linkedCategory`) |
|---|---|
| 내장 | 지금과 같은 한글 이름 `"식비"` … `"기타"` (변경 없음) |
| 사용자 | `"user:<UUID 문자열>"` 예: `"user:6F1C…"` |

- **이름 변경은 `UserCategory` 한 행만 바꾼다.** 기록·페이백은 ID를 들고 있으므로 손대지 않는다.
  → 완료 기준 3(과거 기록·통계·페이백이 새 이름, 합계 동일)이 구조적으로 보장된다.
- **삭제는 그 ID를 가진 기록·페이백을 `"기타"`로 일괄 갱신**하고 행을 지운다(한 번의 save).
- `SpendingRecord`, `Payback` 엔티티의 속성은 바뀌지 않는다. 기존 데이터 변환(마이그레이션 코드) 없음.

### 버린 대안
| 대안 | 버린 이유 |
|---|---|
| 이름 문자열 저장 + 이름 변경 시 일괄 갱신 | 이름 변경마다 기록 전체를 훑어 바꿔야 하고, 중간 실패 시 옛 이름 기록이 기타로 떨어진다(기획 7장 위험 그대로). 대소문자 무시 중복 규칙과 정확 일치 저장이 어긋날 여지도 있다 |
| `SpendingRecord`에 `categoryId: UUID?` 속성 추가 | 내장/사용자 두 칸을 함께 해석해야 하고 마이그레이션·CSV·테스트 지점이 늘어난다. 문자열 칸 하나로 충분하다 |
| 내장 7개도 엔티티로 옮김 | 기존 데이터 변환이 필요하고 "기본 고정" 요구와도 맞지 않는다 |

---

## 3. 데이터 계층

### 3-1. CoreData 모델 버전 13 (신규)
`GagaeSsi 13.xcdatamodel`을 12에서 복사해 만들고 `.xccurrentversion`을 13으로 올린다.
**엔티티 추가만** 하므로 lightweight migration(이미 켜져 있음) 범위다.

```
UserCategory (codeGenerationType="class")
  id         UUID     필수
  name       String   필수
  emoji      String   필수, 기본 "💸"
  colorKey   String   필수, UserCategoryColor.rawValue
  createdAt  Date     필수 (표시 순서 = createdAt 오름차순)
```

### 3-2. 값 타입 (`Models/UserCategoryModels.swift`, 신규)
- `UserCategoryModel` — `id, name, emoji, color: UserCategoryColor, createdAt`, `init(entity:)`.
  모르는 `colorKey`는 팔레트 첫 색(`rose`)으로 읽는다.
- `CategoryKey: Hashable` — 기록이 가리키는 카테고리.
  ```swift
  enum CategoryKey: Hashable {
      case builtIn(SpendingCategory)
      case user(UUID)
      init(storageValue: String?)   // "user:<uuid>" → .user, 그 외 → .builtIn(SpendingCategory.from(rawValue:))
      var storageValue: String      // 저장용 문자열
      static let other = CategoryKey.builtIn(.other)
  }
  ```
  - `"user:"` 접두사 뒤가 UUID로 안 읽히면 `.builtIn(.other)`.
  - 내장 이름에는 `:`이 없으므로 충돌하지 않는다.
- `CategoryInfo` — 화면이 읽는 표시 정보 `key, name, emoji, color, isBuiltIn` (디자인 1-3의 "이름·이모지·색 세 가지").
- `UserCategoryRules` — 순수 함수 묶음(테스트 대상).
  - `maxCount = 20`, `maxNameLength = 10`(grapheme = Swift `Character` 수)
  - `normalizedName(_:)` 앞뒤 공백 제거
  - `clamp(_:)` 10자 초과분 자르기(입력칸 바인딩에서 사용)
  - `validate(name:existingNames:excluding:currentCount:) -> UserCategoryError?`
    - 빈 이름 → `.emptyName`, 10자 초과 → `.nameTooLong`, 21번째 → `.limitReached`
    - 중복: 내장 7개 이름 + 다른 사용자 카테고리 이름과 **앞뒤 공백 제거 + `localizedCaseInsensitiveCompare`** 비교,
      수정 시 자기 자신 제외 → `.duplicateName`
  - `firstEmoji(in:) -> String?` — 문자열의 `Character`를 앞에서부터 보며 첫 이모지 하나를 돌려준다.
    판정: 첫 scalar가 `isEmoji`이고 (`isEmojiPresentation` 이거나 scalar가 2개 이상[VS16·ZWJ·키캡]).
    "1", "#" 같은 숫자·기호(단독 `isEmoji`=true)는 이모지로 보지 않는다. "👨‍👩‍👧"은 한 `Character`라 그대로 남는다.
  - `defaultColor(used:) -> UserCategoryColor` — 아직 안 쓴 첫 색, 모두 썼으면 `rose`.
- `UserCategoryError: Error` — 위 4개 + `.saveFailed`.

### 3-3. `UserCategoryColor` 팔레트 (`Common/DesignSystem.swift`)
- `enum UserCategoryColor: String, CaseIterable` 8색(`rose … plum`), `var color: Color`는
  `Color.adaptive(light:dark:)`로 디자인 1-2 표의 hex를 쓴다. `var label: String`(접근성 "장미" 등).
- 저장은 rawValue. hex를 저장하지 않으므로 나중에 값을 다듬어도 기록이 따라온다.
- 흰 글자 대비는 구현 때 실측(디자인 10장)하고, 4.5 미만이면 해당 값만 어둡게 조정한다.

### 3-4. `CategoryCatalog` (`Core/CategoryCatalog.swift`, 신규)
사용자 카테고리 목록을 메모리에 들고 `CategoryKey → CategoryInfo`를 풀어 주는 곳.

```swift
@Observable final class CategoryCatalog {
    static let shared = CategoryCatalog()
    private(set) var userCategories: [UserCategoryModel] = []

    init(userCategories: [UserCategoryModel] = [])   // 테스트에서 직접 주입
    func reload(from manager: CoreDataManager = .shared)

    var all: [CategoryInfo]                 // 내장 7 → 사용자(createdAt 순)
    var canAddMore: Bool                    // userCategories.count < 20
    func info(for key: CategoryKey) -> CategoryInfo      // 모르는 .user(id) → 기타
    func normalize(_ key: CategoryKey) -> CategoryKey    // 모르는 .user(id) → .other
}
```

- `@Observable`이라 `CategoryCatalog.shared`를 읽는 뷰는 `reload()` 후 자동으로 다시 그려진다.
  `SpendingRecordModel` 같은 값 타입에서 바로 쓰도록 `CategoryKey`에 편의 속성
  `var info: CategoryInfo { CategoryCatalog.shared.info(for: self) }`를 둔다.
- 앱 시작 시 `RootView` `.task`(또는 `GagaeSsiApp` init)에서 한 번 `reload()`.
  추가·수정·삭제 성공 후, 데이터 초기화 후에도 `reload()` + `eventBus.notifyCategoryChanged()`.
- **왜 싱글톤인가**: 표시 지점이 10곳 이상이고 대부분 값 타입(`record.category.emoji`)에서 읽는다.
  모든 뷰에 목록을 넘기면 변경 범위가 두 배가 된다. `CoreDataManager.shared`와 같은 관례를 따른다.
  순수 로직(`info/normalize`)은 주입한 인스턴스로 테스트한다.

### 3-5. `CoreDataManager` 추가 API (`Core/CoreDataManager.swift`)

| 메서드 | 동작 |
|---|---|
| `fetchUserCategories() -> [UserCategoryModel]` | createdAt 오름차순 |
| `addUserCategory(name:emoji:color:) throws -> UserCategoryModel` | `UserCategoryRules.validate` 통과 시 저장. 이모지는 `firstEmoji` 결과(없으면 💸) |
| `updateUserCategory(_ model:) throws` | 같은 검증(자기 제외). 이름·이모지·색만 바꾼다 |
| `userCategoryUsage(id:) -> (records: Int, paybacks: Int)` | `count(for:)` + `category == %@` / `linkedCategory == %@ AND type == period` |
| `deleteUserCategory(id:) throws -> (records: Int, paybacks: Int)` | 그 ID 기록의 `category`와 페이백의 `linkedCategory`를 `"기타"`로 바꾸고 행 삭제, **save 1회** |
| `resetAllData()` | `entityNames`에 `"UserCategory"` 추가 |

- 저장 실패 시 `context.rollback()` 후 `.saveFailed`를 던진다. 지금 `saveContext()`는 실패해도 변경을
  컨텍스트에 남기므로, 반쯤 바뀐 상태가 다음 save에 섞이지 않게 이 메서드들만 rollback을 붙인다.
- 기록 갱신은 `NSBatchUpdateRequest`가 아니라 fetch 후 속성 대입으로 한다(`renameSpendingTitles`와 같은
  방식). 열린 화면의 managed object와 어긋나지 않고, 기록 수가 수천 건 수준이라 성능 문제 없음.
- 기존 쓰기 지점 변경: `newSpendingRecord.category = model.category.storageValue`(565·642행),
  `e.linkedCategory = m.linkedCategory?.storageValue`(428행).
- `linkedSpending(for:)`의 필터를 `catalog.normalize($0.category) == catalog.normalize(category)`로.

### 3-6. 기존 모델 타입 변경
- `SpendingRecordModel.category: SpendingCategory` → `CategoryKey`
  (`init(entity:)`는 `CategoryKey(storageValue: entity.category)`, 기본값 `.other`).
- `PaybackModel.linkedCategory: SpendingCategory?` → `CategoryKey?`.
  `init(entity:)`는 nil/빈 값만 nil, 나머지는 `CategoryKey(storageValue:)`.
  (예전엔 모르는 문자열이 nil이었지만 지금 저장된 값은 모두 내장 이름이라 동작 차이 없음.)
- `SpendingEditDraft.category`, `SpendingSuggestion.category`, `SpendViewModel.tempCategory`,
  `HistorySpendEditView.category`, `PaybackSheets.linkedCategory`, `StatsViewModel.CategoryTotal.category`,
  `CategoryDetailView.category` → `CategoryKey`.
- 타입을 바꾸면 컴파일러가 `.rawValue`를 쓰던 곳(CSV, 제목 대체 글, 통계 제목)을 모두 잡아 준다.
  → 이름 표시는 전부 `key.info.name`으로 바꾼다. **CSV가 `"user:…"`를 내보내는 실수를 막는 장치**이기도 하다.
- `SpendingEditDraft`의 "제목이 비면 카테고리 이름" 규칙(`result.title = category.rawValue`)은
  `category.info.name`으로 바꾼다. 저장 시점의 이름이 제목으로 굳는 기존 동작은 유지(내장과 같음).

### 3-7. 이벤트
`AppEventBus`에 `categoryChangedTrigger: UUID` + `notifyCategoryChanged()` 추가.
`CategoryCatalog`가 `@Observable`이라 칩 목록은 트리거 없이도 갱신되지만, 집계를 캐시하는 화면
(`StatsViewModel.categoryTotals`, `PaybackListView`, `HistoryViewModel`)은 이 트리거로 다시 계산한다.

---

## 4. 화면 계층

### 4-1. 신규 파일
| 파일 | 내용 |
|---|---|
| `Common/CategoryChip.swift` | 공용 칩. `style: .normal / .payback`, `selected`, 추가 칩 `CategoryChip.add(action:)`. 이모지 `frame(width: 18)`+`lineLimit(1)`, 빈 이모지는 💸. 디자인 7-1 |
| `Features/Settings/CategoryManageView.swift` | `List(.insetGrouped)`. 기본 칩 묶음(흐름 배치: iOS 16+ `Layout` 프로토콜로 간단한 `FlowLayout`) + 사용자 행(스와이프·VoiceOver 삭제) + 추가 행 + 20개 안내 + 토스트 |
| `Features/Settings/CategoryManageViewModel.swift` | `@Observable`. `rows: [(model, usageCount)]`, `loadError`, `pendingDelete`, `deleteMessage`, `toast`. 삭제 확인 문구 생성은 순수 함수 `CategoryDeleteMessage.make(name:records:paybacks:)` |
| `Features/Settings/CategoryEditSheet.swift` | `mode: .add / .edit(UserCategoryModel)`, `onSaved: (UserCategoryModel) -> Void`. 이름(clamp 바인딩·n/10·중복 안내), 이모지 그리드(추천 15 + 직접 입력 → `firstEmoji`), 색 원, 미리보기 `CategoryChip` 2개, 저장 실패 안내, `interactiveDismissDisabled(isDirty)` |

Xcode 프로젝트가 `PBXFileSystemSynchronizedRootGroup`을 쓰므로 새 파일은 pbxproj 수정 없이 포함된다.

### 4-2. 기존 파일 변경
| 파일 | 변경 |
|---|---|
| `SettingsView` | `dataSection` 맨 위 "카테고리 관리" 행(`"기본 7개"`/`"n개"`), 초기화 문구 변경, 초기화 후 `CategoryCatalog.shared.reload()` |
| `SpendView` / `SpendViewModel` | 칩 줄을 `CategoryCatalog.shared.all` + `CategoryChip`으로, 끝에 추가 칩(`canAddMore`일 때만). 시트 `onSaved`에서 `tempCategory = .user(id)` + `ScrollViewReader.scrollTo`. `tempCategory`는 화면 표시·저장 직전에 `normalize`. 자동완성 이모지 `s.category.info.emoji`. 오늘 목록 행 |
| `HistorySpendEditView` | 칩을 `CategoryChip`으로, 목록 출처 `all`. 로드 시 `category = catalog.normalize(record.category)` |
| `HistoryView`, `TripDetailView`, `OverspendHistoryView` | 원 아이콘·제목 대체 글을 `record.category.info`로 |
| `StatsViewModel` | `dict[catalog.normalize(record.category)]`로 집계(모르는 ID는 기타로 합침). `categoryChangedTrigger`에서 재계산 |
| `StatsView` | 색 점·이름·도넛 색을 `item.category.info`로, 이름 `lineLimit(1)`·`truncationMode(.tail)`, 금액 `layoutPriority(1)` |
| `CategoryDetailView` | `category: CategoryKey`, 필터 `normalize` 비교, 제목·빈 화면 문구 `info` |
| `PaybackSheets` / `PaybackListView` | 칩 `CategoryChip(style: .payback)`, `안 씀 → all`, 로드 시 normalize, 연결 표시 `info` |
| `SpendingCSVExporter` | `record.category.info.name` (현재 이름) |
| `SpendingSuggestion` | 최근 카테고리 키를 그대로 들고, 표시는 `info`(삭제된 ID → 기타 💸) |
| `AppEventBus` | `categoryChangedTrigger` |

### 4-3. 흐름
```
[추가]  CategoryEditSheet ─ save ─▶ CoreDataManager.addUserCategory (검증·저장)
          ─▶ CategoryCatalog.shared.reload() ─▶ eventBus.notifyCategoryChanged()
          ─▶ onSaved(model) (SpendView: tempCategory = .user(id), scrollTo)
[수정]  updateUserCategory ─▶ reload ─▶ notify   (기록은 손대지 않음, 표시만 새 이름)
[삭제]  userCategoryUsage(id) ─▶ alert(N건·M개) ─▶ deleteUserCategory(id)
          (기록·페이백 → "기타", 행 삭제, save 1회) ─▶ reload ─▶ notify ─▶ 토스트
[표시]  record.category(CategoryKey) ─▶ CategoryCatalog.info(for:) ─▶ name/emoji/color
          모르는 .user(id) ─▶ 기타
```

---

## 5. 예외 상황 처리 (기획 7장 대응)

| 상황 | 처리 |
|---|---|
| 기존 기록(한글 이름) | 저장 형식 그대로 → `CategoryKey.builtIn`으로 읽힘. 변환 없음 |
| 이름 변경 후 옛 기록 | ID 참조라 영향 없음 |
| 삭제된 ID를 가리키는 선택 칩·수정 중 기록·자동완성·페이백 | `catalog.normalize` / `info(for:)`가 기타로 돌려줌. 저장하면 `"기타"`로 저장 |
| 삭제 일괄 갱신 중 실패 | rollback → 기록·카테고리 모두 원래대로, "삭제하지 못했어요" alert |
| 이모지 칸에 "ab", "🐶🐱", "👨‍👩‍👧" | `firstEmoji` → nil(안내 후 이전 값 유지) / "🐶" / "👨‍👩‍👧". 칩은 18pt 고정 폭으로 한 번 더 막음 |
| 21번째 추가 | UI(추가 칩 숨김·버튼 비활성) + `CoreDataManager`에서 `.limitReached` 이중 차단 |
| 같은 이름 다시 만들기 | 새 UUID → 옛 기록(이미 "기타")은 돌아오지 않음. alert 문구와 일치 |
| 앱 구버전으로 되돌린 경우 | 구버전은 `"user:…"`를 기타로 읽음(금액·날짜 보존). 신버전으로 다시 올리면 원래 카테고리로 보임 |

---

## 6. 테스트 계획

모두 `CoreDataManager(inMemory: true)` + `setUp`의 `resetAllData()`. 순수 로직은 저장소 없이.

### 6-1. 신규 `UserCategoryTests.swift`
1. **규칙(순수)**: 빈/공백 이름, 11자 거부·10자 허용(한글·이모지 섞인 grapheme 기준), 내장 이름("식비")·
   기존 이름 대소문자/앞뒤 공백 차이 중복, 수정 시 자기 이름 허용, 20개에서 `.limitReached`.
2. **`firstEmoji`**: "ab"→nil, "1"→nil, "🐶🐱"→"🐶", "a🐶"→"🐶", "👨‍👩‍👧"→"👨‍👩‍👧", "☺️"→"☺️".
3. **`CategoryKey`**: 내장 7개 storageValue 왕복, `"user:<uuid>"` 왕복, `"user:xyz"`·nil·"모르는값" → `.other`.
4. **CRUD**: 추가 후 `fetchUserCategories` 순서·값, `updateUserCategory` 반영, 중복·21번째는 throw하고 저장 안 됨.
5. **이름 변경**: 사용자 카테고리로 기록 3건 저장 → 이름 변경 → `fetchSpendingRecords`의 `category.info.name`이
   새 이름, `myShareTotal` 동일, `CSV` 카테고리 열 새 이름, 통계 집계 한 줄.
6. **삭제**: 기록 N건 + 기간형 페이백 1개 연결 → `userCategoryUsage`가 (N,1) → `deleteUserCategory` 후 기록
   `category == .other`, 페이백 `linkedCategory == .other`, `linkedSpendingTotal` 합계 동일, 카테고리 행 없음.
7. **예산 불변**: 위 추가·수정·삭제 전후로 `fetchOrCreateTodayDailyBudget()`의 사용 가능 금액·이월과
   `budgetOutflow`가 같다(완료 기준 5).
8. **초기화**: `resetAllData()` 후 `fetchUserCategories()`가 빈 배열.
9. **카탈로그**: 주입한 `CategoryCatalog`에서 `all` 순서(내장 7 → createdAt), 모르는 ID `info`가 기타 💸.

### 6-2. 기존 테스트 수정·추가
- `CoreDataMigrationTests`: `test_GagaeSsi12에서_13으로_마이그레이션되고_기존_카테고리는_그대로다` —
  12 모델로 "식비" 기록·"교통" 연결 페이백을 쓰고 현재 모델로 연 뒤, 카테고리 그대로·`UserCategory` 0건.
- `SpendViewModelTests`, `SpendingEditDraftTests`, `SpendingSuggestionTests`, `PaybackLinkTests`,
  `CategorySpendingTests`, `DataExportTests`: 타입 변경(`SpendingCategory` → `CategoryKey`)에 맞춰
  `.food` → `.builtIn(.food)`로 고친다. 기대값은 바꾸지 않는다(동작 불변 확인).
  `PaybackLinkTests`에 사용자 카테고리 연결 1건, `DataExportTests`에 사용자 카테고리 이름 출력 1건 추가.
- 전체 테스트: `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'`.

### 6-3. 수동 확인 (디자인 10장)
- 팔레트 8색 흰 글자 대비 실측(라이트·다크), SE 폭에서 10자 칩·통계 행,
  "＋ 추가" → 새 칩 선택·스크롤·입력 금액 유지, VoiceOver 삭제 커스텀 액션, 라이트/다크 스크린샷.
- 재시작 후 사용자 카테고리 기록 유지(완료 기준 2).

---

## 7. 위험과 되돌리기

| 위험 | 영향 | 대응 |
|---|---|---|
| `SpendingCategory` → `CategoryKey` 타입 변경 범위가 넓다(약 20개 파일) | 표시 누락·컴파일 오류 | 타입을 바꿔 컴파일러가 모든 사용처를 잡게 한다. 기존 테스트 기대값을 그대로 두어 동작 불변을 확인 |
| `CategoryCatalog.shared` 전역 상태 | 테스트 간 상태 누수, reload 누락 시 옛 이름 표시 | 순수 로직은 주입 인스턴스로 테스트. reload는 CRUD·초기화 직후 한 곳(`CategoryCatalog` 래퍼 메서드)에서만 호출 |
| 모델 버전 13 추가 | 마이그레이션 실패 시 앱 실행 불가 | 엔티티 추가만(lightweight). 12→13 마이그레이션 테스트 필수 |
| 삭제 중 일부만 갱신 | 기록 일부가 사라진 ID를 가리킴 | save 1회 + 실패 시 rollback. 남더라도 `normalize`가 기타로 표시·집계 |
| 팔레트 대비 추정치 | 다크에서 칩 글자 가독성 | 실측 후 값 조정. 토큰 rawValue 저장이라 값만 바꾸면 됨 |

**되돌리기**: 기능을 빼야 하면 화면 진입(설정 행·추가 칩)만 숨겨도 기존 데이터는 그대로 표시된다.
코드를 완전히 되돌려도 구버전 해석 규칙상 사용자 카테고리 기록은 "기타"로 보이고 금액·날짜는 보존된다.
모델 13은 엔티티 추가뿐이라 남겨 둬도 무해하다.

---

## 8. 코드 대조 기록 (2026-10-29 재확인)

설계의 전제가 지금 코드와 맞는지 다시 확인했다. 구현 전에 이 표와 달라졌으면 설계를 먼저 고친다.

| 전제 | 확인 위치 | 결과 |
|---|---|---|
| 현재 모델 버전은 12 | `Resources/GagaeSsi.xcdatamodeld/.xccurrentversion` | `GagaeSsi 12.xcdatamodel` → 13 신설이 맞다 |
| 기록 카테고리 쓰기 지점 2곳 | `CoreDataManager.swift:565`, `:642` (`model.category.rawValue`) | `storageValue`로 교체 대상 |
| 페이백 연결 쓰기 지점 1곳 | `CoreDataManager.swift:428` (`m.linkedCategory?.rawValue`) | `storageValue`로 교체 대상 |
| 연결 소비 필터 | `CoreDataManager.swift:434` `linkedSpending(for:)`, `:451` `linkedSpendingTotal(for:)` | `normalize` 비교로 교체. 합계는 앞 함수 결과를 쓰므로 한 곳만 고치면 된다 |
| 초기화 대상 목록 | `CoreDataManager.swift:915` `entityNames` | `"UserCategory"` 추가 |
| 저장 실패 시 rollback 없음 | `CoreDataManager.swift:44` `saveContext()` (로그 후 `false`만 반환) | 3-5의 "새 메서드만 rollback" 결정 유지. 기존 호출부 동작은 건드리지 않는다 |
| 일괄 갱신 선례 | `CoreDataManager.swift:744` `renameSpendingTitles` | 삭제 시 기타 이동을 같은 fetch+대입 방식으로 작성 |
| `SpendingCategory` 사용처 | 앱 13개 파일 + 테스트 4개 파일 | 7장 "약 20개 파일" 추정 범위 안 |
| 마이그레이션 테스트 틀 | `CoreDataMigrationTests.swift:33` `model(named:)`, `:56` `container(with:)`, `:219` 최초→현재 일괄 테스트 | 12→13 테스트는 `:328`(11→12)과 같은 모양으로 추가. `:219`는 13을 자동으로 거치므로 함께 통과해야 한다 |

---

## 9. 구현 순서 (Epsilon 참고)

1. 모델 13 + `UserCategory` 엔티티, 마이그레이션 테스트
2. `UserCategoryModels.swift`(키·규칙·이모지) + `UserCategoryColor` + 순수 테스트
3. `CoreDataManager` CRUD·삭제·초기화 + `CategoryCatalog` + 저장소 테스트
4. `SpendingCategory` → `CategoryKey` 타입 교체(컴파일 오류 따라 전 지점), 기존 테스트 수정·통과
5. `CategoryChip` 공용화 후 Spend·HistoryEdit·Payback 교체
6. `CategoryManageView`·`CategoryEditSheet`·설정 진입 행·초기화 문구
7. 통계 긴 글 대응, 수동 확인 목록
