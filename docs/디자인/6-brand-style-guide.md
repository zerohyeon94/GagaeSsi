# 가계씨 브랜드 스타일 가이드 (#6)

작성일: 2026-11-02

기준 코드: `GagaeSsi/Common/DesignSystem.swift`. **이 문서와 코드가 어긋나면 코드가 현행이고, 이 문서를 고친다.**
새 화면을 만들 때는 아래 토큰만 쓴다.

## 1. 색상 — 라이트/다크 적응형

모든 색은 `Color.adaptive(light:dark:)`로 정의되어 `UIColor` 동적 제공자를 통해 시스템 트레잇을 따라간다.
Assets 컬러셋을 쓰지 않는 것은 팔레트를 `DesignSystem.swift` 한 곳에서 보고 고치기 위해서다.

### 주요 · 포인트 · 상태

| 토큰 | Light | Dark | 용도 |
|---|---|---|---|
| `gagaePink` | `#FFB0B0` | `#FFA9A9` | primaryLight |
| `gagaePinkDark` | `#F5706B` | `#FF8A85` | primary (버튼·강조) |
| `gagaePinkLight` | `#FFE1E6` | `#3B2A2F` | primaryPale |
| `gagaePoint` | `#FFD766` | `#FFDE80` | 포인트(노랑) |
| `gagaePointDark` | `#F5BF26` | `#FFCB45` | 포인트 진하게 |
| `gagaeGood` | `#59C78D` | `#63D89B` | 여유 |
| `gagaeWarning` | `#FFA633` | `#FFB558` | 주의 |
| `gagaeDanger` | `#F25959` | `#FF7A7A` | 위험 |

다크에서는 어두운 배경 위에서 묻히지 않도록 primary 계열을 한 단계 밝게 쓴다.

### 면 · 텍스트 · 구분선

| 토큰 | Light | Dark | 용도 |
|---|---|---|---|
| `gagaeBackground` | `#FFF5F7` | `#171315` | 화면 배경 |
| `gagaeCardBackground` | `#FFFFFF` | `#221C20` | 카드 |
| `gagaeSurface` | `#FAFAFA` | `#2B242A` | 보조 면 |
| `gagaeSurfaceAlt` | `#F5F5F5` | `#322A30` | 버튼·칩처럼 한 단계 눌린 면 |
| `gagaePinkPale` | `#FFF0F0` | `#35272B` | 강조 배너 |
| `gagaeText` | `#1A1A1A` | `#F4EFF1` | 본문 |
| `gagaeTextSecondary` | `#888888` | `#A99FA5` | 보조 |
| `gagaeTextTertiary` | `#BBBBBB` | `#6F656B` | 비활성·힌트 |
| `gagaeDivider` | `#EEEEEE` | `#382F35` | 구분선 |

### 그라디언트

| 토큰 | Light | Dark | 용도 |
|---|---|---|---|
| `gagaePinkGradientTop` → `Bottom` | `#FFF0F3` → `#F9F7FF` | `#1D171A` → `#17151D` | 화면 배경 (`GagaeBackground`) |
| `gagaeBudgetCardTop` → `Bottom` | `#F5706B` → `#E84060` | `#E0605C` → `#C93A54` | 홈 예산 카드. 흰 글씨가 올라가므로 다크에서도 진하게 |

테마는 `BudgetConfig.themeMode`(기기 설정 / 밝게 / 어둡게)로 사용자가 고르고 `RootView`의 `.preferredColorScheme`에 반영된다.

## 2. 타이포그래피 — SF Pro Rounded

