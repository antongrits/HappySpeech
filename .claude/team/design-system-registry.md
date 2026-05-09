# DesignSystem Registry

Реестр публичных компонентов `HappySpeech/DesignSystem/Components/`. Обновляется
при добавлении/изменении компонентов. Группы соответствуют Plan v18 Block J.

> Source language: ru (Localizable.xcstrings). Все public-API компонентов — Swift-DocC,
> русские fallback-строки, поддержка Light/Dark, Reduce Motion, VoiceOver.

---

## Group A — Foundation (10)

| # | Component | File | Notes |
|---|-----------|------|-------|
| A.1 | `HSButton` | `HSButton.swift` | 4 styles (primary/secondary/ghost/danger), 3 sizes, isLoading, icon |
| A.2 | `HSCard` | `HSCard.swift` | elevated/flat/tinted, circuit-aware shadow |
| A.3 | `HSLiquidGlassCard` | `HSLiquidGlassCard.swift` | iOS 26 `.glassEffect()` + iOS 17 fallback |
| A.4 | `HSBadge` + `HSToast` | `HSBadge.swift` | filled/outlined/success/warning/info/neutral |
| A.5 | `HSProgressBar` | `HSProgressBar.swift` | animated, accessible value |
| A.6 | `HSProgressRing` | `HSProgressRing.swift` | circular ring, % overlay |
| A.7 | `HSChart` | `HSChart.swift` | bar/line, Swift Charts wrapper |
| A.8 | `HSSegmentedPicker` | `HSSegmentedPicker.swift` | 2-4 segments, generic over `Hashable` |
| A.9 | `HSSpeechBubble` | `HSSpeechBubble.swift` | tail bubble, маскот dialogue |
| A.10 | `HSSticker` | `HSSticker.swift` | rewards stickers, animated entry |

## Group B — Domain (10)

| # | Component | File | Notes |
|---|-----------|------|-------|
| B.1 | `HSAudioWaveform` | `HSAudioWaveform.swift` | live waveform from AVAudioEngine |
| B.2 | `HSAudioRecorderView` | `HSAudioRecorderView.swift` | record button + waveform |
| B.3 | `HSConfettiView` | `HSConfettiView.swift` | confetti emitter, 3 palettes |
| B.4 | `HSRewardBurst` | `HSRewardBurst.swift` | reward animation overlay |
| B.5 | `HSContentSymbol` | `HSContentSymbol.swift` | sound family iconography |
| B.6 | `HSPictTile` | `HSPictTile.swift` | tile for sound-hunter and sorting games |
| B.7 | `HSSoundChip` | `HSSoundChip.swift` | sound family chips (С/З/Ц/Ш/Ж/Ч/Щ/Р/Л/К/Г/Х) |
| B.8 | `HSMascotView` + `LyalyaMascotView` | `LyalyaMascotView.swift` | маскот «Ляля», 10 states |
| B.9 | `HSMascotPullToRefresh` | `HSMascotPullToRefresh.swift` | pull-to-refresh с Лялей |
| **B.10** | **`HSEmptyStateView`** | **`HSEmptyStateView.swift`** | **6 variants (lessons/tasks/achievements/notifications/search/custom). SF Symbol or mascot illustration. Reduce Motion, VoiceOver combined label.** |

## Group C — Specialised (3 — добавлены v18)

| # | Component | File | Notes |
|---|-----------|------|-------|
| **C.1** | **`HSTimelineView`** | **`HSTimelineView.swift`** | **Vertical timeline для progress dashboard / истории достижений. Generic над `HSTimelineItem`. Spring entrance staggered (Reduce Motion compliant). Light/Dark via ColorTokens. ru-RU date format `d MMM`.** |
| **C.2** | **`HSStarRatingView`** | **`HSStarRatingView.swift`** | **1-5 stars rating. Display и interactive modes. Tap target ≥44pt. Haptic medium на tap (UIImpactFeedbackGenerator). VoiceOver «Оценка X из 5», в interactive — «Поставить N звёзд».** |
| **C.3** | **`HSPaywallTeaser`** | **`HSPaywallTeaser.swift`** | **Premium feature teaser, post-v1.0 monetization готовность. Lock icon + title + subtitle + disabled CTA. HSLiquidGlassCard (gold tint). GoldShimmer animation (off при Reduce Motion). iOS 17+.** |

---

## Specialty / Helpers (не входят в Group A/B/C)

| Component | Purpose |
|-----------|---------|
| `HSAnimatedTabBar` | Custom tab bar с анимациями |
| `HSCustomAlert` | Custom alert с маскотом |
| `HSErrorStateView` | Error state (parallel to EmptyState) |
| `HSGlassNavigationBar` | Liquid Glass nav bar |
| `HSHeroCardTransition` | Matched geometry transitions |
| `HSLoadingView` | Loading state с Лялей |
| `HSLottieContainer` | Lottie animation wrapper |
| `HSMarkdownView` | Markdown renderer |
| `HSMeshGradientBackground` | Mesh gradient background |
| `HSOfflineBanner` | Offline indicator |
| `HSOnboardingParallax` | Parallax onboarding cards |
| `HSScrollTransitionList` | Scroll-driven transitions |
| `HSSkeletonShimmer` | Skeleton loading |
| `HSSwipeCardStack` | Tinder-style swipe stack |
| `HomeScreenCard` | Home screen tile |
| `LyalyaHeroView`, `LyalyaRealityKitView` | 3D RealityKit маскот |
| `LyalyaLipSyncCoordinator`, `MouthBubbleOverlay` | Lip-sync с маскотом |
| `ParentalGate` | Parent-only access gate |

---

## Block J B.10 + Group C v18 — Implementation summary

**Дата:** 2026-05-09. **Автор:** antongrits.

- `HSEmptyStateView`: исходный компонент уже существовал (mascot + symbol), добавлено 6 convenience-variants как extension (`.lessons`, `.tasks`, `.achievements`, `.notifications`, `.search`, `.custom`) с русскими строками через `String(localized:defaultValue:)`.
- `HSTimelineView`: новый. Vertical timeline с node circles, generic `HSTimelineItem`, spring entrance staggered animation (delay 0.06s × index), Reduce Motion compliance.
- `HSStarRatingView`: новый. Display + interactive режимы. Tap target ≥44pt, UIImpactFeedbackGenerator medium на tap, gold-fill (`ColorTokens.Brand.gold`).
- `HSPaywallTeaser`: новый. Premium-teaser с замочком, disabled CTA в v1.0. HSLiquidGlassCard (gold tint 0.18). GoldShimmer overlay (выключается при Reduce Motion).

**BUILD:** SUCCEEDED iPhone SE (3rd generation), Debug.

**Compliance:**
- Russian-only, DocC tripple-slash comments на public API.
- Light/Dark — через ColorTokens (адаптивные ассеты).
- Reduce Motion — через `@Environment(\.accessibilityReduceMotion)`.
- VoiceOver — `.accessibilityElement(children:)` + `.accessibilityLabel`.
- `#Preview` блоки в `#if DEBUG` с light + dark вариантами.
