# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

**가계씨(GagaeSsi)** — "오늘 얼마 쓸 수 있어?" 월급·고정비·급여일 기준으로 하루 사용 가능 금액을 계산해주는 iOS 가계부 앱. SwiftUI + CoreData, iOS 18+, 코드 주석과 문서는 한국어로 작성한다.

브랜치: `develop`에서 작업하고 PR은 `main`으로 보낸다.

## 빌드 & 테스트 명령어

```bash
# 빌드
xcodebuild -project GagaeSsi.xcodeproj -scheme GagaeSsi \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' build

# 전체 테스트
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'

# 단일 테스트 클래스 / 메서드
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -only-testing:GagaeSsiTests/CoreDataManagerTests/testBudgetConfig_CRUD
```

- 배포 타겟이 iOS 18.0이므로 iOS 18 이상 시뮬레이터가 필요하다.
- **destination 주의** (2026-09-09): `name=iPhone 16`은 이제 쓰지 않는다. 그 시뮬레이터는 iOS 18.0 런타임에 있는데 현재 Xcode는 iOS 26.x 런타임만 eligible로 보아 `Unable to find a device matching the provided destination specifier`로 실패한다. 위처럼 `name=iPhone 17,OS=26.0`을 쓴다. 사용 가능한 목록은 `xcodebuild -showdestinations -project GagaeSsi.xcodeproj -scheme GagaeSsiTests`로 확인.
- 테스트는 `CoreDataManager(inMemory: true)`로 인메모리 스토어를 사용하며, `setUp`에서 `resetAllData()`로 초기화한다.

## 아키텍처

### 화면 흐름 (GagaeSsi/App/GagaeSsiApp.swift)

`RootView`가 `AppState.isSetupCompleted`(= CoreData에 `BudgetConfig` 존재 여부)로 분기한다:
- 설정 없음 → `Features/Setup/` 온보딩 (월급 → 고정비 입력)
- 설정 있음 → `ContentView` 메인 탭 (0: 홈, 1: 기록/Spend, 2: 통계/Stats, 3: 설정/Settings)

### 상태 관리 패턴

- **`@Observable` (Observation 프레임워크) 기반 MVVM.** Combine/RxSwift를 쓰지 않는다. `Features/<기능>/` 폴더마다 View + ViewModel 쌍으로 구성.
- **`AppEventBus`** (Common/): 전역 이벤트 버스. `UUID` 프로퍼티를 갱신하는 방식으로 트리거를 전파한다 (`notifySpendingAdded()` 등). View에서는 `.onChange(of: eventBus.xxxTrigger)`로 감지. RxSwift `PublishSubject`를 대체한 패턴이며, 프로젝트에 남아있는 RxSwift 패키지 의존성은 레거시로 실제 import되는 곳은 없다.
- **`AppState`** (GagaeSsiApp.swift): 셋업 완료 여부와 선택된 탭 인덱스를 관리. `eventBus`, `appState` 모두 `.environment()`로 주입.

### 데이터 계층

- **`CoreDataManager`** (Core/): 싱글톤(`shared`) + CRUD 전담. lightweight migration 활성화. 테스트용 `init(inMemory:)` 제공.
- **Entity ↔ 구조체 모델 변환 패턴**: CoreData 엔티티(`BudgetConfig`, `FixedCost`, `DailyBudget` 등)를 View/ViewModel에 직접 노출하지 않고, `Models/`의 값 타입(`BudgetConfigModel`, `FixedCostModel`, `DailyBudgetModel`)으로 변환해 사용한다. 각 모델은 `init(entity:)` 변환 생성자를 가진다.

### 예산 계산 (핵심 도메인 로직)

- **`DailyBudgetCalculator`** (Core/Utils/BudgetCalculationUtils.swift): 급여 기간(이번 급여일 ~ 다음 달 급여일)과 기본 일일 예산 `(월급 − 고정비 합계) ÷ 급여 기간 일수` (원 단위 내림)를 계산.
- **이월(carryover)**: 전날 잔액 전액이 다음날로 이월되며 음수 이월도 허용(과소비 페널티가 제품 의도). 앱 미실행일의 이월은 홈 진입 시 `CoreDataManager.processDailyBudgets(upTo:)`가 소급 처리한다.
- 계산 규칙의 기준 문서는 `docs/2026-07-08-daily-budget-calculation-rules.md`이며, **구현과 문서가 어긋나면 문서를 기준으로 구현을 수정한다.**
- **소비 합산의 두 렌즈** (`SpendingRecordModel`의 `Sequence` 확장, `Models/BudgetModels.swift`): 소비 기록·통계 화면은 `myShareTotal`(내 몫 합), 예산 장부 화면은 `budgetOutflow`(지갑 제외 + 내가 낸 돈만)를 쓴다. 한 화면에서 두 렌즈를 섞지 않는다.

### 디자인 시스템

- `Common/DesignSystem.swift`에 색상 팔레트(`gagaePink` 등 돼지 테마), 타이포그래피, 공용 컴포넌트가 정의되어 있다. 하드코딩 대신 이 토큰을 사용한다.
- **라이트/다크 모두 지원** (2026-08-08): 색상 토큰은 `Color.adaptive(light:dark:)`로 정의되어 `UIColor` 동적 제공자를 통해 시스템 트레잇을 따라간다. 새 색을 추가할 땐 반드시 이 헬퍼를 쓰고, 뷰에 hex를 직접 박지 않는다.
  - 테마는 `BudgetConfig.themeMode`(기기 설정/밝게/어둡게)로 사용자가 고르며 `RootView`의 `.preferredColorScheme`에 반영된다.
  - 예전에 라이트로 고정했던 이유(다크에서 TextField 글자가 안 보임)는 배경 토큰이 다크 값을 갖게 되면서 해소됐다.

## 문서 운영

- 설계/기획 문서 원본은 리포 `docs/`에 둔다 (`docs/superpowers/specs/`에 기능 설계 문서). 노션에는 요약과 GitHub 링크만 올린다.
- 문서 파일명은 `YYYY-MM-DD-<주제>.md` 형식.