**브랜드 폰트는 SF Pro Rounded(`Font.system(design: .rounded)`)로 확정한다 (#25).**

- 번들에 있던 Pretendard 9종(13MB)은 등록(`UIAppFonts`)도 사용처도 없어 제거했다.
- 금액 표시가 rounded 숫자의 모양에 기대고 있어, 본문만 다른 폰트로 바꾸면 한 화면에 두 서체가 섞인다.
- 시스템 폰트라 Dynamic Type·굵기 축을 그대로 쓰고 앱 용량이 늘지 않는다.

| 분류 | 토큰 | 크기 / 굵기 |
|---|---|---|
| 타이틀 | `gagaeLargeTitle` | 34 / bold |
| | `gagaeTitle` | 28 / bold |
| | `gagaeTitle2` | 22 / bold |
| | `gagaeTitle3` | 20 / semibold |
| 본문 | `gagaeHeadline` | 17 / semibold |
| | `gagaeBody` · `gagaeBodyMedium` | 17 / regular · medium |
| 보조 | `gagaeCallout` · `gagaeCalloutMedium` | 16 / regular · medium |
| | `gagaeSubheadline` | 15 / regular |
| | `gagaeFootnote` | 13 / regular |
| | `gagaeCaption` · `gagaeCaptionMedium` | 12 / regular · medium |
| 금액 | `gagaeAmountLarge` | 40 / bold |
| | `gagaeAmountMedium` | 24 / bold |
| | `gagaeAmountSmall` | 18 / semibold |

다른 폰트를 다시 들이려면 이 문서를 먼저 고치고, `Info.plist`의 `UIAppFonts` 등록과 쓰는 굵기만 번들에 넣는 것을 함께 한다.

## 3. 간격 · 반경 · 그림자

- `GagaeSpacing` — xs 4 / sm 8 / md 16 / lg 24 / xl 32 / xxl 48
- `GagaeRadius` — sm 8 / md 12 / lg 16 / xl 20 / xxl 28 / full 100
- `gagaeShadow()` — 기본 `black 8%`, radius 12, y 4
- `gagaeCardShadow()` — `gagaePinkDark 15%`, radius 8, y 6

## 4. 공용 컴포넌트

`GagaeCard` · `GagaePrimaryButton` · `GagaeSecondaryButton` · `GagaeDivider` · `GagaeSectionHeader` ·
`GagaeAmountField` · `GagaeTextField` · `GagaeEmptyStateView` · `GagaeBackground`

## 5. 예산 상태와 캐릭터

예산 상태 색은 직접 고르지 않고 `BudgetStatus.from(available:base:)`를 거친다.

| 상태 | 남은 비율 | 색 | 표정(임시) | 문구 |
|---|---|---|---|---|
| `good` | 50% 이상 | `gagaeGood` | 🐷 | 오늘도 가게씨가 지켜볼게요! |
| `warning` | 20~50% | `gagaeWarning` | 😰 | 슬슬 줄여볼까요? |
| `critical` | 0~20% | `gagaeDanger` | 😱 | 조심해요, 거의 다 썼어요! |
| `empty` | 0 이하 | `gagaeDanger` | 😵 | 오늘은 여기까지예요... |

표정은 지금 이모지(`pigMood`)다. 캐릭터 표정 세트(#5)가 나오면 이 네 상태에 하나씩 대응시킨다.

## 6. 규칙

- **하드코딩 금지.** 뷰에 hex를 직접 박지 않고 위 토큰을 쓴다.
- **새 색을 추가할 땐 반드시 `Color.adaptive(light:dark:)`를 쓴다.** 라이트 값만 넣으면 다크에서 글자가 안 보인다.
- 새 토큰은 `DesignSystem.swift`의 `Color` 확장과 `ShapeStyle` 확장 양쪽에 추가하고, 이 문서의 표에도 넣는다.

## 알려진 예외

- 뷰에 `Color(hex:)`가 22곳 남아 있다 (설정 화면 아이콘 배경 등). 대부분 카테고리·아이콘 고유색이라 다크에서도 읽히지만,
  새로 손대는 화면에서는 토큰으로 옮긴다. `grep -rn 'Color(hex:' --include="*.swift" GagaeSsi | grep -v DesignSystem.swift`로 확인.
- 마케팅·스토어 스크린샷이 이 팔레트를 따르는지는 스토어 제출(#28) 때 함께 확인한다.
