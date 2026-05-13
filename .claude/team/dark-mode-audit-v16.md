# Dark Mode Audit v16 — HappySpeech

**Дата:** 2026-05-07
**Автор:** designer agent (Block H, Plan v16)
**Статус:** AUDIT — handoff в ios-developer для implementation

## TL;DR

- ColorTokens **архитектурно корректно** построен на named Color assets: 60+ colorset-ов в `Assets.xcassets` имеют Light + Dark варианты. Проверочный sample (`KidBg.colorset`) подтверждает: `rgb(255,248,240)` Light → `rgb(42,31,24)` Dark.
- Snapshot-инфраструктура **уже тестирует dark mode**: 11 из 13 файлов содержат `(.dark)` в `appearances` массиве (исключение — `DisplayStateTests.swift` и хелпер `SnapshotTestHelper.swift`).
- **Главная проблема:** обильное использование `Color.white` / `Color.black` / `.white` / `.black` literal-ов в фичах (142 raw occurrence) — они НЕ адаптируются к системной теме и часто рендерят белый текст на белом фоне в Light mode (или наоборот).
- Жалоба пользователя «тексты сливаются с фоном» подтверждается: в **24 фичах** найдены антипаттерны с тёмными скримами и белым текстом без проверки контекста.

---

## Section 1 — Colors that MUST be dynamic (ToFix)

### 1.1 Hardcoded `.white` foregroundStyle на gradient/material backgrounds

`.foregroundStyle(.white)` корректен **только** если фон гарантированно тёмный (AR camera, dark scrim, Brand.primary gradient). Везде где фон зависит от темы — ломается.

| Файл | Кол-во | Контекст | Риск |
|---|---|---|---|
| `Features/Demo/DemoModeView.swift` | 11 | Demo overlay, частично на Brand gradient — OK; но на `.white.opacity(0.07)` фоне — invisible в light | HIGH |
| `Features/ARZone/ARZoneViewCards.swift` | 6 | AR scene всегда тёмный — OK | LOW |
| `Features/ARZone/ARZoneViewComponents.swift` | 6 | AR scene всегда тёмный — OK | LOW |
| `Features/ARZone/ARZoneTutorialSheetView.swift` | 4 | sheet поверх AR — нужно verify | MED |
| `Features/Auth/SplashView.swift` | 4 | splash на Brand.primary gradient — OK | LOW |
| `Features/Auth/AuthSignInView.swift` | 1 | проверить фон CTA | MED |
| `Features/Auth/AuthSignUpView.swift` | 1 | проверить фон CTA | MED |
| `Features/Auth/AuthForgotPasswordView.swift` | 1 | `.background(.white.opacity(0.15), in: Circle())` — invisible в light | HIGH |
| `Features/SiblingMultiplayer/SiblingGameView.swift` | 1 | поверх dark scrim — OK | LOW |
| `Features/Customization/CustomizationViewCards.swift` | 4 | поверх customization gradient — depends | MED |
| `Features/Customization/CustomizationViewComponents.swift` | 1 | `.background(.ultraThinMaterial)` — material плюс белый текст в light = низкий контраст | HIGH |
| `Features/Customization/CustomizationView.swift` | 1 | LinearGradient — depends | MED |
| `Features/HomeTasks/HomeTasksView.swift` | 2 | activeFilter chip — белый текст на coral — OK | LOW |
| `Features/SharePlay/SharePlayView.swift` | 4 | Brand background — OK | LOW |
| `Features/SharePlay/SharePlaySessionView.swift` | 2 | `.background(.ultraThinMaterial)` + `.foregroundStyle(.white)` — провал контраста в light | HIGH |
| `Features/Settings/SettingsViewComponents.swift` | 1 | проверить фон | MED |
| `Features/Demo/DemoView.swift` | 1 | проверить фон | MED |
| `Features/StutteringModule/SoftOnset/SoftOnsetView.swift` | 2 | проверить фон CTA | MED |
| `Features/StutteringModule/Metronome/MetronomeView.swift` | 1 | проверить фон CTA | MED |

### 1.2 Hardcoded backgrounds в чёрно-белых литералах

