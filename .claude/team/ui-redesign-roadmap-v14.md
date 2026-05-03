# UI Redesign Roadmap v14 — Modern UI Consistency Audit

> Автор: designer-ui (Block EE, Plan v14)
> Дата: 2026-05-03
> Основание: пользователь сообщил, что "UI несовременный, некрасивый, экраны не в единой теме"

---

## 1. Original Design Source

**Статус: НЕ НАЙДЕНА** в стандартных местах.

Поиск по путям:
- `/Users/antongric/Yandex.Disk.localized/` — папок `claude-design*` / `happyspeech-design*` нет
- `/Users/antongric/Downloads/` — аналогично пусто

В `CLAUDE.md` упоминается путь `happyspeech-design/project/*.jsx` как "локально, не в репо", но папка не найдена. Возможно, была удалена или переименована.

**Что сохранилось от original design:**
Файл `SpacingTokens.swift` содержит комментарий: `"Переведены из дизайн-прототипа tokens.jsx"` — значит токены были переведены в код из JSX-прототипа, но сам JSX-файл не доступен.

Текущий DesignSystem покрывает основные намерения исходного дизайна:
- Brand palette: coral-apricot primary, mint success, sky info, lilac AR, butter rewards, rose warmth, gold achievements
- Kid circuit: тёплая кремовая палитра
- Parent circuit: нейтральная холодная
- Specialist circuit: аналитическая, data-dense
- Радиусы: xs=8, sm=12, md=18, lg=24, xl=32 (generous, modern)
- Spacing: 4pt grid, screenEdge=24, cardPad=20
- Типографика: SF Pro Rounded для kid, Regular SF Pro для parent/spec

---

## 2. Статистика аудита (измерено grep по 483 файлам Features/)

| Метрика | Значение | Оценка |
|---|---|---|
| Всего View-файлов | 91 | — |
| View-файлы БЕЗ ColorTokens | 8 (9%) | Красный |
| View-файлы БЕЗ TypographyTokens | 11 (12%) | Красный |
| Хардкодные `.font(.system(size:))` | 345 строк | Красный |
| Хардкодные `Color.blue/red/green/orange/purple` | 2 файла | Жёлтый |
| `Color.white` / `Color.black` (overlay, не токены) | 80 строк | Жёлтый |
| Хардкодные `LinearGradient`/`RadialGradient` | 60 строк | Жёлтый |
| Хардкодные `.cornerRadius(N)` без RadiusTokens | 5 файлов | Жёлтый |
| Хардкодные анимации без MotionTokens | 49 строк | Жёлтый |
| Нативные `Button()` без HSButton | 124 строки | Оранжевый |
| HSButton usages | 125 | Хорошо |
| HSLiquidGlassCard usages | 125 | Хорошо |
| SpacingTokens usages | 1977 | Отлично |
| TypographyTokens usages | 1105 | Хорошо |
| Hardcoded frame sizes (px values) | 303 | Нормально (многие — намеренные) |
| `.glassEffect()` / `.ultraThinMaterial` usages | 15 | Жёлтый (мало) |
| Теней без ShadowTokens | 50 строк | Жёлтый |

---

## 3. Критические несоответствия (по группам)

### 3.1 Типографика — САМАЯ СЕРЬЁЗНАЯ ПРОБЛЕМА

**345 хардкодных `.font(.system(size:))` в фичах** — это главная причина несовременного вида.

Файлы с наибольшим числом нарушений:
- `StutteringView.swift` — 8+ хардкодных размеров шрифтов (9pt, 13pt, 14pt, 16pt, 18pt, 20pt, 28pt, 48pt)
- `DemoModeView.swift` — хардкодные 16pt, 17pt, 64pt, 72pt — no rounding, no design token
- `SettingsView.swift` — 13pt, 26pt, 28pt, 13pt semibold (не rounded, не из токена)
- `ARZoneView.swift` — 9pt (слишком мелко для детей!), динамический `size * 0.5`
- `ParentHomeSubViews.swift` — `.font(.system(size: 18, weight: .black, design: .rounded))` — вместо `TypographyTokens.headline()`
- `FamilyVoiceLibraryView.swift` — 20pt, 36pt, 64pt light — нарушают rhythm
- `SiblingGameView.swift` — 32pt без `.design: .rounded`

