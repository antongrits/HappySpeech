# Kavsoft + SwiftUI Custom UI Research v16 (Block O)

**Дата:** 2026-05-07
**Researcher:** researcher агент (Sonnet @ high)
**Источники:** 37 URLs из kavsoft.dev, GitHub MIT repos, Apple WWDC23-26, AppCoda, SwiftUI Lab, Hacking with Swift

---

## Section 1 — Top 10 patterns from kavsoft

Из GitHub-репо [recherst/kavsoft-swiftui-animations](https://github.com/recherst/kavsoft-swiftui-animations) задокументировано **85+ проектов** от Kavsoft. Самые применимые к HappySpeech:

### 1.1 — Tab Bar патт еrns (matchedGeometryEffect)

**Animated Curved Tab Bar / Matched Geometry Tab Bar / Elastic Tab Bar / Scrollable Tab Bar.**

Ключевая техника: фоновый capsule/indicator получает `matchedGeometryEffect(id: selectedTab, in: ns, isSource: false)`, каждая кнопка — `isSource: true`. State-change в `withAnimation(.spring(response: 0.35))`.

Источники:
- [kavsoft.dev/matched_geometry_tabbar](https://kavsoft.dev/matched_geometry_tabbar)
- [kavsoft.dev/SwiftUI_2.0/Animated_Curved_Tabbar](https://kavsoft.dev/SwiftUI_2.0/Animated_Curved_Tabbar)
- [kavsoft.dev/animated_elastic_tab_bar](https://kavsoft.dev/animated_elastic_tab_bar)

### 1.2 — Hero Transition

**App Store Hero Animation / WhatsApp Hero Animation.** Две версии:
- Старая через `matchedGeometryEffect` напрямую
- Новая iOS 18 через `matchedTransitionSource(id:in:)` + `navigationTransition(.zoom(sourceID:in:))` — буквально 3 строки кода

Источники:
- [kavsoft.dev/swiftui_3.0_hero_animation](https://kavsoft.dev/swiftui_3.0_hero_animation)
- [Patreon — SwiftUI Stack 17/18](https://www.patreon.com/posts/swiftui-stack-17-115934965)
- [Peter Friese — Hero Animations](https://peterfriese.dev/blog/2024/hero-animation/)

### 1.3 — Pull-to-Refresh + Lottie

Кастомный pull-to-refresh с Lottie-анимацией. Отслеживание scroll offset через `PreferenceKey`, при offset > threshold — Lottie/маscot анимация.

Источник: [kavsoft.dev/swiftui_3.0_pull_refresh_lottie_may](https://kavsoft.dev/swiftui_3.0_pull_refresh_lottie_may)

### 1.4 — Skeleton Loading View / Shimmer

`LinearGradient` с тремя стопами (base → highlight → base) анимирует `startPoint` от `(-1, 0.5)` до `(1, 0.5)` за 1.5 сек `repeatForever`. Накладывается на `.redacted(reason: .placeholder)`.

Источники:
- [Patreon Skeleton View](https://www.patreon.com/posts/swiftui-skeleton-126526147)
- SPM альтернатива: [github.com/markiv/SwiftUI-Shimmer](https://github.com/markiv/SwiftUI-Shimmer) (MIT)

### 1.5 — Parallax / Carousel

Parallax Carousel, Stacked Carousel Slider, Parallax With Sticky Header, Hero Carousel Slider, Liquid Swipe.

### 1.6-1.10 — Special

YouTube Mini Player, Snapchat Transition, Mobile Wallet Card Animation, Custom NavBar, Navigation Drawer.

---

## Section 2 — Modern SwiftUI iOS 17/26 affordances

### 2.1 — `scrollTransition` (iOS 17)

Фазы -1/0/+1 для opacity, scale, blur, rotation при скролле. `.interactive` (плавное) и `.animated` (триггер).

Источники:
- [Apple WWDC23 — Beyond scroll views](https://developer.apple.com/videos/play/wwdc2023/10159/)
- [AppCoda ScrollView Transition](https://www.appcoda.com/swiftui-scroll-view-transition/)

### 2.2 — `containerRelativeFrame` (iOS 17)

Заменяет `GeometryReader` для размеров относительно контейнера. **Критично для SE 3** (320pt) — карточки адаптируются автоматически.

### 2.3 — `PhaseAnimator` (iOS 17)

Многошаговая анимация через `Sequence`. Идеально для маскота Ляли (bounce → spin → wiggle циклически).

Источники:
- [SwiftUI Lab Part 7](https://swiftui-lab.com/swiftui-animations-part7/)
- [Apple WWDC23 Session 10157](https://developer.apple.com/videos/play/wwdc2023/10157/)

### 2.4 — `KeyframeAnimator` (iOS 17)

Независимые треки для разных свойств (scale, rotation, offset).

Источник: [AppCoda KeyframeAnimator](https://www.appcoda.com/keyframeanimator/)

### 2.5 — `MeshGradient` (iOS 18)

Сетка 3x3 точек с цветами. Анимируется через `withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true))`. Отличная база для фона kid-контура.

Источники:
- [Hacking with Swift MeshGradient](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-mesh-gradient)
- [Donny Wals MeshGradient iOS 18](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/)
- [Rudrank Riyam Animating MeshGradient](https://rudrank.com/exploring-swiftui-animating-mesh-gradient-with-colors-in-ios-18/)

### 2.6 — `glassEffect` / Liquid Glass (iOS 26)

`.glassEffect()` модификатор + `GlassEffectContainer` для морфинга между формами через `.glassEffectID()`.

Источники:
- [Apple Docs — Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [DEV — GlassEffectContainer](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)

### 2.7 — `symbolEffect` для SF Symbols

`.symbolEffect(.bounce)`, `.symbolEffect(.rotate)`, `.symbolEffect(.pulse)`, `.symbolEffect(.variableColor)`.

Источник: [Hacking with Swift symbolEffect](https://www.hackingwithswift.com/quick-start/swiftui/how-to-animate-sf-symbols)

---

## Section 3 — Other SwiftUI channels

- **Paul Hudson (Hacking with Swift)** — исчерпывающая документация SwiftUI features
- **Peter Friese** — лучший туториал hero animation iOS 18
- **SwiftUI Lab** — deep dive `matchedGeometryEffect`, `PhaseAnimator`
- **nilcoalescing** — custom segmented control
- **AppCoda** — `scrollTransition`, `KeyframeAnimator`
- **avanderlee (SwiftLee)** — dynamic pager view onboarding
- **Antoine van der Lee** — best practices Swift Concurrency

---

## Section 4 — 10 HSCustom*.swift спецификации

### 4.1 — `HSAnimatedTabBar.swift`

Кастомный tab bar вместо системного `TabView`. Горизонтальный `HStack` из иконок + лейблов. Активный элемент выделяется capsule-фоном через `matchedGeometryEffect` (isSource: false на capsule, isSource: true на каждой кнопке). State-change обёрнут в `withAnimation(.spring(response: 0.35))`. Badge через `ZStack` + `Circle` с `PhaseAnimator` для pulse-эффекта при новых уведомлениях. Поддерживает 4–5 табов, иконки SF Symbols с `symbolEffect(.bounce)` при tap.

### 4.2 — `HSHeroCardTransition.swift`

Карточка-источник для hero перехода в навигацию. Использует `matchedTransitionSource(id: card.id, in: heroNamespace)` на карточке в списке. Destination View применяет `navigationTransition(.zoom(sourceID: card.id, in: heroNamespace))`. Работает на iOS 18+; fallback на iOS 17 — `matchedGeometryEffect` с `@State isExpanded`. Применимо к карточкам уроков (`LessonCard`), профилям детей, звуковым пакам.

### 4.3 — `HSGlassNavigationBar.swift`

Кастомный навбар поверх контента (не системный). `ZStack` с контентом внизу, навбар сверху фиксирован через `.safeAreaInset(edge: .top)`. Фон — `.ultraThinMaterial` с небольшим `RoundedRectangle` clip. На iOS 26 — `.glassEffect()` с `GlassEffectContainer`. Back button кастомный (SF Symbol `chevron.left` + haptic). Заголовок с `matchedGeometryEffect` для плавного появления при push.

### 4.4 — `HSSegmentedPicker.swift`

Generic `<T: CaseIterable & Hashable & Localizable>` сегментированный контрол. Capsule-индикатор через `matchedGeometryEffect`. Поддерживает 2–5 сегментов, адаптируется через `containerRelativeFrame`. Underline-вариант (rectangle height:2) для родительского контура. Children-вариант (rounded capsule, ColorTokens.Brand.primary). `withAnimation(.spring(response: 0.3, dampingFraction: 0.7))` при переключении.

### 4.5 — `HSMascotPullToRefresh.swift`

Pull-to-refresh с анимацией Ляли. Отслеживает scroll offset через `PreferenceKey`. При offset > 60pt — Ляля появляется сверху с `PhaseAnimator` (bounce → wave → spin). При отпускании — запускается refresh + Ляля "тянет" верёвку. `async/await` refresh callback. Используется только в kid-контуре (`ChildHomeView`, `SessionHistoryView`).

### 4.6 — `HSSwipeCardStack.swift`

Стек карточек с Tinder-свайпом. `ZStack` карточек где верхняя реагирует на `DragGesture`. При drag — `rotationEffect(Angle(degrees: offset.x / 20))` + `opacity` fade. Dismiss при `abs(offset.x) > 150`. Следующие карточки масштабируются `scale(0.95)` → `scale(1.0)` при появлении. Применяется в упражнениях `minimal-pairs` и `sorting`.

### 4.7 — `HSOnboardingParallax.swift`

Onboarding с параллакс-эффектом. `TabView` + `.tabViewStyle(.page)`. Каждая страница — `GeometryReader` (или `scrollTransition`) для смещения фонового слоя на `offset * 0.3` (parallax ratio). Передний слой — иллюстрация + текст. `MeshGradient` фон с анимацией цветов между страницами.

### 4.8 — `HSSkeletonShimmer.swift`

ViewModifier `shimmer()` для состояния загрузки. Внутри — `LinearGradient` с тремя стопами (base → highlight → base) анимирует `startPoint` от `(-1, 0.5)` до `(1, 0.5)` за 1.5 сек `repeatForever`. Накладывается на `.redacted(reason: .placeholder)` контент.

### 4.9 — `HSEmptyStateView.swift`

Branded empty state с Лялей. Параметры: `illustration: LyalyaExpression`, `title: LocalizedStringKey`, `subtitle: LocalizedStringKey`, `action: (() -> Void)?`. Ляля анимируется через `PhaseAnimator` (idle bounce). Кнопка — `HSPrimaryButton`. Поддерживает варианты: `.noLessons`, `.noProgress`, `.offlineMode`, `.searchEmpty`.

### 4.10 — `HSCustomAlert.swift`

Non-system брендированный алерт. Реализован как `ZStack` overlay через `ViewModifier` (`.hsAlert(...)`). Фон — `.ultraThinMaterial` blur + затемнение. Контейнер — `RoundedRectangle` с `shadow` и `ColorTokens.Kid.surface`. Появление через `.transition(.scale(scale: 0.9).combined(with: .opacity))`. Поддерживает: title, subtitle, иконку SF Symbol / LyalyaExpression, до 3 кнопок.

---

## Section 5 — Применение в HappySpeech

**Топ-5 паттернов для немедленного внедрения:**

1. `HSAnimatedTabBar` заменяет все три системных TabView (kid / parent / specialist) — самое заметное улучшение визуала
2. `HSHeroCardTransition` применить к `LessonCard → SessionShell` и `SoundPackCard → SoundPackDetail` — App Store-like wow-эффект
3. `HSMeshGradientBackground` — для фона `ChildHomeView` вместо статичного цвета
4. `HSSkeletonShimmer` — `ChildHomeView` сейчас показывает пустоту при загрузке
5. `HSCustomAlert` — устранить системные `Alert` из kid-контура

**SPM пакеты для add (MIT, COPPA-safe):**
- `markiv/SwiftUI-Shimmer` — простой shimmer modifier
- `exyte/FloatingButton` — раскрывающееся FAB меню
- `dadalar/SwiftUI-CardStackView` — Tinder-style cards

**Ограничение iOS 26 Liquid Glass (`glassEffect`)** — `@available(iOS 26, *)` guard обязателен, fallback на `.ultraThinMaterial`.

---

## Section 6 — Полный список references (37 URLs)

- [Kavsoft — Matched Geometry Tab Bar](https://kavsoft.dev/matched_geometry_tabbar)
- [Kavsoft — Animated Curved Tab Bar](https://kavsoft.dev/SwiftUI_2.0/Animated_Curved_Tabbar)
- [Kavsoft — Elastic Tab Bar](https://kavsoft.dev/animated_elastic_tab_bar)
- [Kavsoft — Hero Animation App Store](https://kavsoft.dev/swiftui_3.0_hero_animation)
- [Kavsoft — Custom Pull To Refresh Lottie](https://kavsoft.dev/swiftui_3.0_pull_refresh_lottie_may)
- [Kavsoft — Navigation Stack Hero iOS 17/18 (Patreon)](https://www.patreon.com/posts/swiftui-stack-17-115934965)
- [Kavsoft — Skeleton View (Patreon)](https://www.patreon.com/posts/swiftui-skeleton-126526147)
- [GitHub recherst/kavsoft-swiftui-animations (85 проектов)](https://github.com/recherst/kavsoft-swiftui-animations)
- [GitHub MatHeartGaming/coolStuff_with_SwiftUI](https://github.com/MatHeartGaming/coolStuff_with_SwiftUI)
- [Peter Friese — Hero Animations NavigationTransition iOS 18](https://peterfriese.dev/blog/2024/hero-animation/)
- [AppCoda — Navigation Transition iOS 18](https://www.appcoda.com/navigation-transition/)
- [AppCoda — ScrollView Transition iOS 17](https://www.appcoda.com/swiftui-scroll-view-transition/)
- [AppCoda — KeyframeAnimator iOS 17](https://www.appcoda.com/keyframeanimator/)
- [SwiftUI Lab — PhaseAnimator Part 7](https://swiftui-lab.com/swiftui-animations-part7/)
- [SwiftUI Lab — matchedGeometryEffect Part 1](https://swiftui-lab.com/matchedgeometryeffect-part1/)
- [nilcoalescing — Custom Segmented Control matchedGeometryEffect](https://nilcoalescing.com/blog/CustomSegmentedControlWithMatchedGeometryEffect/)
- [Hacking with Swift — MeshGradient](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-mesh-gradient)
- [Hacking with Swift — SF Symbols symbolEffect](https://www.hackingwithswift.com/quick-start/swiftui/how-to-animate-sf-symbols)
- [Donny Wals — MeshGradient iOS 18](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/)
- [Rudrank Riyam — Animating MeshGradient iOS 18](https://rudrank.com/exploring-swiftui-animating-mesh-gradient-with-colors-in-ios-18/)
- [Apple WWDC24 — Create custom visual effects SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10151/)
- [Apple WWDC24 — Enhance UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/)
- [Apple WWDC23 — Advanced animations SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10157/)
- [Apple WWDC23 — Beyond scroll views](https://developer.apple.com/videos/play/wwdc2023/10159/)
- [Apple WWDC25 — Build SwiftUI app with new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple Developer Docs — Liquid Glass custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [DEV Community — GlassEffectContainer iOS 26](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)
- [DEV Community — Liquid Glass best practices](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)
- [GitHub markiv/SwiftUI-Shimmer (MIT)](https://github.com/markiv/SwiftUI-Shimmer)
- [GitHub exyte/FloatingButton (MIT)](https://github.com/exyte/FloatingButton)
- [GitHub dadalar/SwiftUI-CardStackView (MIT)](https://github.com/dadalar/SwiftUI-CardStackView)
- [Medium — Tinder Swipe SwiftUI DragGesture](https://medium.com/@jc_builds/creating-tinder-like-swipeable-cards-in-swiftui-193fab1427b8)
- [Medium — Skeleton Shimmer SwiftUI](https://medium.com/@felipaugsts/skeleton-shimmer-in-swiftui-a6668194f6c5)
- [Medium — Custom Alert SwiftUI ViewModifier](https://lukecsmith.co.uk/swiftui/swiftui-custom-alert/)
- [SwiftLee — Dynamic Pager View Onboarding](https://www.avanderlee.com/swiftui/dynamic-pager-view-onboarding/)
- [Lottie iOS — official SwiftUI integration](https://lottiefiles.com/blog/working-with-lottie-animations/how-to-add-lottie-animation-ios-app-swift)
- [GitHub conorluddy/LiquidGlassReference](https://github.com/conorluddy/LiquidGlassReference)
