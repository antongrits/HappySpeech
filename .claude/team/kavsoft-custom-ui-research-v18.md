# kavsoft + Professional iOS UI Patterns Research v18

**Source:** kavsoft YouTube channel + GitHub mirrors (recherst, doxuto) + other professional iOS developers + Apple WWDC23/24/25 + Apple Design Awards 2024
**Date:** 2026-05-08
**Researcher:** researcher agent (Sonnet @ high)

## ⚠️ КРИТИЧЕСКОЕ ОТКРЫТИЕ

В DesignSystem уже **41 компонент** (не 12 как указывалось в audit-v18-baseline). **Все ключевые kavsoft паттерны уже реализованы**. Главная задача Block K — **массовая интеграция готовых 40+ компонентов в Features**, а не создание новых.

Только **3 новых компонента** нужно создать:
- `HSTypewriterText` (~60 LOC) — Ляля говорит посимвольно через `TextRenderer` (iOS 18) / String.prefix fallback
- `HSScratchReveal` (~120 LOC) — scratch-card через Canvas mask + DragGesture для AchievementRevealView
- `HSCardFlip3D` (~80 LOC) — `rotation3DEffect` flip для MemoryGameView

## Полный аудит DesignSystem/Components/ (41 файл)

### Kavsoft-inspired HS* компоненты (12 + 9 бонусных Block O v16)

| Component | LOC | API/Pattern | Apple iOS API |
|---|---|---|---|
| `HSAnimatedTabBar.swift` | ~200 | matchedGeometryEffect capsule | iOS 17 |
| `HSHeroCardTransition.swift` | ~140 | hero zoom navigation | iOS 18 navigationTransition(.zoom) |
| `HSGlassNavigationBar.swift` | ~110 | Liquid Glass navigation | iOS 26 .glassEffect() / iOS 17 .ultraThinMaterial fallback |
| `HSSegmentedPicker.swift` | ~150 | animated segmented control | matchedGeometryEffect |
| `HSMascotPullToRefresh.swift` | ~180 | pull-to-refresh с Лялей | iOS 17 PhaseAnimator |
| `HSSkeletonShimmer.swift` | ~70 | shimmer ViewModifier | SwiftUIShimmer SPM |
| `HSEmptyStateView.swift` | ~120 | branded empty state с Лялей | composition |
| `HSCustomAlert.swift` | ~140 | non-system alert overlay | ZStack + spring |
| `HSSwipeCardStack.swift` | ~220 | Tinder-style swipe deck | DragGesture + rotation |
| `HSOnboardingParallax.swift` | ~190 | parallax onboarding | iOS 18 MeshGradient |
| `HSMeshGradientBackground.swift` | ~80 | iOS 18 animated MeshGradient | iOS 18 MeshGradient |
| `HSScrollTransitionList.swift` | ~210 | scrollTransition пресеты | iOS 17 scrollTransition (.fade/.scaleFade/.parallax/.tiltCarousel) |

### Дополнительные rich components

| Component | LOC | Purpose |
|---|---|---|
| `HSAudioWaveform.swift` | ~280 | Real-time waveform visualizer (recording/playback/spectrogram modes) — критично для речевых упражнений |
| `HSProgressRing.swift` | ~180 | Activity Ring style circular progress |
| `HSConfettiView.swift` | ~150 | Confetti particle celebration через swiftui-particles SPM |
| `HSLottieContainer.swift` | ~90 | Lottie animation wrapper (airbnb/lottie-ios 4.5) |
| `HSLiquidGlassCard.swift` | 107 | iOS 26 .glassEffect() Liquid Glass card |
| `HSChart.swift` | ~200 | Animated Swift Charts wrapper |
| `LyalyaMascotView.swift` | ~250 | Маскот-Ляля root view с состояниями |
| `LyalyaRealityKitView.swift` | ~300 | 3D RealityKit маскот с blendshapes |
| `LyalyaHeroView.swift` | ~150 | Hero presentation Лялы |
| `LyalyaLipSyncCoordinator.swift` | ~200 | Lip sync через AVAudioPlayer amplitude |
| `HSButton.swift` | ~120 | Primary/secondary/tertiary CTA |
| `HSCard.swift` | ~150 | Material card |
| `HSBadge.swift` | ~80 | Status badge |
| `HSProgressBar.swift` | ~100 | Linear progress |
| `HSSpeechBubble.swift` | ~140 | Speech bubble для Лялы |
| `HSPictTile.swift` | ~110 | Picture tile с illustration |
| `HSRewardBurst.swift` | ~160 | Reward burst animation |
| `HSLoadingView.swift` | ~100 | Loading state |
| `HSAudioRecorderView.swift` | ~250 | Audio recorder с waveform |
| `HSSoundChip.swift` | ~90 | Sound category chip |
| `HSContentSymbol.swift` | ~80 | SF Symbol wrapper с тематикой |
| `HSSticker.swift` | ~120 | Sticker view |
| `HSMarkdownView.swift` | ~80 | Markdown rendering через Down SPM |
| `HSOfflineBanner.swift` | ~110 | Offline state banner |
| `HSErrorStateView.swift` | ~140 | Error state с иллюстрацией Лялы |
| `HSMascotView.swift` | ~180 | Маскот container |
| `HomeScreenCard.swift` | ~200 | Home screen card mimicking widget |
| `MouthBubbleOverlay.swift` | ~150 | Mouth bubble overlay для AR-игр |
| `ParentalGate.swift` | ~250 | Parental gate (math problem) для external links |

