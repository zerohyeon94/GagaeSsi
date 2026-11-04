# 가계씨 현황 정리 (2026-11-05)

- **작성일**: 2026-11-05
- **기준 커밋**: `8796a61` (`develop`, PR #45 머지 직후)
- **저장소**: https://github.com/zerohyeon94/GagaeSsi
- **목적**: 기능 개발이 끝나고 출시 준비 단계에 들어선 시점의 스냅샷. 무엇이 만들어져 있고, 무엇이 남았는지 한눈에 보기 위한 문서.

---

## 1. 한 줄 요약

> **"오늘 얼마 쓸 수 있어?"** — 월급·고정비·급여일만 넣으면 하루에 쓸 수 있는 금액을 알려주는 iOS 가계부.

기능 개발(개발 마일스톤 v1.0~v1.7)은 **끝났다**. 지금은 **스토어 첫 제출(1.0) 준비** 단계이며, 남은 일은 코드보다 **실기기 검증·문의 이메일·법무 문서·App Store Connect 등록**이다.

| 항목 | 현재 값 |
|---|---|
| 플랫폼 | iOS 18.0+ (SwiftUI, iPhone·iPad 스크린샷 준비) |
| 데이터 | CoreData, 모델 버전 **`GagaeSsi 13`** (lightweight migration) |
| 앱 버전 | `1.0 (1)` — 스토어 첫 제출 버전 |
| 번들 ID | `com.yhjo.GagaeSsi` |
| 소스 | Swift 파일 76개 (`GagaeSsi/`), `CoreDataManager.swift` 약 2,500줄 |
| 테스트 | 테스트 파일 40개, 테스트 메서드 약 488개 |
| 서버·네트워크 | 없음. 모든 데이터는 기기 안에만 저장 (수집·추적 없음) |

---

## 2. 제품 개념

### 핵심 계산

```
기본 하루 예산 = (월급 − 고정비 합계) ÷ 급여 기간 일수   (원 단위 내림)
급여 기간     = 이번 급여일 ~ 다음 달 급여일
```

- **이월**: 전날 남은 돈 전액이 다음 날로 넘어간다. **음수도 넘어간다** — 많이 쓴 날은 다음 날 예산이 줄어드는 것이 제품 의도.
- **앱을 안 켠 날**도 홈 진입 시 `processDailyBudgets(upTo:)`가 소급해서 채우고 이월을 잇는다.
- **급여일 보정**: 주말이면 직전 금요일, 29~31일은 말일로 클램프.
- 계산 규칙의 기준 문서는 `docs/2026-07-08-daily-budget-calculation-rules.md`. 구현과 문서가 어긋나면 문서를 따른다.

### 캐릭터 (돼지 "가계씨")

오늘 소비 비율에 따라 표정이 바뀐다 (`Models/CharacterState.swift`).

| 상태 | 라벨 | 조건 |
|---|---|---|
| `stable` | 여유 | 하루 예산의 70% 미만 |
| `caution` | 조심 | 70% 이상 100% 미만 |
| `over` | 걱정 | 100% 이상 |
| `covered` | 회복 | 초과했지만 모아둔 이월금으로 채움 |
| `repaying` | 회복 중 | 초과분을 나눠 갚는 중 |

현재는 이모지 기반이며, Rive 캐릭터로의 전환은 출시 이후 과제(#44)다.

---

## 3. 기능 목록

### 화면 구성

- **온보딩** (`Features/Setup`): 월급·급여일 → 고정비 입력.
- **메인 탭** (`App/ContentView.swift`): 홈 · 기록 · 내역 · 통계 · 설정 (5탭).

### 개발 마일스톤별 기능 (GitHub Releases, 모두 pre-release)

| 태그 | 주요 내용 |
|---|---|
| v1.0 | SwiftUI 전환, 돼지 테마 |
| v1.1 | 이월 자동화, 지출 수정, 통계 |
| v1.2 | 위시리스트 저금, 변동 고정비, 급여일(주말·말일) 보정 |
| v1.3 | 고정비 재구성(지출/저축/투자), 이월 방식 선택, 항목 자동완성 |
| v1.4 | 할부, 페이백/환급 |
| v1.5 | 소비 내역 탭, 이월금 충당, 캐릭터 피드백 |
| v1.6 | 초과 상환 계획, 저축·투자 이동 관리, 다크 테마, P2 백로그 소진 |
| v1.6.1 | 부채 수명주기, 위시 지갑 |
| v1.7 | 여행 정산 (인원·결제자·지갑·정산/재개) |

### v1.7 이후 추가된 것 (2026-10~11, 태그 없음)

- **사용자 카테고리** (#35): 카테고리 직접 추가·수정·삭제, 삭제 시 '기타'로 이동, 공용 `CategoryChip`. CoreData 모델 13에 `UserCategory` 엔티티.
- **여행 선택 경계 정리** (#30·#31·#32): 기간이 끝난 여행은 소비 입력 목록에서 제외, '여행 아님'으로 되돌리면 인원·결제자 원복, 기간·기본 인원은 여행 화면에서만 관리.
- **테스트 안정화** (#33·#34): 과거 초과 전환 테스트의 날짜 의존성 제거.
- **조합 시나리오 테스트** (#27 일부): 지갑·여행·미실행·급여일이 겹친 이월 체인 테스트.
- **출시 준비** (#25·#28·#29): 미사용 Pretendard 폰트 13MB 제거(SF Pro Rounded 확정), 개인정보 매니페스트·암호화 면제 키 추가, 버전 1.0 통일.

### 설정 화면에서 접근하는 기능

예산 방식 · 고정비 · 이월 방식 · 위시리스트 · 할부 · 페이백 · 여행 · 저축/투자 이동 · 부채 상환 계획 · 초과 내역 · 소비 리마인더 알림 · 테마(기기/밝게/어둡게) · 카테고리 관리 · 항목명 정리 · CSV 내보내기 · 데이터 초기화 · 피드백 메일 · 버전 표시.

---

## 4. 아키텍처 요약

| 영역 | 방식 |
|---|---|
| UI / 상태 | SwiftUI + `@Observable` MVVM. `Features/<기능>/`마다 View + ViewModel |
| 전역 이벤트 | `AppEventBus` — `UUID` 트리거 갱신 → `.onChange`로 감지 (RxSwift 대체, 패키지는 레거시로만 남음) |
| 앱 상태 | `AppState` — 셋업 완료 여부(`BudgetConfig` 존재)·선택 탭 |
| 데이터 | `CoreDataManager` 싱글톤이 CRUD 전담. 엔티티는 `Models/`의 값 타입으로 변환해 노출 |
| 설정 저장 | 전부 `BudgetConfig`에. UserDefaults 사용처 없음 |
| 디자인 | `Common/DesignSystem.swift` 토큰, `Color.adaptive(light:dark:)`로 라이트/다크 대응, SF Pro Rounded |
| 알림 | 로컬 알림만. id prefix `vcost-`(변동 고정비) / `spend-`(소비 리마인더) / `payback-`(페이백) |

### 지켜온 도메인 규칙

- **이동·약정 금액은 소비 기록을 만들지 않는다** — 위시 저금·고정비·할부·환급·부채 상환·저축/투자 이동은 예산에서만 차감 (통계·초과 판정 이중 계산 방지).
- **소비 합산의 두 렌즈** — 기록·통계는 `myShareTotal`(내 몫), 예산 장부는 `budgetOutflow`(지갑 제외 + 내가 낸 돈). 한 화면에서 섞지 않는다.
- **이월 재계산은 데이터 계층 책임** — 소비 생성·수정·삭제가 직접 `recalculateCarryOverChain`을 부른다.
- **자동 차감·자동 사용은 하지 않는다** — 이월금 사용·부채 상환·급여일 흡수는 사용자에게 묻는다.
- **CoreData 모델은 배포된 버전을 고치지 않고 새 버전을 만든다.**

---

## 5. 문서 위치

| 종류 | 위치 |
|---|---|
| 프로젝트 가이드 | `CLAUDE.md` |
| 계산 규칙 (기준 문서) | `docs/2026-07-08-daily-budget-calculation-rules.md` |
| 기능 설계 (v1.1~v1.7) | `docs/superpowers/specs/` |
| 이슈별 기획·디자인·설계 | `docs/기획/`, `docs/디자인/`, `docs/설계/` (파일명 앞 숫자 = 이슈 번호) |
| 브랜드 스타일 가이드 | `docs/디자인/6-brand-style-guide.md` |
| 스토어 제출 준비 | `docs/기획/28-app-store-submission.md` |
| 버전 규칙 | `docs/기획/29-store-version-rules.md` |
| 실기기 검증 절차 | `docs/기획/27-device-verification-guide.md` |
| 디자인·애니메이션 파이프라인 | `docs/디자인/44-design-animation-pipeline.md` |
| WBS 운영 규칙 | `docs/2026-09-08-github-wbs-operations.md` |

노션에는 요약과 GitHub 링크만 올린다 (원본은 리포).

---

## 6. 남은 일

### 마일스톤 `v1.8 출시 준비` — 6건 완료 / 3건 남음

| 이슈 | 내용 | 상태 |
|---|---|---|
| #26 | 문의 이메일 분리 — `FeedbackMail.supportEmail`이 개인 Gmail이고 앱 바이너리에 포함돼 공개된다 | **열림 · high** |
| #27 | 실기기 실데이터 검증 — 며칠 미실행, 급여일 통과, 마이그레이션(→ 모델 13), 알림, 다크/다이나믹 타입 | **열림 · high** (조합 테스트는 완료) |
| #28 | App Store 제출 — 코드 쪽 준비 완료, 법무 문서 공개 URL·App Store Connect 등록 남음 | **열림** |
| #6, #25, #29 등 | 스타일 가이드 현행화, 폰트 제거, 버전 규칙 | 완료 |

**출시까지의 순서**

1. **#26** 문의용 이메일 결정 → `FeedbackMail.supportEmail`·App Store Connect 지원 이메일·개인정보처리방침 문의처를 같은 주소로.
2. **법무 문서** — 노션 개인정보처리방침·이용약관의 빈칸(개발자명·문의 이메일) 채우기 → 공개 URL.
3. **#27** 실기기에서 시간 경과가 필요한 시나리오 확인.
4. **#28** App Store Connect 입력(초안은 `28-app-store-submission.md`) → 빌드 업로드 → 제출 커밋에 `store/1.0` 태그.

### 출시 이후

| 이슈 | 내용 |
|---|---|
| #44 | 디자인·애니메이션 공통 파이프라인 — Claude 디자인 → Figma(원본) → Rive(돼지 상태 반응) / Lottie(일회성 연출). Android 앱까지 같은 파일 공유 |
| #5 | 가계씨 캐릭터 확장 (감정 + 기능별 버전) — 출시 후 사용자 반응 보고 판단 (보류) |
| — | Android 앱 (위 파이프라인 전제) |

### 알려진 기술 부채

- `CoreDataManager.swift`가 약 2,500줄로 비대하다 (섹션별 분리 후보).
- 일부 ViewModel에 테스트가 없다.
- 설정 화면 아이콘 배경색 등 일부 hex 하드코딩이 남아 있다 (토큰 원칙과 어긋남).
- GitHub Projects(WBS 보드)는 `gh` 토큰에 project 스코프가 없어 아직 만들지 않았다 (`scripts/setup-github-wbs.sh` 준비됨).

---

## 7. 빌드 · 테스트

```bash
# 빌드
xcodebuild -project GagaeSsi.xcodeproj -scheme GagaeSsi \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' build

# 전체 테스트
xcodebuild test -project GagaeSsi.xcodeproj -scheme GagaeSsiTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'
```

- 테스트는 `CoreDataManager(inMemory: true)` 인메모리 스토어 사용. 마이그레이션은 `CoreDataMigrationTests`가 임시 SQLite로 따로 검증한다.
- 시뮬레이터 "Busy"로 실패하면 코드 문제가 아니다 → `xcrun simctl shutdown all` 후 재시도.