**Последствие:** шрифты выглядят непоследовательно на разных экранах. Детский контур теряет фирменный SF Pro Rounded стиль.

### 3.2 Цвет — НЕСОВПАДЕНИЕ С DESIGN SYSTEM

8 View-файлов полностью вне ColorTokens:

- `AnimatedStoryPlayerView.swift` — хардкод `Color.blue.opacity(0.6), Color.purple.opacity(0.6)` как fallback фон — должно быть `ColorTokens.Brand.sky` / `ColorTokens.Brand.lilac`
- `StoryPlayerView.swift` — прямые `Color("BrandPrimary", bundle: nil)` вместо `ColorTokens.Brand.primary`
- `LyalyaRealityView.swift` — прямые `Color("BrandLilac")` — технически та же Asset Catalog, но не через токены
- `CelebrationOverlayView.swift` — `Color.black.opacity(0.45)` для overlay — нет семантического токена для dimmer
- `SpectrogramVisualizerView.swift` / `SpectrogramCanvasView.swift` — нет токенов вообще
- `LyalyaSceneView.swift` — `UIColor.white` для 3D lighting (специфика SceneKit, частично оправдано)

**Нехватающий токен:** отсутствует `ColorTokens.Overlay.dimmer` — во многих местах используют `Color.black.opacity(0.35–0.75)` произвольно. Нужен единый токен.

### 3.3 Градиенты — INCONSISTENCY

60 хардкодных градиентов. Самые проблемные:

- `AuthSignInView.swift`, `AuthSignUpView.swift`, `AuthForgotPasswordView.swift`, `AuthVerifyEmailView.swift` — у каждого свой `LinearGradient` с немного разными цветами. Auth-экраны должны выглядеть одинаково
- `ARZoneView.swift` — 8 разных `LinearGradient` без токенов, часто с произвольными цветами
- `GrammarGameView.swift` — свой отдельный `LinearGradient` фон не из palette
- `HomeTasks` — отдельный стиль фона
- `Onboarding` — per-step gradients (это намеренно, но цвета не из токенов)

**Нет GradientTokens** — это системная дыра. Нужен `GradientTokens.swift` с именованными фоновыми градиентами.

### 3.4 Анимации — РАСХОЖДЕНИЕ С MotionTokens

49 хардкодных анимаций:

- `ARZoneView.swift` — 4 разные inline `.easeInOut(duration: 1.2–1.6).repeatForever` — должно быть `MotionTokens.idlePulse`
- `SplashView.swift` — `.spring(response: 0.6, dampingFraction: 0.65)` — очень близко к `MotionTokens.spring` (0.45, 0.7), но другие параметры → другое ощущение
- `RewardsView.swift` — `.spring(response: 0.55, dampingFraction: 0.55)` — близко к `MotionTokens.bounce`, но не идентично
- Большинство `.easeInOut(0.25)` — можно заменить на `MotionTokens.outQuick`

### 3.5 Компоненты — НЕИСПОЛЬЗОВАНИЕ DS

124 нативных `Button()` без `HSButton` — многие оправданы (toolbar, alert, sheet dismiss), но часть — CTA-кнопки которые должны быть `HSButton`.

Файлы-кандидаты на замену:
- `BreathingView.swift` — main action button нативный
- `SortingView.swift` — игровые кнопки нативные
- `BingoView.swift` — нативные overlay кнопки
- `MinimalPairsView.swift` — caption bar нативный Button

### 3.6 Нехватает ShadowTokens

50 хардкодных `.shadow(color:radius:x:y:)` — единого ShadowTokens.swift нет. Тени произвольны:
- `.shadow(color: .black.opacity(0.08–0.35), radius: 4–20, y: 2–10)` — 6-7 разных вариантов

---

## 4. Оценка Modern Style

### Текущий Modern Style Score: 6/10

