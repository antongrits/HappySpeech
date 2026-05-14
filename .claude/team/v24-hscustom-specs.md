# v24 HSCustom* — Design Specs (11 компонентов)

> **Контекст:** Plan v23 Block 3.1 заявил «11 HSCustom* created+applied», но фактически как полноценный HSCustom* был задокументирован только `HSCustomAlert`. Перепроверка `HappySpeech/DesignSystem/Components/` показала, что **все 11 целевых компонентов уже реализованы как HS*-набор** (без приставки `Custom`) в рамках Block O v16. Этот документ фиксирует public API, токены, integration points и snapshot-coverage требования для v24-аудита.
>
> **Статус каждого компонента:** реализован / интегрирован в Features / нужен snapshot-test и DoD verification в v24.
>
> **Платформа:** iOS 17+ baseline, iOS 18 enhanced (MeshGradient, matchedTransitionSource), iOS 26 fallback paths.
>
> **Контуры:** все компоненты читают `@Environment(\.circuitContext)` и выбирают цветовую палитру (`kid` / `parent` / `specialist`), где это применимо.
>
> **Accessibility-инварианты для всех 11:**
> - `@Environment(\.accessibilityReduceMotion)` уважается — spring/scrollTransition заменяется на статику или opacity.
> - Все интерактивные элементы имеют `accessibilityLabel` через `LocalizedStringKey`.
> - Min touch target в kid-контуре ≥ 56pt (родительский / специалистский — 44pt HIG минимум).
> - VoiceOver-traits: `.isButton` + `.isSelected` на выбранных табах и сегментах.

---

## 1. HSAnimatedTabBar

**File:** `HappySpeech/DesignSystem/Components/HSAnimatedTabBar.swift`
**Статус:** реализован (240 LOC).
**Public API:**

```swift
@available(iOS 17.0, *)
public struct HSAnimatedTabBar<Item: Hashable>: View {
    @Binding public var selection: Item
    public let items: [Item]
    public let labelProvider: (Item) -> (icon: String, title: LocalizedStringKey)
    public var badgeProvider: ((Item) -> Int?)?

    public init(
        selection: Binding<Item>,
        items: [Item],
        badgeProvider: ((Item) -> Int?)? = nil,
        labelProvider: @escaping (Item) -> (icon: String, title: LocalizedStringKey)
    )
}
```

**Tokens:**
- `ColorTokens.Brand.primary` / `Parent.accent` / `Spec.accent` — индикатор (по `circuitContext`).
- `ColorTokens.Kid.inkMuted` / `Parent.inkMuted` / `Spec.inkMuted` — неактивный label.
- `ColorTokens.Semantic.error` — badge fill.
- `ColorTokens.Overlay.shadowMedium` — drop shadow capsule.
- `SpacingTokens.tiny` (8pt) — внутр. padding bar; `.regular` (16) / `.small` (12) — pad сегмента.
- `RadiusTokens` — нет (используется `Capsule(style: .continuous)`).
- `.ultraThinMaterial` (iOS 17/26) — фон bar.

**Animation:**
- `matchedGeometryEffect(id: "indicator")` для capsule-индикатора.
- `withAnimation(.spring(response: 0.35, dampingFraction: 0.78))` при select.
- `.symbolEffect(.bounce, value: isSelected)` на SF Symbol.
- Title fade-in: `.opacity.combined(with: .scale(scale: 0.9))`.
- Reduce Motion → переключение без `withAnimation`.

**Used в Features:**
- `Features/ChildHome/ChildHomeView.swift` — 4 таба (home / lessons / progress / rewards).
- `Features/ParentHome/ParentHomeView.swift` — 3 таба.
- `Features/Specialist/SpecialistHomeView.swift` — 4 таба.

**Snapshot test states (v24 backlog):**
- Light + Dark.
- Selected first / last / middle.
- Badge: none / `5` / `9+`.
- Reduce Motion enabled.
- 3 контура (kid / parent / specialist).

---

## 2. HSHeroCardTransition

**File:** `HappySpeech/DesignSystem/Components/HSHeroCardTransition.swift`
**Статус:** реализован (165 LOC) — это set View-extension'ов + container.
**Public API:**

