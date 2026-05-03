# HappySpeech — Design Handoff v15 (2026-05-04)
# TODO для ios-developer: исправление UI аудита v15

> Приоритеты: P1 = срочно (до Sprint 12), P2 = важно (Sprint 12), P3 = желательно (Sprint 13).
> Каждый блок — атомарный коммит. Читай design-specs-v15.md перед исправлением.

---

## БЛОК P1-1: AchievementsView — неправильный фон
**Файл:** `HappySpeech/Features/Extensions/Achievements/AchievementsView.swift`
**Проблема:** `Color(.systemGroupedBackground)` — системный серый UIKit цвет. На светлой теме выглядит как серый, на тёмной — тёмно-серый. Ломает единый тёплый кремовый Design для kid-контура.

**Исправление:**
```swift
// БЫЛО:
Color(.systemGroupedBackground)
    .ignoresSafeArea()

// СТАЛО:
ColorTokens.Kid.bg
    .ignoresSafeArea()
```

**Дополнительно:**
- Если AchievementsView используется в parent-контуре (для родителей) — использовать `ColorTokens.Parent.bg`. Уточнить у PM: экран достижений — детский или родительский?
- Для Text-элементов внутри убедиться, что `foregroundStyle` использует `ColorTokens.Kid.ink` / `Kid.inkMuted`, а не `.primary` / `.secondary`

**Тест:**
1. Открыть ChildHome → QuickAction «Достижения»
2. Проверить фон в Light mode: тёплый кремовый (не серый)
3. Проверить фон в Dark mode: тёмный тёплый (не нейтрально-серый)

---

## БЛОК P1-2: BreathingTreeView — Color.brown
**Файл:** `HappySpeech/Features/StutteringModule/BreathingTreeView.swift`
**Проблема:** `Color.brown.opacity(0.6)` — системный коричневый без dark-mode адаптации. Не соответствует дизайн-токенам.

**Исправление — вариант A (предпочтительный):** Добавить токен в ColorTokens.swift:
```swift
// В ColorTokens.swift, секция Kid или добавить новый Semantic:
public enum Nature {
    /// Ствол дерева — тёплый коричневый, dark-mode-safe
    public static let treeTrunk = Color("NatureTreeTrunk")
}
```
В Assets.xcassets добавить NatureTreeTrunk.colorset:
- Light: rgb(139, 90, 43) — тёплый коричневый
- Dark: rgb(180, 130, 70) — светлее для dark mode

```swift
// В BreathingTreeView.swift:
// БЫЛО:
.fill(Color.brown.opacity(0.6))

// СТАЛО:
.fill(ColorTokens.Nature.treeTrunk)
```

**Исправление — вариант B (быстрый, без нового токена):**
```swift
// СТАЛО (использовать существующий тёплый токен):
.fill(ColorTokens.Brand.primaryLo.opacity(0.7))
// primaryLo = oklch(0.58 0.19 32) = тёмно-коралловый / ржавый
```

**Для leafColor (динамический HSB):**
Текущая реализация `Color(hue: 0.35, saturation: ..., brightness: ...)` функционально оправдана (градация зелёного по прогрессу дыхания). Допустимо ПРИ УСЛОВИИ добавления комментария:
```swift
// Design exception: dynamic leaf color based on breathing progress.
// Intentionally not using ColorTokens — progress-based interpolation
// from ColorTokens.Brand.mint (hue≈0.46) to a deeper green.
// Reviewed and approved in ui-audit-v15.md.
private var leafColor: Color {
    let progress = Double(interactor.display.treeProgress)
    return Color(
        hue: 0.35,
        saturation: 0.4 + progress * 0.4,
        brightness: 0.5 + progress * 0.3
    )
}
```

**Тест:**
1. Settings → включить Dark Mode
2. StutteringModule → BreathingTreeView → ствол должен быть видим и тёплого тона

---

## БЛОК P2-1: SoundAndFaceView — хардкод font
**Файл:** `HappySpeech/Features/AR/SoundAndFace/SoundAndFaceView.swift`
**Проблема:** `.font(.system(size: 72, weight: .bold))` — хардкод. Игнорирует TypographyTokens и Dynamic Type.

**Исправление:**
```swift
// БЫЛО:
Text(display.soundText)
    .font(.system(size: 72, weight: .bold))

// СТАЛО:
Text(display.soundText)
    .font(TypographyTokens.kidDisplay(72))
```

**Тест:** Settings → Accessibility → Larger Text → экран SoundAndFace — буква должна масштабироваться.

---