| Критерий | Score | Комментарий |
|---|---|---|
| Liquid Glass coverage | 4/10 | HSLiquidGlassCard есть и хорошо написан, но используется только в 125 местах из ~300+ карточных поверхностей |
| SF Pro Rounded consistency | 5/10 | 345 хардкодных шрифтов ломают kid-feel |
| Color token coverage | 7/10 | 83/91 View-файлов используют ColorTokens — хорошо |
| Spacing consistency | 9/10 | 1977 usages SpacingTokens — отлично |
| Animation quality | 6/10 | MotionTokens есть, но 49 inline overrides |
| Component system usage | 7/10 | HSButton используется широко |
| Gradient system | 3/10 | 60 хардкодных, нет GradientTokens |
| Shadow system | 4/10 | Нет ShadowTokens |
| Modern iOS 26 patterns | 5/10 | glassEffect есть но не везде нужно |
| Dark mode consistency | 7/10 | Asset Catalog цвета адаптируются автоматически |

**Target Modern Style Score: 9/10**

---

## 5. Action Items P0 — Блокируют качественный вид (критично)

### P0-1: GradientTokens.swift — создать
Сейчас 60 inline градиентов. Нужен файл с именованными градиентами:

```swift
public enum GradientTokens {
    // Backgrounds
    public static let kidHero = LinearGradient(colors: [ColorTokens.Brand.primary, ColorTokens.Brand.primaryHi], ...)
    public static let authBackground = LinearGradient(colors: [ColorTokens.Kid.bg, ColorTokens.Kid.bgDeep], ...)
    public static let arScene = LinearGradient(colors: [ColorTokens.Brand.lilac, ColorTokens.Brand.sky], ...)
    public static let rewardBurst = LinearGradient(colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold], ...)
    public static let specBackground = LinearGradient(colors: [ColorTokens.Spec.bg, ColorTokens.Spec.bgDeep??], ...)
    // Overlays
    public static let dimmer = Color.black.opacity(0.45)
    public static let dimmerLight = Color.black.opacity(0.25)
}
```

Усилие: 2ч. Файл: `HappySpeech/DesignSystem/Tokens/GradientTokens.swift`

### P0-2: ShadowTokens.swift — создать
Уже был упомянут в системных инструкциях как нужный. 50 хардкодных теней.

```swift
public enum ShadowTokens {
    public static let card = ShadowStyle(color: .black.opacity(0.08), radius: 12, y: 4)
    public static let elevated = ShadowStyle(color: .black.opacity(0.15), radius: 20, y: 10)
    public static let button = ShadowStyle(color: ColorTokens.Brand.primary.opacity(0.25), radius: 8, y: 4)
    public static let none = ShadowStyle(color: .clear, radius: 0, y: 0)
}
```

Усилие: 2ч. Файл: `HappySpeech/DesignSystem/Tokens/ShadowTokens.swift`

### P0-3: Auth-экраны — унифицировать градиенты
4 auth-экрана (`SignIn`, `SignUp`, `ForgotPassword`, `VerifyEmail`) должны иметь **одинаковый** background gradient. Сейчас у каждого свой.

Решение: все 4 экрана используют `GradientTokens.authBackground` (после создания P0-1).

Усилие: 1ч (после P0-1).

### P0-4: AnimatedStoryPlayerView — убрать Color.blue/Color.purple fallback
Строка 172: `[Color.blue.opacity(0.6), Color.purple.opacity(0.6)]` — это полностью нарушает брендовую палитру при отсутствии `backgroundColors`. Заменить на `[ColorTokens.Brand.sky.opacity(0.6), ColorTokens.Brand.lilac.opacity(0.6)]`.

Усилие: 15 минут.

---

## 6. Action Items P1 — Видимые качественные проблемы

### P1-1: Типографика в StutteringView — привести к токенам
8+ хардкодных шрифтов. Самый видимый дефект в StutteringModule.