```swift
@available(iOS 17.0, *)
public extension View {
    func heroSource<ID: Hashable>(id: ID, namespace: Namespace.ID) -> some View
    func heroDestination<ID: Hashable>(id: ID, namespace: Namespace.ID) -> some View
}

@available(iOS 17.0, *)
public struct HSHeroCardContainer<ID: Hashable, Content: View>: View {
    public init(
        id: ID,
        namespace: Namespace.ID,
        onTap: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    )
}
```

**Tokens:** не использует напрямую — обёртка работает над пользовательским контентом.

**Animation:**
- iOS 18+: `matchedTransitionSource(id:in:)` + `navigationTransition(.zoom(sourceID:in:))`.
- iOS 17 fallback: `matchedGeometryEffect(id:in:, isSource: true)` + стандартный slide.
- Pressed scale: `0.97` через `simultaneousGesture(DragGesture(minimumDistance: 0))`.
- Reduce Motion → scaleEffect отключается, transition fall back to opacity.

**Used в Features:**
- `Features/ChildHome` — `LessonCard → SessionShell` push.
- `Features/SoundPacks` — `SoundPackCard → SoundPackDetail`.
- `Features/ParentHome` — `ChildProfileCard → ChildProfileDetail` (если включено).

**Snapshot test states:**
- Idle vs. pressed state (Light + Dark).
- iOS 17 fallback path vs. iOS 18 native zoom (verify через `if #available`).
- 3 grid sizes (1 / 2 / 6 cards).

---

## 3. HSGlassNavigationBar

**File:** `HappySpeech/DesignSystem/Components/HSGlassNavigationBar.swift`
**Статус:** реализован (162 LOC).
**Public API:**

```swift
@available(iOS 17.0, *)
public struct HSGlassNavigationBar<Trailing: View>: View {
    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    )
}
```

**Tokens:**
- `ColorTokens.Kid.ink` / `Parent.ink` / `Spec.ink` — текст и chevron.
- `ColorTokens.Overlay.highlight` — border line 0.5pt.
- `ColorTokens.Overlay.shadow` — drop shadow.
- `.ultraThinMaterial` — fill (iOS 26 заменяется на `.glassEffect()` через `#available`-ветку — TODO в комментарии файла).
- `SpacingTokens.regular` (16) — горизонтальные отступы; `.small` (12) — vertical.
- `RadiusTokens.card` (24) — rounded rectangle shape.

**Animation:**
- Нет встроенной — статичный bar. Появление/исчезновение управляется родителем (push/pop NavStack).
- Haptic: `hapticService.impact(.light)` при tap back.

**Used в Features:**
- Каждый custom-detail экран, не использующий системный NavBar (LessonDetail, SoundPackDetail, ParentReport, SpecialistReport).
- `Features/Settings/SettingsView.swift` — нестандартный заголовок.

**Snapshot test states:**
- Title only / title + subtitle.
- With back button / without.
- Trailing: empty / single button / 2 buttons.
- Light + Dark, 3 контура.
- iOS 26 path verified manually (Liquid Glass).

---

## 4. HSSegmentedPicker

**File:** `HappySpeech/DesignSystem/Components/HSSegmentedPicker.swift`
**Статус:** реализован (258 LOC).
**Public API:**

```swift
@available(iOS 17.0, *)
public struct HSSegmentedPicker<Item: Hashable>: View {
    public enum Style { case capsule, underline, solid }

    public init(
        selection: Binding<Item>,
        items: [Item],
        style: Style = .capsule,
        titleProvider: @escaping (Item) -> LocalizedStringKey
    )
}
```

**Tokens:**
- Accent: `Brand.primary` / `Parent.accent` / `Spec.accent` (по `circuitContext`).
- Track fill: `Kid.surfaceAlt` / `Parent.surface` / `Spec.panel`.
- Text muted: `Kid.inkMuted` / `Parent.inkMuted` / `Spec.inkMuted`.
- `ColorTokens.Overlay.separator` — underline mode.
- `SpacingTokens.micro` (4pt) — padding inside capsule track; `.small` (12) — vertical sticker.
- `RadiusTokens.sm` (12) — `.solid` style background.

**Animation:**
- `matchedGeometryEffect(id: "indicator")` для индикатора.
- `withAnimation(.spring(response: 0.3, dampingFraction: 0.78))` при выборе.
- Haptic: `hapticService.selection()` на каждый select.

