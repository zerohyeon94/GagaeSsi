# 소비 기록 리마인더 알림 설계

- **작성일**: 2026-08-07
- **상태**: 구현 완료 (2026-08-07)
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 코드**: `Core/NotificationService.swift`, `Core/CoreDataManager.swift`, `Models/BudgetModels.swift`, `Features/Settings/`

---

## 1. 배경·목적

가계씨는 사용자가 직접 소비를 기록해야 하루 예산과 이월이 정확해진다. 기록을 하루 빠뜨리면 다음 날 이월이 실제와 어긋나고, 며칠 쌓이면 앱을 신뢰할 수 없게 된다.

사용자가 정한 시각에 **"오늘 쓴 내역 아직 안 적으셨어요"** 알림을 보내 기록 습관을 유지시킨다. 이미 기록한 날에는 울리지 않아야 알림 피로도가 생기지 않는다.

## 2. 기술적 제약과 그에 따른 설계

**제약**: iOS 로컬 알림은 발송 시점에 앱 코드를 실행하지 않으므로, "오늘 소비 기록이 있는지"를 발송 시점에 판단할 수 없다. `UNCalendarNotificationTrigger(repeats: true)`는 식별자가 하나뿐이라 **특정 날짜분만 취소할 수 없다.**

**설계**: 향후 **14일치를 `repeats: false`로 개별 예약**하고(`spend-YYYYMMDD` 식별자), 오늘 소비 기록이 생기면 **오늘분만 제거**한다. 앱이 열릴 때마다 rolling으로 다시 채운다.

- 14일: 사용자가 2주 이상 앱을 안 열면 알림이 끊기지만, 그 시점이면 리마인더 자체가 의미를 잃은 상태이므로 허용한다. 기존 변동 고정비 알림(`vcost-`)과 동일하게 `UNCalendarNotificationTrigger` + `repeats: false` 패턴을 따른다.

## 3. 확정된 설계 결정

| 결정 | 선택 |
|---|---|
| 알림 조건 | **그날 소비 기록이 1건이라도 있으면 당일 알림 취소** (사실상 "안 적은 날에만 알림") |
| 예약 방식 | 향후 14일치 개별 예약 (`repeats: false`), 앱 활성화 시 rolling 갱신 |
| 기본값 | OFF, 시각 21:00 |
| 저장 위치 | `BudgetConfig` (앱 전체가 CoreData 단일 설정을 쓰는 기존 패턴 유지 — UserDefaults 미사용) |
| 권한 | 토글 ON 시 요청. 이미 거부 상태면 시스템 설정 안내 |

## 4. 데이터 모델 (CoreData `GagaeSsi 3`, lightweight migration)

`BudgetConfig` 필드 추가:

| 속성 | 타입 | 기본값 |
|---|---|---|
| `spendReminderEnabled` | Bool | `false` |
| `spendReminderHour` | Int16 | `21` |
| `spendReminderMinute` | Int16 | `0` |

`BudgetConfigModel`에 대응 프로퍼티 추가 (`init(entity:)` 변환 포함).

> 주의: CoreData의 Bool 기본값은 `false`, Int16 기본값은 `0`이다. 기존 사용자 마이그레이션 시 `spendReminderHour`가 `0`(자정)이 되므로, **모델 변환 시 `enabled == false`이면 시각을 21:00으로 보정**해 UI 초기값이 자정으로 보이지 않게 한다.

## 5. 알림 서비스 (`NotificationService` 확장)

기존 변동 고정비 알림(`vcost-` prefix)과 **완전히 분리**된 `spend-` prefix를 사용한다.

```swift
/// 기존 spend- 알림 전부 제거 후 fireDates를 개별 예약한다.
/// 제거와 재예약은 같은 콜백 안에서 처리한다
/// (따로 호출하면 제거 콜백이 늦게 도착해 방금 추가한 알림까지 지운다).
func refreshSpendReminders(fireDates: [Date])

/// 모든 소비 리마인더 제거 (기능 OFF·데이터 초기화)
func cancelAllSpendReminders()
```

> **예약 대상 날짜는 호출 스레드에서 미리 계산해 넘긴다.** `getPendingNotificationRequests`
> 콜백은 임의 큐에서 실행되므로, 그 안에서 CoreData(`viewContext`)를 조회하면 스레드 규칙을
> 위반한다. 그래서 `hasRecord` 클로저를 서비스에 넘기지 않고 `[Date]`만 받는다.