Маппинг замен:
- `.font(.system(size: 48))` → `TypographyTokens.kidDisplay(48)`
- `.font(.system(size: 28, weight: .semibold))` → `TypographyTokens.title(28)`
- `.font(.system(size: 20))` → `TypographyTokens.headline()`
- `.font(.system(size: 16))` → `TypographyTokens.body(16)`
- `.font(.system(size: 14, weight: .semibold))` → `TypographyTokens.caption(14)` или добавить `subheadline()` токен
- `.font(.system(size: 13))` → `TypographyTokens.caption()`

Усилие: 1ч.

### P1-2: SettingsView — типографика
6+ хардкодных шрифтов. Settings — часто используемый экран родителей и специалистов.

Усилие: 1ч.

### P1-3: DemoModeView — рефакторинг типографики и цветов
`.font(.system(size: 64, weight: .bold))`, `.font(.system(size: 72))` — большие размеры без rounded дизайна.
Нужен `TypographyTokens.kidDisplay(64)` / `TypographyTokens.kidDisplay(72)`.

Усилие: 45 мин.

### P1-4: ARZoneView — 8 inline LinearGradient заменить токенами
Самый сложный P1. ARZoneView большой (1000+ строк), но gradient inconsistency сильно заметна при использовании AR.

Усилие: 2ч.

### P1-5: RhythmView — `Color.green` → `ColorTokens.Semantic.success`
Одна строка: `.stroke(wasHit ? Color.green : .clear, lineWidth: 3)`.
Нужно: `.stroke(wasHit ? ColorTokens.Semantic.success : .clear, lineWidth: 3)`.

Усилие: 5 минут.

### P1-6: SpectrogramVisualizerView — добавить ColorTokens
Полностью без токенов. Использует `Color.white.opacity(0.15)` для waveform bars — должно быть `ColorTokens.Spec.waveform` (токен уже есть!).

Усилие: 30 мин.

### P1-7: Добавить `ColorTokens.Overlay.dimmer` и унифицировать overlay-затемнения
Сейчас 15+ мест с `Color.black.opacity(0.35–0.75)` — все разные. Нужен единый токен:
- `ColorTokens.Overlay.dimmer` = `Color.black.opacity(0.45)` — стандартный overlay
- `ColorTokens.Overlay.dimmerLight` = `Color.black.opacity(0.25)` — лёгкий overlay
- `ColorTokens.Overlay.dimmerHeavy` = `Color.black.opacity(0.65)` — сильный для video player

Добавить в `ColorTokens.swift` новый namespace `Overlay`.

Усилие: 30 мин (добавить токены) + 1ч (применить во всех файлах).

---

## 7. Action Items P2 — Полировка

### P2-1: GrammarGameView и SiblingMultiplayerView — добавить TypographyTokens
Оба файла без TypographyTokens. Не критично, но заметно при A/B сравнении.

Усилие: 1ч.

### P2-2: Inline spring/bounce animations → MotionTokens
49 inline анимаций. Большинство — `easeInOut(0.25)`, легко заменить на `MotionTokens.outQuick`.

Наиболее ощутимые замены:
- `ARZoneView.swift` — 4 repeatForever → `MotionTokens.idlePulse`
- `SplashView.swift` — `.spring(response: 0.6, dampingFraction: 0.65)` — проверить разницу с `MotionTokens.spring` и привести
- `RewardsView.swift` — `.spring(response: 0.55, dampingFraction: 0.55)` → `MotionTokens.bounce`

Усилие: 2ч.

### P2-3: cornerRadius(6) / cornerRadius(3) / cornerRadius(4) → RadiusTokens.chip (8)
5 файлов с хардкодными маленькими радиусами (3, 4, 6pt). Радиус 3pt — слишком острый для детского приложения. Минимальный по дизайну — `RadiusTokens.xs` = 8pt.

Файлы:
- `ParentHomeSubViews.swift` — `.cornerRadius(6)` → `.cornerRadius(RadiusTokens.chip)`
- `ProgressDashboardView.swift` — `.cornerRadius(6)` → `.cornerRadius(RadiusTokens.chip)`
- `ComparisonDashboardView.swift` — `.cornerRadius(3)` → `.cornerRadius(RadiusTokens.xs)`
- `FamilyCalendarView.swift` — `.cornerRadius(3)` → `.cornerRadius(RadiusTokens.xs)`
- `AchievementsView.swift` — `.cornerRadius(4)` → `.cornerRadius(RadiusTokens.chip)`