**Used в Features:**
- `Features/Settings` — выбор темы.
- `Features/ParentHome` — фильтр Daily / Weekly / Monthly.
- `Features/FamilyVoice` — модальный выбор.
- `Features/ProgressDashboard` — переключение между метриками.

**Snapshot test states:**
- 3 стиля × 3 контура × 2 темы = 18 snapshots.
- 2 / 3 / 5 items.
- First / middle / last selected.
- Reduce Motion enabled.

---

## 5. HSMascotPullToRefresh

**File:** `HappySpeech/DesignSystem/Components/HSMascotPullToRefresh.swift`
**Статус:** реализован (190 LOC) — ViewModifier + расширение View.
**Public API:**

```swift
@available(iOS 17.0, *)
public extension View {
    func hsMascotRefresh(action: @escaping @Sendable () async -> Void) -> some View
}
```

**Tokens:**
- `ColorTokens.Brand.primary` (opacity 0.18) — фон circle под маскотом.
- `ColorTokens.Brand.primary` — tint mascot SF Symbol.
- Размеры: circle 56×56pt, иконка 28pt.

**Animation:**
- Pull progress 0 → 1 (threshold pullOffset / 80).
- States: `.thinking` (drag) → `.waving` (threshold) → `.celebrating` (refreshing).
- `PhaseAnimator([1.0, 1.15, 1.0])` — pulse во время refresh (`.easeInOut(duration: 0.6)`).
- Rotation `progress × 360 × 0.5` во время drag.
- Reduce Motion → отключает phaseAnimator, scale-эффект остаётся минимальным.

**Used в Features (ТОЛЬКО kid-контур):**
- `Features/ChildHome/ChildHomeView.swift` — обновление daily plan.
- `Features/SessionHistory/SessionHistoryView.swift` — refetch sessions.
- `Features/Rewards/RewardsView.swift` — refresh achievements.

**Snapshot test states (animation-heavy — приоритет на unit-tests):**
- Idle (no pull).
- Pull at progress 0.3 / 0.7 / 1.0.
- Active refreshing.
- Reduce Motion.

---

## 6. HSSwipeCardStack

**File:** `HappySpeech/DesignSystem/Components/HSSwipeCardStack.swift`
**Статус:** реализован (213 LOC).
**Public API:**

```swift
@available(iOS 17.0, *)
public struct HSSwipeCardStack<Item: Identifiable, Card: View>: View {
    public enum SwipeDirection { case left, right }

    public init(
        items: [Item],
        maxVisible: Int = 3,
        onSwipe: @escaping (Item, SwipeDirection) -> Void,
        @ViewBuilder card: @escaping (Item) -> Card
    )
}
```

**Tokens:** не использует напрямую — pass-through контент. В preview — `ColorTokens.Brand.primary/mint/lilac/butter`.

**Animation:**
- DragGesture: offset + rotation `degrees(offset.width / 20)`.
- Top opacity убывает при abs(offset.width) → 200.
- Threshold ±150pt → fly-out 600pt via `.easeOut(duration: 0.28)`.
- Spring snap-back если ниже threshold: `.spring(response: 0.35, dampingFraction: 0.7)`.
- Stack scale: `1.0 - depth × 0.05`, yOffset: `depth × 12`.
- Haptic: `hapticService.impact(.light)` на каждый swipe.
- Reduce Motion → drag не двигает карточку, swipe выполняется мгновенно.

**Used в Features:**
- `Features/Games/MinimalPairs` — выбор между двумя похожими словами.
- `Features/Games/Sorting` — сортировка карточек.
- `Features/Games/SoundHunter` — drag-cards вариант.

**Snapshot test states:**
- 0 / 1 / 3 / 5 items в стеке.
- Top card at idle / drag 50pt / drag 150pt (threshold).
- Reduce Motion.

---

## 7. HSOnboardingParallax

**File:** `HappySpeech/DesignSystem/Components/HSOnboardingParallax.swift`
**Статус:** реализован (292 LOC) — самый крупный компонент пакета.
**Public API:**

```swift
@available(iOS 17.0, *)
public struct HSOnboardingParallax: View {
    public struct Page: Identifiable {
        public init(
            imageName: String,
            title: LocalizedStringKey,
            subtitle: LocalizedStringKey,
            mascotState: LyalyaState = .waving
        )
    }

    public init(pages: [Page], onFinish: @escaping () -> Void)
}
```