## БЛОК P2-2: ScreeningView — хардкод font в close button
**Файл:** `HappySpeech/Features/Screening/ScreeningView.swift`
**Проблема:** `.font(.system(size: 28))` в header кнопке.

**Исправление:**
```swift
// БЫЛО:
Image(systemName: "xmark.circle.fill")
    .font(.system(size: 28))

// СТАЛО:
Image(systemName: "xmark.circle.fill")
    .font(TypographyTokens.title(28))
```

**Тест:** Запустить ScreeningView → убедиться что кнопка закрытия визуально корректна.

---

## БЛОК P2-3: ButterflyCatchView — хардкод cornerRadius
**Файл:** `HappySpeech/Features/AR/ButterflyCatch/ButterflyCatchView.swift`
**Проблема:** `RoundedRectangle(cornerRadius: 12, style: .continuous)` — хардкод. RadiusTokens.sm = 12pt, но должен использоваться токен.

**Исправление:**
```swift
// БЫЛО:
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

// СТАЛО:
.clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))
```

---

## БЛОК P2-4: ChildHomeView — мелкий section header
**Файл:** `HappySpeech/Features/ChildHome/ChildHomeView.swift`
**Проблема:** Section header `sectionHeader()` использует `caption(12)` для заголовка секции. По Design секционные заголовки в kid-контуре должны быть минимум 13pt и visually prominent.

**Исправление:**
```swift
// БЫЛО:
private func sectionHeader(_ title: String, emoji: String) -> some View {
    HStack(spacing: SpacingTokens.sp2) {
        Text(emoji)
            .font(TypographyTokens.caption(14))
        Text(title)
            .font(TypographyTokens.caption(12))   // <- слишком мелко
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .textCase(.uppercase)
            .tracking(1)
        Spacer(minLength: 0)
    }
}

// СТАЛО:
private func sectionHeader(_ title: String, emoji: String) -> some View {
    HStack(spacing: SpacingTokens.sp2) {
        Text(emoji)
            .font(TypographyTokens.caption(16))
            .accessibilityHidden(true)
        Text(title)
            .font(TypographyTokens.caption(13))   // 13pt — минимум для секционных заголовков
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .textCase(.uppercase)
            .tracking(1)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
        Spacer(minLength: 0)
    }
}
```

---

## БЛОК P2-5: GuidedTourTipView — inline shadow
**Файл:** `HappySpeech/Features/GuidedTour/GuidedTourTipView.swift`
**Проблема:** `.shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)` — inline вместо токена.

**Вариант A — использовать существующий токен:**
```swift
// БЫЛО:
.shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)

// СТАЛО:
.kidCardShadow()
// ShadowTokens.Kid.card = radius:12, y:4, opacity:0.08
// Примечание: визуально чуть менее выражена, но соответствует Design System
```

**Вариант B — добавить токен ShadowTokens.Kid.tooltip:**
```swift
// В ShadowTokens.swift добавить:
public static let tooltip = ShadowStyle(
    color: Color(red: 0.23, green: 0.16, blue: 0.11),
    radius: 16,
    x: 0, y: 8,
    opacity: 0.12
)

// И View extension:
public func kidTooltipShadow() -> some View {
    modifier(ShadowModifier(style: ShadowTokens.Kid.tooltip))
}

// В GuidedTourTipView.swift:
.kidTooltipShadow()
```

---

## БЛОК P2-6: OnboardingFlowView — actionFooter inline gradient
**Файл:** `HappySpeech/Features/Onboarding/OnboardingFlowView.swift`
**Проблема:** Inline LinearGradient в actionFooter background вместо GradientTokens.

**Исправление:** В GradientTokens.swift добавить параметрический метод (см. design-specs-v15.md раздел 6).

Затем в OnboardingFlowView:
```swift
// БЫЛО:
.background(
    LinearGradient(
        colors: [gradientColors(for: display.currentStep).last?.opacity(0) ?? Color.clear,
                 gradientColors(for: display.currentStep).last ?? Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
    .ignoresSafeArea(edges: .bottom)
)

// СТАЛО (после добавления токена):
.background(
    GradientTokens.kidBottomFade(
        background: gradientColors(for: display.currentStep).last ?? ColorTokens.Kid.bg
    )
    .ignoresSafeArea(edges: .bottom)
)
```

---

## БЛОК P3-1: ChildHomeView — хардкод малые отступы
**Файл:** `HappySpeech/Features/ChildHome/ChildHomeView.swift`
**Проблема:** `padding(.horizontal, 2)` и `padding(.vertical, 4)` в quickPlay/todayWords секциях — хардкод вместо SpacingTokens.