Усилие: 30 мин.

### P2-4: HSLiquidGlassCard — расширить применение
Сейчас 125 usages — хорошо, но на некоторых экранах ещё используют `.background(Material.ultraThinMaterial)` напрямую (15 мест).

Кандидаты на замену на `HSLiquidGlassCard`:
- Некоторые sheet-контент блоки в ARZone
- NarrativeQuestView — narrative card должна быть glass
- MinimalPairsView — caption bar

Усилие: 2ч.

### P2-5: Добавить `.design: .rounded` к шрифтам в детском контуре
Некоторые хардкодные шрифты в kid-экранах используют `weight: .semibold` без `.design: .rounded`. Это нарушает детский feel.

Например, `ParentHomeSubViews.swift` строка 61: `.font(.system(size: 18, weight: .black, design: .rounded))` — уже верно. Но `ARZoneTutorialSheetView.swift` строка 94: `.font(.system(size: 52, weight: .semibold))` — нет .rounded.

Усилие: 1ч (вместе с другими font-рефакторингами).

---

## 8. Modern iOS 26 Recommendations

### 8.1 Liquid Glass — использовать агрессивнее

`HSLiquidGlassCard` уже готов с нативным `.glassEffect()` на iOS 26. Но многие фоны используют сплошные цвета (`ColorTokens.Kid.bg`) вместо glass поверхностей.

Рекомендации:
- **ChildHome mascot zone** — сделать glass-карточку поверх градиентного фона
- **SessionShell progress header** — glass header вместо сплошного фона
- **WorldMap legend** — glass overlay поверх карты
- **RepeatAfterModel listening card** — glass card с `.tinted(ColorTokens.Brand.primary.opacity(0.15))`

### 8.2 PhaseAnimator и KeyframeAnimator (iOS 17+)

Несколько мест используют ручные `@State` + `onAppear` + `withAnimation` chains для многошаговых анимаций (SplashView, CelebrationOverlay). Можно заменить на `PhaseAnimator` для более чистого кода и лучшей производительности.

### 8.3 ScrollView contentMargins (iOS 17+)

Некоторые ScrollView используют `.padding(.horizontal, SpacingTokens.screenEdge)` на content. Правильнее: `.contentMargins(.horizontal, SpacingTokens.screenEdge)` — тогда scrollbar правильно позиционируется.

### 8.4 symbolEffect для SF Symbols (iOS 17+)

Несколько иконок в ChildHome и SessionShell используют `withAnimation` для смены иконки. Заменить на `.symbolEffect(.bounce)` / `.symbolEffect(.variableColor)` — нативнее и красивее.

### 8.5 Mesh Gradient (iOS 18+)

Детский background сейчас — `LinearGradient` из 2 точек. iOS 18 привнёс `MeshGradient` — органичный многоточечный градиент, который выглядит современно и тепло.

```swift
// Пример для KidBackground
MeshGradient(width: 3, height: 3, points: [...], colors: [
    ColorTokens.Kid.bgSofter, ColorTokens.Brand.rose.opacity(0.3), ColorTokens.Kid.bg,
    ColorTokens.Brand.butter.opacity(0.2), ColorTokens.Kid.bgSoft, ...
])
```

Усилие: 4ч. Визуальный эффект: значительный.

---

## 9. Качество визуальных ассетов (без кода)

### 9.1 Существующие иллюстрации (154 шт)
Пользователь сказал "картинки некрасивые". Без просмотра конкретных файлов предположительные причины:
- Иллюстрации могут быть сгенерированы через разные AI-модели в разное время → inconsistent style
- Нет единого стиля: flat vs outline vs 3D vs cartoon смешаны
- Рекомендация: аудит 10-15 ключевых иллюстраций вручную