**Tokens:**
- `ColorTokens.Brand.primaryLo / butter / rose / mint / sky / lilac / primary / gold` — палитра MeshGradient (9 control points × 2 phases).
- `ColorTokens.Kid.bg / bgSofter / ink / inkMuted / line` — текст и нейтральные точки.
- `SpacingTokens.large` (24) — между Title и Subtitle; `.regular` (16) — внутри секции; `.screenEdge` (24) — нижний CTA.
- Размер illustration: 260pt height.
- TypographyTokens.titleLarge() / body(16) / caption().

**Animation:**
- `.scrollTransition(.interactive)` — illustration scale `1.0 - 0.15 × |phase|`, offset Y `−40 × phase`, opacity `1 − 0.4 × |phase|`.
- Page indicator capsule: `.spring(response: 0.35, dampingFraction: 0.8)`.
- iOS 18+: `MeshGradient` 3×3 9 colors — animated с `easeInOut(duration: 0.8)` через `meshProgress`.
- iOS 17 fallback: статичный `LinearGradient(topLeading → bottomTrailing)`.
- CTA spring: `.spring(response: 0.45, dampingFraction: 0.78)`.
- Reduce Motion → scrollTransition `.identity`, MeshGradient без анимации.

**Used в Features:**
- `Features/Onboarding/OnboardingFlowView.swift` — 10 страниц онбординга.

**Snapshot test states:**
- First / middle / last page selected.
- With illustration asset / без (SF Symbol fallback).
- iOS 17 (LinearGradient) vs iOS 18 (MeshGradient) — manual verification.
- Light + Dark.
- 3 / 5 / 10 pages indicator counts.

---

## 8. HSSkeletonShimmer

**File:** `HappySpeech/DesignSystem/Components/HSSkeletonShimmer.swift`
**Статус:** реализован (146 LOC) — ViewModifier + готовые shapes.
**Public API:**

```swift
@available(iOS 17.0, *)
public extension View {
    func hsShimmer(active: Bool = true) -> some View
}

@available(iOS 17.0, *)
public struct HSSkeletonRow: View {
    public init(height: CGFloat = 20)
}

@available(iOS 17.0, *)
public struct HSSkeletonCard: View {
    public init()
}
```

**Tokens:**
- `ColorTokens.Overlay.highlight` — band-цвет shimmer gradient.
- `ColorTokens.Overlay.dimmer` — fill для `HSSkeletonRow`.
- `ColorTokens.Kid.surface` — фон `HSSkeletonCard`.
- `RadiusTokens.xs` (8) — row corner; `.card` (24) — card corner.
- `SpacingTokens.small` (12) / `.cardPad` (20) — paddings.

**Animation:**
- LinearGradient sweep: bandWidth 0.4, duration 1.4s, `.linear` `repeatForever(autoreverses: false)`.
- `blendMode(.overlay)` — natural look поверх любого контента.
- Reduce Motion → анимация не запускается (статичный shimmer = просто dimmer слой).

**Used в Features:**
- `Features/ChildHome/ChildHomeViewListComponents.swift` — `HSSkeletonCard ×3` на loading.
- `Features/SessionHistory` — список skeleton rows.
- `Features/ProgressDashboard` — chart placeholder.
- `Features/Rewards` — grid скелетов.

**Snapshot test states:**
- HSSkeletonRow heights 12 / 20 / 32.
- HSSkeletonCard.
- 3 cards stack (как в preview).
- Reduce Motion (статичный кадр).
- Light + Dark.

---

## 9. HSEmptyStateView (already-existing, v18 Block J)

**File:** `HappySpeech/DesignSystem/Components/HSEmptyStateView.swift`
**Статус:** реализован (295 LOC) **до v23**. Создан в Block O v16, расширен в Block J v18 (convenience variants).
**Public API:**