- 식별자: `spend-YYYYMMDD`
- 이미 지난 시각은 예약하지 않는다 (기존 `schedule`과 동일한 가드)
- **오늘**은 `hasRecord(오늘) == true`면 건너뛴다. 미래 날짜는 기록이 있을 수 없으므로 항상 예약한다.
- 문구
  - title: `가계씨 🐷`
  - body: `오늘 쓴 내역, 아직 안 적으셨네요. 까먹기 전에 기록해요!`

`CoreDataManager`에 래퍼 추가:
```swift
/// BudgetConfig에서 설정을 읽고 SpendReminderSchedule.pendingDates로 날짜를 계산해 넘긴다.
/// hasRecord는 fetchSpendingRecords(date:)로 판정한다.
func refreshSpendReminders(now: Date = Date())

/// 설정(토글·시각) 저장 후 즉시 재예약
@discardableResult
func updateSpendReminder(enabled: Bool, hour: Int, minute: Int) -> Bool
```

## 6. 갱신 시점

| 시점 | 이유 |
|---|---|
| 앱 활성화 (`scenePhase == .active`) | rolling 재예약. 기존 `refreshVariableCostReminders` 호출 지점과 동일 |
| 소비 저장 / 삭제 후 (`AppEventBus.spendingAddedTrigger`) | 오늘분 취소 또는 복구 |
| 설정 변경 (토글·시각) | 즉시 반영 |
| 데이터 초기화 | `cancelAllSpendReminders()` |

## 7. UI — 설정 "알림" 섹션

`SettingSection`에 `.notification` 케이스 추가 (`고정비 관리`와 `데이터 관리` 사이).

```
알림
  소비 기록 리마인더                    [ON/OFF]
  알림 시각                             오후 9:00  ▸
  └ 그날 소비를 기록하면 알림이 오지 않아요
```

- 토글 ON → `requestAuthorization` 호출
  - 거부 상태(`.denied`)면 알림: "시스템 설정 > 가계씨 > 알림에서 허용해주세요" + 설정 앱 이동 버튼
  - 권한 미획득 시 토글은 OFF로 되돌린다
- 시각 선택: `DatePicker(displayedComponents: .hourAndMinute)` (토글 ON일 때만 노출)

## 8. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 설정 시각이 이미 지난 오늘 | 오늘분 미예약, 내일부터 |
| 기록 후 그 소비를 삭제 | `AppEventBus` 트리거로 재예약 → 오늘분 복구 (시각이 아직 안 지났다면) |
| 권한 거부 | 토글 OFF 유지 + 시스템 설정 안내 |
| 14일 이상 앱 미실행 | 알림 소진. 다음 실행 시 재충전 |
| 데이터 초기화 | 모든 `spend-` 알림 제거 |
| 기존 사용자 마이그레이션 | `enabled = false`, 시각은 모델 변환에서 21:00으로 보정 |

## 9. 테스트 (`SpendReminderTests` 11건)

로컬 알림 예약 자체는 시뮬레이터 의존성이 커서, **예약 대상 날짜를 고르는 순수 로직**을 분리해 테스트한다.

```swift
enum SpendReminderSchedule {
    /// now 기준 향후 days일 중 실제로 예약할 발송 시각 목록
    static func pendingDates(from now: Date, hour: Int, minute: Int,
                             days: Int, hasRecord: (Date) -> Bool,
                             calendar: Calendar) -> [Date]

    /// 알림 식별자 (spend-YYYYMMDD)
    static func identifier(for fireDate: Date, calendar: Calendar) -> String
}
```

1. 오늘 시각이 아직 안 지났고 기록 없음 → 오늘 포함
2. 오늘 시각이 이미 지남 → 오늘 제외
3. 오늘 기록 있음 → 오늘 제외
4. 미래 날짜 필터링도 동작
5. `days = 14` → 14개 이하 반환
6. 정확히 발송 시각과 같으면 제외 (`fireDate > now`)
7. 잘못된 시각·일수(24시, −1, 60분, 0일) → 빈 배열
8. 식별자 형식 `spend-20260807`
9. 식별자는 날짜마다 고유
10. 기본값 저장 확인 (꺼짐 / 21:00)
11. 설정 변경 저장 확인 (`updateSpendReminder`)

## 10. 범위 제외 (v-next)

- 요일별 알림 on/off
- 알림에서 바로 기록(Notification Action / App Intent)
- 여러 시각 알림 (아침·저녁 2회)
- 급여일·예산 초과 알림 등 다른 종류의 알림