### 9.2 Lottie анимации (58 шт)
Причины "некрасивости" Lottie:
- Возможно, часть загружена с LottieFiles в generic стиле, не подходящем к детскому бренду
- Отсутствие брендовой цветовой обработки (Lottie поддерживает Dynamic Properties)
- Рекомендация: применить `HSLottieContainer` с `colorValueProvider` для перекраски generic анимаций в Brand.primary/mint

### 9.3 Видео (100 MP4)
Причины "некрасивости" видео:
- Возможно, placeholder-видео или AI-сгенерированные с artефактами
- Отсутствие единого визуального стиля (фон, персонажи)
- Рекомендация: добавить loading placeholder из Lottie пока видео загружается + thumbnail preview

### 9.4 Маскот «Ляля» 3D
`LyalyaSceneView.swift` и `LyalyaRealityView.swift` — 3D маскот через SceneKit/RealityKit. Возможные проблемы:
- Освещение: `UIColor.white` ambient — плоское, нет глубины
- Нет subsurface scattering для мягкого детского вида
- Рекомендация: добавить тёплый `omniLight` с `color = UIColor(hue: 0.1, saturation: 0.3, brightness: 1.0)` (тёплый белый)

---

## 10. Список экранов с статусом consistency

| Экран | ColorTokens | Typography | Gradients | Animation | Оценка |
|---|---|---|---|---|---|
| SplashView | ✅ | ⚠️ (1 hardcoded) | ⚠️ (inline) | ⚠️ (inline spring) | 7/10 |
| AuthSignInView | ✅ | ✅ | ⚠️ (inline gradient) | ✅ | 8/10 |
| AuthSignUpView | ✅ | ✅ | ⚠️ (inline gradient) | ✅ | 8/10 |
| RoleSelectView | ✅ | ✅ | ✅ | ✅ | 10/10 |
| OnboardingFlowView | ✅ | ✅ | ⚠️ (step gradients inline) | ✅ | 8/10 |
| ChildHomeView | ✅ | ✅ | ✅ | ✅ | 9/10 |
| ParentHomeView | ✅ | ✅ | ✅ | ✅ | 9/10 |
| SpecialistHomeView | ✅ | ✅ | ✅ | ✅ | 9/10 |
| WorldMapView | ✅ | ✅ | ⚠️ | ✅ | 8/10 |
| SessionShellView | ✅ | ✅ | ✅ | ✅ | 9/10 |
| RepeatAfterModelView | ✅ | ✅ | ✅ | ✅ | 9/10 |
| ListenAndChooseView | ✅ | ✅ | ✅ | ✅ | 9/10 |
| DragAndMatchView | ✅ | ✅ | ⚠️ | ✅ | 8/10 |
| SortingView | ✅ | ✅ | ⚠️ | ✅ | 8/10 |
| BingoView | ✅ | ✅ | ⚠️ | ✅ | 8/10 |
| BreathingView | ✅ | ✅ | ⚠️ | ⚠️ | 7/10 |
| RhythmView | ✅ | ✅ | ✅ | ⚠️ | 8/10 |
| MinimalPairsView | ✅ | ✅ | ⚠️ | ✅ | 8/10 |
| NarrativeQuestView | ✅ | ✅ | ⚠️ | ⚠️ | 7/10 |
| GrammarGameView | ✅ | ❌ (нет токенов) | ⚠️ | ✅ | 6/10 |
| ARZoneView | ✅ | ⚠️ | ❌ (8 inline) | ❌ (4 inline pulse) | 4/10 |
| ARMirrorView | ✅ | ✅ | ⚠️ | ✅ | 8/10 |
| AnimatedStoryPlayerView | ❌ (Color.blue!) | ❌ | ⚠️ | ⚠️ | 3/10 |
| StoryPlayerView | ❌ | ✅ | ⚠️ | ✅ | 5/10 |
| CelebrationOverlayView | ❌ | ✅ | ⚠️ | ✅ | 6/10 |
| SessionCompleteView | ✅ | ✅ | ⚠️ | ⚠️ | 7/10 |
| RewardsView | ✅ | ✅ | ✅ | ⚠️ | 8/10 |
| AchievementsView | ✅ | ✅ | ✅ | ✅ | 9/10 |
| ProgressDashboardView | ✅ | ✅ | ✅ | ✅ | 8/10 |
| SettingsView | ✅ | ❌ (6+ hardcoded) | ✅ | ⚠️ | 6/10 |
| StutteringView | ✅ | ❌ (8+ hardcoded) | ✅ | ⚠️ | 5/10 |
| SpectrogramVisualizerView | ❌ | ❌ | — | — | 2/10 |
| LyalyaSceneView | ❌ | — | — | — | 3/10 (SceneKit) |
| SiblingGameView | ✅ | ⚠️ | ⚠️ | ⚠️ | 6/10 |
| FamilyCalendarView | ✅ | ✅ | ✅ | ⚠️ | 7/10 |
| PermissionFlowView | ✅ | ✅ | ✅ | ⚠️ | 8/10 |
| DemoModeView | ✅ | ❌ (5+ hardcoded) | ⚠️ | ✅ | 5/10 |