```swift
@available(iOS 17.0, *)
public struct HSEmptyStateView: View {
    public enum IllustrationKind {
        case symbol(String)
        case mascot(LyalyaState)
    }

    // Старое API — SF Symbol
    public init(icon: String, title: String, message: String,
                action: (() -> Void)? = nil, actionTitle: String = "Попробовать")

    // Новое API — маскот
    public init(mascot: LyalyaState, title: String, subtitle: String,
                actionTitle: String = "Попробовать", action: (() -> Void)? = nil)
}

// Convenience variants (v18 Block J B.10):
public extension HSEmptyStateView {
    static func lessons(actionTitle: String, action: (() -> Void)?) -> HSEmptyStateView
    static func tasks(actionTitle: String, action: (() -> Void)?) -> HSEmptyStateView
    static func achievements(actionTitle: String, action: (() -> Void)?) -> HSEmptyStateView
    static func notifications(actionTitle: String, action: (() -> Void)?) -> HSEmptyStateView
    static func search(query: String, actionTitle: String, action: (() -> Void)?) -> HSEmptyStateView
    static func custom(icon: String, title: String, message: String,
                       actionTitle: String, action: (() -> Void)?) -> HSEmptyStateView
}
```

**Tokens:**
- `ColorTokens.Brand.primary` (opacity 0.15) — фон circle под маскотом.
- `SpacingTokens.large` / `.small` / `.xLarge` — vertical rhythm.
- `RadiusTokens` — нет (circle).
- TypographyTokens.headline (bold) / body (secondary).
- Illustration size: 120pt height, mascot 96pt.

**Animation:**
- `IdleBounceModifier` — `PhaseAnimator([0, 1, 0])` через `.easeInOut(duration: 1.4)`.
- Scale 1.0 → 1.05, offset Y −6pt.
- Reduce Motion → bounce отключается.

**Used в Features:**
- `Features/SessionHistory` — `.lessons` variant.
- `Features/HomeTasks` — `.tasks` variant.
- `Features/Rewards` — `.achievements` variant.
- `Features/Settings` — `.notifications` variant.
- `Features/SoundPacks` (search results) — `.search(query:)` variant.

**v24 verification:** snapshot tests on 5 convenience variants × 2 themes = 10 snapshots. Variant с маскотом — отдельная категория.

> **NOTE для ios-developer:** этот компонент уже существует, в v24 НЕ нужно его пересоздавать — только верифицировать DoD (snapshot, accessibility, Dynamic Type).

---

## 10. HSMeshGradientBackground

**File:** `HappySpeech/DesignSystem/Components/HSMeshGradientBackground.swift`
**Статус:** реализован (155 LOC) — bonus компонент.
**Public API:**

```swift
@available(iOS 17.0, *)
public struct HSMeshGradientBackground: View {
    public enum Palette { case kidWarm, kidCool, rewards, calm }

    public init(palette: Palette = .kidWarm, animated: Bool = true)
}
```

**Tokens (palette compositions):**
- `.kidWarm`: primaryLo + butter + rose + bgSofter.
- `.kidCool`: sky + lilac + mint + bgSoft.
- `.rewards`: gold + butter + primaryLo.
- `.calm`: mint + sky + lilac.
- Все 4 палитры используют по 9 control colors (3×3 grid).

**Animation:**
- iOS 18+: `MeshGradient` 3×3 с control points сдвигаются по offset 0.18 через `easeInOut(duration: 4).repeatForever(autoreverses: true)`.
- iOS 17 fallback: ZStack из `LinearGradient(topLeading → bottomTrailing)` + 2 `RadialGradient` (без анимации).
- Reduce Motion → offset = 0, статичный mesh.

**Used в Features:**
- `Features/ChildHome` — `.kidWarm` фон.
- `Features/Rewards` — `.rewards` фон + конфетти overlay.
- `Features/Onboarding` — динамически переключается через `HSOnboardingParallax` (отдельная palette внутри parallax).
- `Features/StutteringModule/FluencyDiary` — `.calm`.

**Snapshot test states:**
- 4 палитры × 2 темы = 8 snapshots.
- iOS 17 fallback vs iOS 18 mesh — manual.
- animated: true / false.

---

## 11. HSScrollTransitionList

**File:** `HappySpeech/DesignSystem/Components/HSScrollTransitionList.swift`
**Статус:** реализован (112 LOC) — bonus, чистый View-extension.
**Public API:**

```swift
@available(iOS 17.0, *)
public enum HSScrollEffectStyle {
    case fade
    case scaleFade
    case parallax
    case tiltCarousel
}

@available(iOS 17.0, *)
public extension View {
    func hsScrollEffect(_ style: HSScrollEffectStyle) -> some View
}
```

