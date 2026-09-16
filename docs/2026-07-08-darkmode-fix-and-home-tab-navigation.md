# 다크모드 입력 필드 버그 수정 & 홈 소비 기록 탭 전환 개선

- **작성일**: 2026-07-08
- **상태**: 구현 완료
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)

---

## 1. 배경

### 1-1. 버그: 다크모드에서 월급 입력 텍스트가 보이지 않음

설정 → 월급 & 급여일(`EditBudgetView`)에서 월급을 입력하면 다크모드에서 텍스트가 흰색으로 렌더링되어 보이지 않는다.

**원인 분석**
- 가계씨 디자인 시스템(`DesignSystem.swift`)은 **라이트 테마 고정**으로 설계됨 — 배경(`#FFF5F7`), 카드 배경(`#FFFFFF`) 등 모든 색상이 라이트 기준 하드코딩.
- 반면 앱이 시스템 다크모드 설정을 그대로 따라가면서, 명시적 색상이 없는 `TextField` 글자색만 시스템 기본값(다크모드 = 흰색)으로 바뀜.
- 결과: **흰 카드 배경 위 흰 글자** → 보이지 않음.
- 동일 패턴의 `TextField`가 8곳 존재 (`EditBudgetView`, `SpendView`, `SetupSalaryView`, `SetupFixedCostView`, `FixedExpenseEditView`, `GagaeAmountField`, `GagaeTextField`) — 전부 같은 잠재 버그.

### 1-2. UX 개선: 홈 → 소비 기록하기 진입 방식

홈 하단의 "소비 기록하기" 버튼이 `NavigationLink`로 `SpendView`를 **푸시**해서 이동한다.
- 이미 하단 탭에 "기록" 탭으로 동일한 `SpendView`가 존재 → 같은 화면이 두 경로(푸시/탭)로 열려 이중 진입 구조.
- 푸시로 열면 뒤로가기를 해야 하고, 탭바의 "기록" 탭과 선택 상태가 어긋남.

---

## 2. 해결 방안

### 2-1. 다크모드 버그 → 앱 전체 라이트 모드 고정

디자인 시스템 자체가 라이트 테마 고정이므로, 개별 `TextField` 8곳에 색을 일일이 지정하는 대신 **루트에서 라이트 모드로 고정**한다.

```swift
// GagaeSsiApp.swift — RootView
.preferredColorScheme(.light)
```

- 입력 필드뿐 아니라 시트, 알럿, 피커 등 시스템 색을 쓰는 모든 UI의 다크모드 색상 충돌을 한 번에 방지.
- 추후 다크 테마를 정식 지원할 경우: 디자인 토큰을 `Assets.xcassets` 컬러셋(라이트/다크 변형)으로 이관하고 이 한 줄을 제거하면 됨.

### 2-2. 소비 기록하기 → 탭 전환

전역 `AppState`에 탭 선택 상태를 추가하고, 홈 버튼이 "기록" 탭으로 전환하도록 변경.

```swift
// AppState
var selectedTab: Int = 0   // 0: 홈, 1: 기록, 2: 통계, 3: 설정

// ContentView — TabView(selection:)을 AppState와 바인딩
@Bindable var appState = appState
TabView(selection: $appState.selectedTab) { ... }

// HomeView — NavigationLink → Button으로 교체
Button { appState.selectedTab = 1 } label: { /* 기존 디자인 유지 */ }
```

- 버튼 디자인(그라디언트 캡슐)은 그대로 유지, 동작만 탭 전환으로 변경.
- 탭 선택 상태가 전역으로 이동해 추후 딥링크·위젯에서 특정 탭 진입도 가능해짐.

---

## 3. 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `GagaeSsi/App/GagaeSsiApp.swift` | `RootView`에 `.preferredColorScheme(.light)` 추가, `AppState`에 `selectedTab` 추가 |
| `GagaeSsi/App/ContentView.swift` | 로컬 `@State` 탭 상태 제거, `AppState.selectedTab` 바인딩으로 교체 |
| `GagaeSsi/Features/Home/HomeView.swift` | 소비 기록하기 버튼을 `NavigationLink` 푸시 → 기록 탭 전환 `Button`으로 교체 |

## 4. 검증

- [x] `xcodebuild` iOS Simulator 빌드 성공
- [ ] 다크모드 기기에서 설정 → 월급 입력 텍스트 정상 표시 확인 (수동)
- [ ] 홈 → 소비 기록하기 탭 전환 및 탭바 선택 상태 일치 확인 (수동)

## 5. 남은 백로그 (노션 기준 현행화)

노션 체크리스트 중 카테고리 입력(`SpendView`), 통계 화면(Swift Charts 기반 `StatsView`), CoreData `category` 속성, 홈 7일 차트 실데이터 연결은 **이미 구현 완료**된 상태. 남은 항목:

- [ ] 데이터 백업 (설정에 "준비 중")
- [ ] 피드백 보내기 (설정에 "준비 중")
- [ ] 자주 쓰는 항목 즐겨찾기 (향후 고려)
- [ ] 다크 테마 정식 지원 여부 결정 (현재는 라이트 고정)