| Файл | Строка | Проблема |
|---|---|---|
| `DesignSystem/Components/HomeScreenCard.swift` | 166 | `.background(Color.black)` в `#Preview` — preview только; OK |
| `DesignSystem/Components/HSConfettiView.swift` | — | `Color.black.ignoresSafeArea()` для preview — OK |
| `Features/Common/Stories/AnimatedStoryPlayerView.swift` | — | `Color.black` — story всегда cinematic dark, OK |
| `Features/SiblingMultiplayer/SiblingGameView.swift` | — | `Color.black.opacity(0.35)` modal scrim — semantically OK, но используй `ColorTokens.Overlay.dimmer` |
| 24 других файла | — | `.background(.black.opacity(0.x))` для AR / scrim — заменить на `ColorTokens.Overlay.*` |

### 1.3 `.foregroundColor(.gray)` без semantic

| Файл | Проблема |
|---|---|
| `DesignSystem/Components/HSSticker.swift:silverStar` | `Color.gray.opacity(0.2)` — semantic icon color, должно быть `ColorTokens.Brand.* ` или новый `ColorTokens.Reward.silver` |
| `DesignSystem/Components/ParentalGate.swift` (×2) | `Color.gray.opacity(0.2)` — preview backdrop — заменить на `ColorTokens.Parent.bgDeep` |
| `DesignSystem/Components/HSMarkdownView.swift` | manual `colorScheme` branching через `UIColor.white/black.withAlphaComponent` — допустимо, **уже корректно** учитывает тему |

### 1.4 LyalyaScene UIColor (SceneKit)

`ColorTokens.LyalyaScene.bodyUI`, `pupilUI`, `ambientUI` — **статичные UIColor**, одинаковые для Light/Dark. SceneKit рендерит на `LyalyaScene.backdropIdle` (статичный светло-сиреневый `#F3EEFF`).

**Решение:** в dark mode персонаж выглядит plastic-розовым на светлом фоне. Нужны Dark-варианты `backdropIdle` и `backdropCelebrate` (хотя бы насыщеннее) — converted в `Color(uiColor: UIColor { trait in ... })`.

---

## Section 2 — Colors that legitimately stay static

| Группа | Файл-сегмент | Обоснование |
|---|---|---|
| `Confetti.*` (14 цветов) | celebration palette | Радостные частицы должны быть яркими в обеих темах — стилистически OK |
| `Theme.*Outfit/Skin/Background` (16 пар gradients) | customization picker | Это **выбираемые декоративные** темы (наряды Ляли, фоны комнаты) — пользовательский выбор, не системный — допустимо статично |
| `Theme.hair*`, `Theme.eye*`, `Theme.tone*` | preview swatches | Демонстрация цвета волос/глаз — должна выглядеть одинаково для всех |
| `Theme.body*UI` (RealityKit) | SimpleMaterial | RealityKit материал — нужен один цвет на материал, smart dark-mode delegation done через освещение сцены |
| `Brand.*` (primary, mint, lilac, sky, butter, rose, gold) | brand identity | Бренд — Color asset (named), уже dynamic через assets |
| `Celebration.backdrop*` | preview-only backdrops | используется только в `#Preview` для отладки. **Если в production** — переместить в `Section 1` |
| `Skin.classic = Color.white` | mascot skin tint | классический белый — design intent, но проверить контраст в Dark |

---

## Section 3 — Per-screen audit findings

### Top 20 экранов с потенциальными dark-mode проблемами (по grep heuristics)