**Исправление:**
```swift
// БЫЛО:
.padding(.horizontal, 2)
.padding(.vertical, 4)

// СТАЛО (4pt = sp1 = micro):
.padding(.horizontal, SpacingTokens.micro)  // 4pt
.padding(.vertical, SpacingTokens.micro)    // 4pt
// или .padding(SpacingTokens.micro) если оба одинаковые
```

---

## БЛОК P3-2: SplashView — семантика sp16
**Файл:** `HappySpeech/Features/Auth/SplashView.swift`
**Проблема:** `.padding(.bottom, SpacingTokens.sp16)` для loading bar. sp16 = 64pt — корректно по числу, но следует использовать семантический алиас.

**Исправление:**
```swift
// БЫЛО:
.padding(.bottom, SpacingTokens.sp16)

// СТАЛО:
.padding(.bottom, SpacingTokens.xxxLarge)  // 48pt более уместно, или sp16 остаётся если 64pt нужен
// Проверить визуально — возможно оставить как есть (sp16 = xxxLarge + 16pt)
```

---

## БЛОК ДОПОЛНИТЕЛЬНО-1: Проверить unread экраны
Следующие экраны не были полностью прочитаны в audit. Проверить вручную:

1. `Features/Common/CelebrationOverlayView.swift` — убедиться ColorTokens, нет Color.yellow/green
2. `Features/Common/LyalyaSceneView.swift` — убедиться фон не хардкод
3. `Features/Common/Stories/AnimatedStoryPlayerView.swift` — должен использовать GradientTokens.storyMagic
4. `Features/Common/Spectrogram/SpectrogramCanvasView.swift` — убедиться ColorTokens.Spec.waveform
5. `Features/Common/Spectrogram/SpectrogramVisualizerView.swift` — аналогично
6. `Features/Common/Spectrogram/StaticSpectrogramView.swift` — аналогично
7. `Features/ARZone/ARZoneTutorialSheetView.swift` — убедиться RadiusTokens / ColorTokens
8. `Features/SiblingMultiplayer/SiblingLobbyView.swift` — убедиться Kid контур

---

## БЛОК ДОПОЛНИТЕЛЬНО-2: Проверка темы AR оверлеев (технический долг)
**Все AR-экраны** (ARMirrorView, BreathingARView, ButterflyCatchView, HoldThePoseView, MimicLyalyaView, SoundAndFaceView, PoseSequenceView, ARStoryQuestView):

Текущий паттерн:
```swift
.background(.black.opacity(0.45), in: Capsule())
.background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: RadiusTokens.md))
```

Рекомендация — заменить на именованный Overlay токен:
```swift
// СТАЛО:
.background(ColorTokens.Overlay.dimmerHeavy, in: Capsule())
// ColorTokens.Overlay.dimmerHeavy = Color.black.opacity(0.65) — существует в токенах
// Или ColorTokens.Overlay.dimmer = 0.45 — ближе к текущему значению

// Для 0.40 / 0.45 → ColorTokens.Overlay.dimmer (0.45) — достаточно близко
```

Это не срочно (P3), но улучшит консистентность и упростит глобальное изменение темноты overlay.

---

## Итоговый чеклист для ios-developer

### Sprint 12 (P1 — СРОЧНО)
- [ ] P1-1: AchievementsView.swift — заменить Color(.systemGroupedBackground)
- [ ] P1-2: BreathingTreeView.swift — заменить Color.brown

### Sprint 12 (P2 — Важно)
- [ ] P2-1: SoundAndFaceView.swift — заменить .font(.system(size:72))
- [ ] P2-2: ScreeningView.swift — заменить .font(.system(size:28))
- [ ] P2-3: ButterflyCatchView.swift — заменить cornerRadius:12
- [ ] P2-4: ChildHomeView.swift — увеличить section header font
- [ ] P2-5: GuidedTourTipView.swift — заменить inline shadow
- [ ] P2-6: OnboardingFlowView.swift — вынести gradient в GradientTokens

### Sprint 13 (P3 — Желательно)
- [ ] P3-1: ChildHomeView.swift — micro-отступы 2/4pt → SpacingTokens.micro
- [ ] P3-2: SplashView.swift — sp16 → семантический алиас
- [ ] Дополнительно-1: проверить unread экраны
- [ ] Дополнительно-2: AR overlay dimmer → ColorTokens.Overlay

---

## Вносить в git коммиты по шаблону:
```
fix(ui): [экран] replace hardcoded [цвет/font/radius] with design token

- AchievementsView: Color(.systemGroupedBackground) → ColorTokens.Kid.bg
Resolves: ui-audit-v15 P1-1
```