**Экранов ≥8/10:** ~22 из 37 проверенных = **59% соответствия**
**Target:** 90%+ экранов ≥8/10

---

## 11. Effort Estimate

### Quick Wins (≤2ч каждый, total ~8ч)
- P0-4: AnimatedStoryPlayerView Color.blue fix — 15 мин
- P1-5: RhythmView Color.green → semantic — 5 мин
- P2-3: cornerRadius (5 файлов) — 30 мин
- P0-1: GradientTokens.swift создать — 2ч
- P0-2: ShadowTokens.swift создать — 2ч
- P1-7: ColorTokens.Overlay namespace — 30 мин

### Medium (4–8ч, total ~14ч)
- P0-3: Auth экраны унифицировать градиенты — 1ч
- P1-1: StutteringView типографика — 1ч
- P1-2: SettingsView типографика — 1ч
- P1-3: DemoModeView рефакторинг — 45 мин
- P1-6: SpectrogramVisualizerView — 30 мин
- P2-2: Inline animations → MotionTokens — 2ч
- P2-4: Расширить HSLiquidGlassCard — 2ч
- P2-5: .rounded на шрифты в kid contexts — 1ч

### Large (8–16ч, total ~20ч)
- P1-4: ARZoneView полный рефакторинг градиентов и анимаций — 4ч
- MeshGradient для KidBackground — 4ч
- GrammarGameView, SiblingMultiplayerView полный token-audit — 2ч
- PhaseAnimator рефакторинг SplashView, CelebrationOverlay — 3ч
- symbolEffect добавить на SF Symbol transitions — 2ч

**TOTAL ESTIMATED EFFORT: ~42 часа**

---

## 12. Рекомендуемый порядок работы

**Sprint 13 приоритеты:**
1. Создать GradientTokens.swift + ShadowTokens.swift + ColorTokens.Overlay (P0-1, P0-2, P1-7) — 1 день
2. Унифицировать Auth-экраны (P0-3) — 2ч
3. Fix AnimatedStoryPlayerView Color.blue (P0-4) и RhythmView (P1-5) — 20 мин
4. Typography audit для StutteringView, SettingsView, DemoModeView (P1-1, P1-2, P1-3) — 3ч
5. ARZoneView рефакторинг (P1-4) — отдельный PR
6. MeshGradient KidBackground (P2, iOS 18) — если есть время

---

## 13. Нехватающие DesignSystem файлы

Нужно создать:
1. `HappySpeech/DesignSystem/Tokens/GradientTokens.swift` — именованные градиенты
2. `HappySpeech/DesignSystem/Tokens/ShadowTokens.swift` — именованные тени
3. Добавить `ColorTokens.Overlay` namespace в `ColorTokens.swift`

Опционально:
4. `HappySpeech/DesignSystem/Tokens/ElevationTokens.swift` — Z-levels (card vs sheet vs modal)

---

*Аудит выполнен автоматически + ручным просмотром ключевых файлов. Поиск по 483 Swift файлам Features/.*