**Total LOC:** ~7,760 (audit v18 confirmed)

## Главный вывод для Block K

**Задача НЕ создание новых компонентов** — почти все есть. **Задача = массовая интеграция existing 40+ компонентов в Features**. Audit v18-baseline подтвердил: только 1 из 41 компонента фактически используется в Features (HSCustomAlert).

## kavsoft каталог (85+ проектов через GitHub зеркала)

### GitHub mirrors

- [github.com/recherst/kavsoft-swiftui-animations](https://github.com/recherst/kavsoft-swiftui-animations) — 85 проектов
- [github.com/doxuto/kavsoft-animation](https://github.com/doxuto/kavsoft-animation) — 3D, BoomerangCards, DoubleSidedGallery

### Категории kavsoft tutorials релевантные для HappySpeech

**Tab Bars:**
- AnimatedTabBar (matchedGeometryEffect capsule) → ✅ уже HSAnimatedTabBar
- CurvedTabbar (concave shape) — потенциально использовать
- AnimatedSFTabBar (с symbolEffect) → ✅ уже HSAnimatedTabBar
- SharedTabBar — common pattern
- ScrollableTabBar — для child profile switcher

**Hero Transitions:**
- HeroAnimation, WhatsAppHeroAnimation → ✅ уже HSHeroCardTransition
- HeroCarouselSlider — для StoryLibrary preview
- AppStoreAnimations — для DemoView showcase

**Parallax/Scroll:**
- ParallaxCarousel, ParallaxWithStickyHeader → ✅ HSScrollTransitionList с .parallax
- AnimatedStickyHeader → нужно создать `HSStretchyHeader` (50 LOC) для ChildHomeView
- ScalingOnScroll → ✅ HSScrollTransitionList с .scaleFade

**Cards:**
- BoomerangCards — для memory game
- DoubleSidedGallery — для CardFlip3D
- CardAnimation, 3DCardAnimation, 3DShoeApp → нужно создать `HSCardFlip3D` (80 LOC)

**Sheets:**
- BottomSheet, BlurredSheet, AppleMusicBottomSheet → SwiftUI native .sheet + presentationDetents работает

**Loading:**
- AnimatedLoadingScreen, DribbleLoadingBall, TextShimmer → ✅ HSSkeletonShimmer + HSLoadingView

**Interactive:**
- DragAndDropAPI → используется в DragAndMatch game
- LiquidSwipe — wow эффект для onboarding
- SnapchatTransition — между screens
- PullToRefresh → ✅ HSMascotPullToRefresh

**App UIs (вдохновение):**
- AppleMusicAnimations, AppStoreAnimations — для DemoView
- CoffeeAppAnimation, BookAppAnimation — для CulturalContentView (Block R.1.5)

## iOS 17/18/26 API status в HappySpeech

| API | iOS | Статус в проекте |
|---|---|---|
| `scrollTransition` | 17 | ✅ HSScrollTransitionList |
| `containerRelativeFrame` | 17 | ✅ используется |
| `PhaseAnimator` | 17 | ✅ HSMascotPullToRefresh |
| `KeyframeAnimator` | 17 | ⚠️ нужно добавить в HSButton feedback |
| `MeshGradient` | 18 | ✅ HSMeshGradientBackground |
| `navigationTransition(.zoom)` | 18 | ✅ HSHeroCardTransition |
| `matchedTransitionSource` | 18 | ✅ HSHeroCardTransition |
| `glassEffect` / `GlassEffectContainer` | 26 | ✅ HSGlassNavigationBar, HSLiquidGlassCard |
| `symbolEffect` | 17 | ✅ HSAnimatedTabBar (.bounce) — нужно расширить |
| `sensoryFeedback` | 17 | ⚠️ нужно добавить во все game buttons |
| `TextRenderer` | 18 | ❌ не реализован — нужен `HSTypewriterText` |

## SPM пакеты — статус и рекомендации

### Уже в проекте (verified audit v18-baseline)

- `SwiftUIShimmer 1.5.0` ✅
- `FloatingButton 1.4.0` ✅
- `swiftui-particles 1.0` ✅
- `Lottie 4.5` ✅
- `RiveRuntime 6.0` ✅

### Рекомендуется добавить в Block K

- **`twostraws/Vortex`** (MIT) — для fireworks + magic пресетов в SessionCompletionView, дополнение к swiftui-particles
- **`ConfettiSwiftUI` (simibac, MIT)** — альтернатива HSConfettiView, more variety
- **`SwiftUI-CardStackView` (dadalar, MIT)** — для Tinder-style swipe в MinimalPairs/Sorting (или интегрировать pattern в HSSwipeCardStack)

## 3 НОВЫХ компонента для Block K (только эти нужно создать)

### 1. HSTypewriterText (~60 LOC)

```swift
// HappySpeech/DesignSystem/Components/HSTypewriterText.swift
import SwiftUI

@available(iOS 17.0, *)
struct HSTypewriterText: View {
    let text: String
    var speed: Double = 0.04  // sec per character
    @State private var visibleCharCount: Int = 0
    
    var body: some View {
        Text(String(text.prefix(visibleCharCount)))
            .font(TypographyTokens.body)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .onAppear {
                animateTypewriter()
            }
    }
    
    private func animateTypewriter() {
        Task { @MainActor in
            for i in 0...text.count {
                visibleCharCount = i
                try? await Task.sleep(for: .seconds(speed))
            }
        }
    }
}
```

**Применение:** LyalyaSpeechBubble, OnboardingFlowView (steps text), Demo (instructions).

### 2. HSScratchReveal (~120 LOC)

```swift
// HappySpeech/DesignSystem/Components/HSScratchReveal.swift
import SwiftUI

@available(iOS 17.0, *)
struct HSScratchReveal<Foreground: View, Background: View>: View {
    @ViewBuilder var foreground: Foreground  // что под царапанием
    @ViewBuilder var background: Background  // царапающаяся область (например серая)
    
    @State private var scratches: [CGPoint] = []
    let scratchRadius: CGFloat = 30
    
    var body: some View {
        ZStack {
            foreground
            
            background
                .mask {
                    // Reverse mask: показать всё кроме поцарапанных областей
                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                        ctx.blendMode = .destinationOut
                        for point in scratches {
                            ctx.fill(Path(ellipseIn: CGRect(x: point.x - scratchRadius, y: point.y - scratchRadius, width: scratchRadius*2, height: scratchRadius*2)), with: .color(.white))
                        }
                    }
                }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    scratches.append(gesture.location)
                }
        )
    }
}
```

**Применение:** AchievementRevealView, DailyRewardView, SessionCompleteView reward unlock.

### 3. HSCardFlip3D (~80 LOC)

```swift
// HappySpeech/DesignSystem/Components/HSCardFlip3D.swift
import SwiftUI

@available(iOS 17.0, *)
struct HSCardFlip3D<Front: View, Back: View>: View {
    @Binding var isFlipped: Bool
    @ViewBuilder var front: Front
    @ViewBuilder var back: Back
    
    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.spring(duration: 0.6, bounce: 0.2), value: isFlipped)
    }
}
```

**Применение:** MemoryGameView, BingoView (cell reveal), PuzzleRevealView (piece flip).

### HSStretchyHeader (~50 LOC) — bonus

```swift
// HappySpeech/DesignSystem/Components/HSStretchyHeader.swift
struct HSStretchyHeader<Header: View>: View {
    @ViewBuilder var header: Header
    
    var body: some View {
        GeometryReader { proxy in
            let offset = proxy.frame(in: .global).minY
            let stretch = max(0, offset)
            header
                .frame(width: proxy.size.width, height: proxy.size.height + stretch)
                .offset(y: -stretch)
        }
        .frame(height: 280)
    }
}
```

**Применение:** ChildHomeView header, RewardsView, FamilyAchievements.

## Применение в HappySpeech — Roadmap для ios-developer

### Group A — немедленное внедрение existing компонентов (нет новых файлов)

**Priority A.1** (1-2 часа):
1. `HSAnimatedTabBar` → `RootNavigationContainer` (заменить системный TabView)
2. `HSScrollTransitionList` с `.tiltCarousel` → все `LazyVStack` карточки
3. `HSSkeletonShimmer` → `ChildHomeView` loading state

**Priority A.2** (1-2 часа):
4. `HSSegmentedPicker` → `ProgressDashboardView`, `ParentHomeView`, `SoundPackDetailView`
5. `.symbolEffect(.bounce)` → SF Symbol иконки в TabBar + game buttons
6. `.sensoryFeedback(.success/.error)` → все Button в game template views

### Group B — интеграция rich компонентов (2-5 часов)

7. `HSHeroCardTransition` → `LessonCard → SessionShellView` (главный навигационный путь)
8. `HSMeshGradientBackground` → `ChildHomeView` фон
9. `HSSwipeCardStack` → `MinimalPairsGameView` + `SortingGameView`
10. `HSConfettiView` → `SessionCompletionView`
11. `HSProgressRing` → `ChildHomeView` дневной прогресс
12. `HSAudioWaveform` (recording mode) → `ASRRecordingView` live визуализатор
13. `HSOnboardingParallax` → `OnboardingView` (заменить текущий)
14. `HSMascotPullToRefresh` → `ChildHomeView`, `SessionHistoryView`
15. `HSLottieContainer` → расширенное использование (сейчас 1 раз)
16. `HSCustomAlert` → replace system Alert (5+ files)

### Group C — 3 новых компонента (5-8 часов)

17. `HSTypewriterText` (60 LOC) → `LyalyaSpeechBubble`, OnboardingFlowView, DemoView, InstructionView
18. `HSScratchReveal` (120 LOC) → `AchievementRevealView`, `DailyRewardView`, SessionCompleteView reward
19. `HSCardFlip3D` (80 LOC) → `MemoryGameView`, BingoView cell reveal, PuzzleRevealView

### Group D — bonus компонент (опционально)

20. `HSStretchyHeader` (50 LOC) → `ChildHomeView`, `RewardsView`, `FamilyAchievementsView`

### SPM additions

- Add `twostraws/Vortex` (MIT) → `Package.swift`/`project.yml`:
  ```yaml
  Vortex:
    url: https://github.com/twostraws/Vortex
    from: "1.0.0"
  ```
  → use в `SessionCompletionView` для fireworks preset

## Apple Design Award winners 2024/2025 — детский UX

### Crayola Adventures (ADA 2024 Inclusivity)

- Полная нарратизация для non-readers
- Доступные puzzle + storybook UI
- Применение для HappySpeech: voice-over Лялы для каждого экрана + минимум текста

### CapWords (ADA 2024)

- Camera → sticker трансформация объектов с fun animations
- Применение для HappySpeech: ARFaceFilter / ObjectDetection — каждое взаимодействие имеет delight-анимацию

### Главный паттерн: каждое взаимодействие имеет delight-анимацию

- Tap → bounce + sensoryFeedback
- Correct answer → confetti + particle burst
- Streak → flame.fill animation + scale up
- Reward unlock → scratch reveal или 3D card flip
- Level complete → fireworks Vortex preset

## Источники (полный список)

### kavsoft каталог

- [kavsoft.dev — официальный сайт](https://kavsoft.dev/)
- [GitHub recherst/kavsoft-swiftui-animations — 85 проектов](https://github.com/recherst/kavsoft-swiftui-animations)
- [GitHub doxuto/kavsoft-animation — 3D + BoomerangCards](https://github.com/doxuto/kavsoft-animation)

### SPM пакеты

- [GitHub twostraws/Vortex — MIT particles](https://github.com/twostraws/Vortex)
- [GitHub simibac/ConfettiSwiftUI — MIT confetti](https://github.com/simibac/ConfettiSwiftUI)
- [GitHub markiv/SwiftUI-Shimmer — MIT shimmer](https://github.com/markiv/SwiftUI-Shimmer)
- [GitHub dadalar/SwiftUI-CardStackView — MIT card stack](https://github.com/dadalar/SwiftUI-CardStackView)

### Apple Developer

- [Apple Developer — Liquid Glass custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Apple WWDC25 — Build SwiftUI app with new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple WWDC24 — Enhance UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/)
- [Apple WWDC23 — Advanced animations PhaseAnimator/KeyframeAnimator](https://developer.apple.com/videos/play/wwdc2023/10157/)
- [Apple WWDC23 — Beyond scroll views scrollTransition](https://developer.apple.com/videos/play/wwdc2023/10159/)
- [Apple Design Awards 2024](https://developer.apple.com/design/awards/2024/)

### Tutorials

- [Peter Friese — Hero Animations iOS 18](https://peterfriese.dev/blog/2024/hero-animation/)
- [AppCoda — navigationTransition iOS 18](https://www.appcoda.com/navigation-transition/)
- [AppCoda — scrollTransition iOS 17](https://www.appcoda.com/swiftui-scroll-view-transition/)
- [SwiftUI Lab — matchedGeometryEffect deep dive](https://swiftui-lab.com/matchedgeometryeffect-part1/)
- [SwiftUI Lab — PhaseAnimator Part 7](https://swiftui-lab.com/swiftui-animations-part7/)
- [Hacking with Swift — MeshGradient](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-mesh-gradient)
- [Hacking with Swift — symbolEffect SF Symbols](https://www.hackingwithswift.com/quick-start/swiftui/how-to-animate-sf-symbols)
- [Hacking with Swift — sensoryFeedback iOS 17](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback)
- [Donny Wals — MeshGradient iOS 18](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/)
- [Donny Wals — Stretchy Header iOS 18](https://www.donnywals.com/building-a-stretchy-header-view-with-swiftui-on-ios-18/)
- [Rudrank Riyam — Animating MeshGradient iOS 18](https://rudrank.com/exploring-swiftui-animating-mesh-gradient-with-colors-in-ios-18/)
- [nilcoalescing — Custom Segmented Control matchedGeometryEffect](https://nilcoalescing.com/blog/CustomSegmentedControlWithMatchedGeometryEffect/)
- [fatbobman — TextRenderer Typewriter Effects](https://fatbobman.com/en/posts/creating-stunning-dynamic-text-effects-with-textrender/)
- [fatbobman — Mastering ScrollView Custom Paging](https://fatbobman.com/en/posts/mastering-swiftui-scrolling-implementing-custom-paging/)
- [DEV — GlassEffectContainer iOS 26](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)
- [createwithswift.com — Live Audio Waveform SwiftUI](https://www.createwithswift.com/creating-a-live-audio-waveform-in-swiftui/)
- [Medium — Scratch Card animation SwiftUI](https://medium.com/@rishixcode/card-scratching-animation-in-swiftui-d6234c1c544b)
- [AppCoda — Scratch Card Stackademic](https://blog.stackademic.com/creating-the-scratch-card-effect-in-swiftui-a08f02f59ef6)
- [Medium — Tinder swipe SwiftUI](https://medium.com/@jaredcassoutt/creating-tinder-like-swipeable-cards-in-swiftui-193fab1427b8)
- [Sarunw — Activity Ring SwiftUI](https://sarunw.com/posts/how-to-create-activity-ring-in-swiftui/)
- [DEV — Mastering Real-Time Audio Visualization Swift 6](https://dev.to/programmingcentral/mastering-real-time-audio-visualization-building-a-pro-grade-waveform-for-ai-apps-in-swift-6-1ngp)

## End of K research v18.

**Next step:** Block J/K implementation — ios-developer agent применяет existing 40+ компонентов в Features + создаёт 3 новых (HSTypewriterText, HSScratchReveal, HSCardFlip3D).