**Tokens:** не использует напрямую (transform-only).

**Animation (per style):**
- `.fade` — opacity `1 − 0.6 × |phase|`.
- `.scaleFade` — scale `1 − 0.15 × |phase|` + opacity `1 − 0.5 × |phase|`.
- `.parallax` — offset Y `24 × phase`.
- `.tiltCarousel` — scale `0.85 + 0.15 × (1 − |phase|)` + rotation3D `−8° × phase` (axis Y, perspective 0.4) + opacity `1 − 0.3 × |phase|`.
- Reduce Motion → возвращает content без модификации.

**Used в Features:**
- `Features/WorldMap/WorldMapView.swift` — `.tiltCarousel` для карты уровней.
- `Features/SessionHistory` — `.scaleFade` для timeline rows.
- `Features/Rewards` — `.parallax` для badges grid.
- `Features/ChildHome` — `.fade` для daily lesson list.

**Snapshot test states:**
- Это animation-only modifier — snapshot покрывает только idle position.
- Все 4 стиля × 2 темы = 8 snapshots.
- Reduce Motion (идентично default).

---

## Сводная таблица

| # | Component                  | LOC | iOS req. | Уже в Features? | Snapshot DoD v24 |
|---|----------------------------|-----|----------|-----------------|------------------|
| 1 | HSAnimatedTabBar           | 240 | 17       | ChildHome, ParentHome, SpecialistHome | TODO |
| 2 | HSHeroCardTransition       | 165 | 17 / 18+ | ChildHome, SoundPacks | TODO |
| 3 | HSGlassNavigationBar       | 161 | 17 (26 future) | Detail screens, Settings | TODO |
| 4 | HSSegmentedPicker          | 258 | 17       | Settings, ParentHome, FamilyVoice, Progress | TODO |
| 5 | HSMascotPullToRefresh      | 190 | 17       | ChildHome, SessionHistory, Rewards | TODO |
| 6 | HSSwipeCardStack           | 213 | 17       | Games: MinimalPairs, Sorting, SoundHunter | TODO |
| 7 | HSOnboardingParallax       | 292 | 17 / 18+ | OnboardingFlowView | TODO |
| 8 | HSSkeletonShimmer          | 146 | 17       | ChildHome, SessionHistory, Progress, Rewards | TODO |
| 9 | HSEmptyStateView           | 295 | 17       | SessionHistory, HomeTasks, Rewards, Settings, SoundPacks (search) | TODO |
| 10 | HSMeshGradientBackground  | 155 | 17 / 18+ | ChildHome, Rewards, FluencyDiary | TODO |
| 11 | HSScrollTransitionList    | 112 | 17       | WorldMap, SessionHistory, Rewards, ChildHome | TODO |

**Итого LOC:** 2 227 строк (production code, без preview-блоков ~1 700).

---

## v24 Acceptance Checklist (для ios-developer)

Для каждого компонента в v24:

- [ ] Прочитать source файл и зафиксировать соответствие spec в этом документе.
- [ ] Если расхождение — обновить spec, не код (если код корректен).
- [ ] Если код некорректен — fix + commit отдельным `fix(component): …` коммитом.
- [ ] Добавить snapshot tests согласно списку `Snapshot test states` (snapshotting `SnapshotTesting`).
- [ ] Проверить SwiftLint strict pass.
- [ ] Проверить, что используется ТОЛЬКО `ColorTokens` / `SpacingTokens` / `RadiusTokens` / `TypographyTokens` (никаких hex / magic numbers).
- [ ] Прогнать accessibility-auditor скилл — Dynamic Type Small / accessibilityLarge, VoiceOver labels.
- [ ] Записать результат в `.claude/team/v24-hscustom-implementation-report.md`.

---

## Версионирование и история

- v16 (Block O): первая реализация всех 11 компонентов как часть «kavsoft pack».
- v18 (Block J B.10): расширение HSEmptyStateView convenience variants.
- v21 (Block C): запрет эмодзи в DesignSystem → миграция на `LyalyaState.fallbackSFSymbol`.
- v23 (Block 3.1): заявлено как HSCustom* — фактически документация отставала.
- v24 (Block 2.1, этот файл): полная сверка реального кода со спецификацией, баклог snapshot-тестов.