| # | Экран | Issue | Severity |
|---|---|---|---|
| 1 | `Features/Auth/AuthForgotPasswordView.swift` | `.background(.white.opacity(0.15), in: Circle())` invisible на light bg | HIGH |
| 2 | `Features/Auth/AuthSignUpView.swift` | то же `.white.opacity(0.15)` | HIGH |
| 3 | `Features/SharePlay/SharePlaySessionView.swift` | `.ultraThinMaterial` + `.foregroundStyle(.white)` без проверки темы | HIGH |
| 4 | `Features/Customization/CustomizationViewComponents.swift` | `.ultraThinMaterial` фон + white text | HIGH |
| 5 | `Features/Demo/DemoModeView.swift` | 11 `.foregroundStyle(.white)` поверх variable backgrounds | HIGH |
| 6 | `Features/ParentChild/FamilyVoiceSplitView.swift` | `.fill(Color.white.opacity(0.92))` — invisible в light | HIGH |
| 7 | `Features/SessionComplete/SessionCompleteViewComponents.swift` | `Color.black.opacity(0.45)` scrim — должно быть `ColorTokens.Overlay.dimmer` | LOW (semantic) |
| 8 | `Features/Common/CelebrationOverlayView.swift` | `Color.black.opacity(0.45)` + `.white.opacity(0.3)` | LOW (semantic) |
| 9 | `Features/Common/Stories/AnimatedStoryPlayerView.swift` | OK (cinematic dark intent) | LOW |
| 10 | `Features/Common/Spectrogram/SpectrogramVisualizerView.swift` | `.fill(Color.white.opacity(0.15))` на variable bg — нужен ColorTokens.Spec.line | MED |
| 11 | `Features/LessonPlayer/Sorting/SortingView.swift` | white.opacity(0.2) stroke на variable bg | MED |
| 12 | `Features/LessonPlayer/MinimalPairs/MinimalPairsView.swift` | tooltip `Color.black.opacity(0.75)` — статичный, OK для tooltip но семантически в Overlay | LOW |
| 13 | `Features/WorldMap/WorldMapIslandsCanvas.swift` | `Color.white` strokes на map — depends on map bg adaptation | MED |
| 14 | `Features/WorldMap/WorldMapViewComponents.swift` | `Color.white` strokeBorder | MED |
| 15 | `Features/AR/*` (8 файлов) | `.black.opacity(0.45)` chips поверх AR — OK (camera всегда live) | LOW |
| 16 | `Features/Specialist/Reports/SpecialistReportsView.swift` | `.foregroundStyle(isSelected ? Color.white : ColorTokens.Spec.ink)` — selected выглядит OK на coral, но verify | MED |
| 17 | `Features/Onboarding/OnboardingFlowViewComponents.swift` | то же pattern | MED |
| 18 | `Features/SessionHistory/SessionHistoryViewComponents.swift` | то же pattern | MED |
| 19 | `Features/HomeTasks/HomeTasksView.swift` | white/0.25 на gradient — depends | MED |
| 20 | `Features/Rewards/RewardsView.swift` + `RewardsViewComponents.swift` | `Color.white.opacity(0.25)` + `Color.black.opacity(0.55)` | MED |

### Только 3 файла используют `@Environment(\.colorScheme)` правильно

- `DesignSystem/Components/HSCard.swift`
- `DesignSystem/Components/HomeScreenCard.swift`
- `Features/ARZone/ARZoneViewComponents.swift`

Это очень мало — большинство экранов полагается **только на named Color assets**, что **должно работать**, но 142 raw black/white opacity ломают это.

---

## Section 4 — Snapshot tests gaps

### Файлы БЕЗ dark mode:

- `DisplayStateTests.swift` — не snapshot test, OK
- `SnapshotTestHelper.swift` — helper, OK

### Файлы С dark mode, но возможно не покрывают все экраны Section 3:

- `KeyScreensSnapshotTests.swift` — Light + Dark
- `OnboardingSnapshotTests.swift` — Light + Dark
- `ParentFlowSnapshotTests.swift` — Light + Dark
- `SpecialistSnapshotTests.swift` — Light + Dark
- `GameTemplatesSnapshotTests.swift` — Light + Dark
- `AdvancedGameSnapshotTests.swift` — Light + Dark
- `ARSnapshotTests.swift` — Light + Dark
- `ErrorStatesSnapshotTests.swift` — Light + Dark
- `FocusStateSnapshotTests.swift` — Light + Dark
- `AccessibilityVariantsSnapshotTests.swift` — Light + Dark
- `DynamicTypeSnapshotTests.swift` — Light + Dark
- `DesignSystemSnapshotTests.swift` — Light + Dark

### Gaps:

- **Auth flow** (SignIn, SignUp, ForgotPassword, Splash) — проверить что входит в `KeyScreensSnapshotTests` или нужен новый `AuthSnapshotTests.swift`
- **SharePlay** (SharePlayView, SharePlaySessionView) — нет dedicated теста
- **Customization** (Cards, Components, View) — нет dedicated теста
- **HomeTasks** — нет dedicated теста
- **WorldMap** — нет dedicated теста
- **SessionComplete / Rewards / CelebrationOverlay** — проверить покрытие

**Итого пропущено: 6 фич × 2 темы × ~3 ключевых state = ~36 новых snapshot test cases.**

---

## Section 5 — Recommendations для ios-developer (batch fixes)

### Priority HIGH (Sprint 12 must-fix)

1. **Заменить `Color.black.opacity(*)` modal scrims** на `ColorTokens.Overlay.dimmer` / `.dimmerHeavy` — 24 occurrences, find/replace.
2. **Заменить `Color.white.opacity(*)` glass tints** на `ColorTokens.Overlay.glass` / `.highlight` — 30+ occurrences.
3. **`AuthForgotPasswordView.swift:98`, `AuthSignUpView.swift:108`** — `.white.opacity(0.15)` поверх gradient: добавить `ColorTokens.Brand.primaryHi.opacity(0.25)` или semantic.
4. **`SharePlaySessionView.swift`, `CustomizationViewComponents.swift`** — `.ultraThinMaterial` + white text не работает в light. Заменить foreground на `ColorTokens.Kid.ink` либо явно тёмный fixed background.
5. **`FamilyVoiceSplitView.swift:Color.white.opacity(0.92)`** — заменить на `ColorTokens.Kid.surface`.

### Priority MED (Sprint 13)

6. **`HSSticker.silverStar`** — добавить `ColorTokens.Brand.silver` асset, заменить `Color.gray.opacity(0.2)`.
7. **`ParentalGate.swift`** — заменить `Color.gray.opacity(0.2)` на `ColorTokens.Parent.bgDeep` (preview backdrop).
8. **`LyalyaScene.backdropIdle/Celebrate`** — добавить Dark варианты в Assets, либо мигрировать на `Color(uiColor: UIColor { trait in ... })`.
9. **Создать `Color.dynamic(light:dark:)` extension** в `DesignSystem/Theme/` для inline cases где asset overkill.
10. **Добавить SwiftLint правило** `no_hardcoded_color_literals` — fail на `Color.white|black|gray` в `Features/`.

### Priority LOW (backlog)

11. Добавить snapshot tests для Auth / SharePlay / Customization / HomeTasks / WorldMap (~36 кейсов).
12. Добавить unit-тест: `ColorAssetIntegrityTest` который iterates все ColorTokens и проверяет наличие Light + Dark variants в Asset Catalog.
13. Документировать в `design-specs.md` правило: «**Никаких raw `Color.white|black|gray` literals в `Features/`. Только `ColorTokens.*`.**»

---

## Acceptance criteria для handoff

- [ ] Все 24 `Color.black.opacity` scrims заменены на `ColorTokens.Overlay.*`.
- [ ] Все `.foregroundStyle(.white)` поверх variable backgrounds проверены и либо justified (AR/Brand gradient), либо заменены.
- [ ] Snapshot tests для Auth + SharePlay + Customization добавлены.
- [ ] `swiftlint --strict` passes без warnings.
- [ ] Manual QA: каждый из 20 экранов Section 3 проверен в Light + Dark на iPhone 17 Pro simulator.

---

## Файлы

- ColorTokens источник: `HappySpeech/DesignSystem/Tokens/ColorTokens.swift` (444 LOC)
- Asset Catalog: `HappySpeech/Resources/Assets.xcassets/` (60+ colorsets, все с Light + Dark)
- Snapshot инфра: `HappySpeechTests/Snapshot/` (13 файлов, 11 с dark mode)
- Existing dynamic patterns: `HSCard.swift`, `HomeScreenCard.swift`, `ARZoneViewComponents.swift`, `HSMarkdownView.swift`
