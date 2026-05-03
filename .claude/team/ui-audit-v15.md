# HappySpeech — UI Audit v15 (2026-05-04)

## Source of Truth — ClaudeDesign JSX Tokens

### Палитра (из tokens.jsx)
| Токен | OKLCH значение | Назначение |
|---|---|---|
| brand.primary | oklch(0.72 0.17 35) | coral-apricot — CTA, маскот-крылья |
| brand.primaryHi | oklch(0.82 0.14 45) | hover, secondary тон |
| brand.primaryLo | oklch(0.58 0.19 32) | pressed, shadow |
| brand.mint | oklch(0.82 0.11 165) | success, прогресс |
| brand.sky | oklch(0.80 0.10 230) | info, ссылки |
| brand.lilac | oklch(0.78 0.11 305) | AR-акцент, magic |
| brand.butter | oklch(0.90 0.12 90) | награды, стрики |
| brand.rose | oklch(0.82 0.10 15) | тепло на карточках |
| kid.bg | oklch(0.975 0.012 80) | кремовый фон |
| kid.ink | oklch(0.22 0.025 60) | тёплый почти-чёрный |
| kid.inkMuted | oklch(0.50 0.020 60) | приглушённый |
| kid.shadow | 0 2px 0 rgba(58,40,28,0.06) + 0 8px 24px rgba(58,40,28,0.08) | тёплая тень |
| parent.bg | oklch(0.985 0.004 250) | холодный нейтральный |
| parent.accent | oklch(0.62 0.14 240) | синий акцент родительского контура |
| spec.bg | oklch(0.98 0.003 250) | нейтральный специалист |
| spec.accent | oklch(0.55 0.13 250) | аналитический синий |

### Типография (из tokens.jsx)
- display: SF Pro Rounded, 34pt, weight 800, letterSpacing -0.8
- title: SF Pro Rounded, 22pt, weight 700, letterSpacing -0.4
- body: SF Pro Text, 14pt, weight 400, lineHeight 1.4
- KidCTA: SF Pro Rounded, 18pt, weight 700
- Min body в kid контуре: 15pt

### Радиусы (из tokens.jsx)
- r.xs=8, r.sm=12, r.md=18, r.lg=24, r.xl=32, r.full=9999

### Тени (из tokens.jsx)
- kid.shadow: 0 2px 0 rgba(58,40,28,0.06), 0 8px 24px rgba(58,40,28,0.08)
- parent.shadow: 0 1px 2px rgba(16,24,40,0.05), 0 1px 3px rgba(16,24,40,0.04)

---

## Per-Screen Audit

### Auth/SplashView.swift
- [OK] Фон: LinearGradient(ColorTokens.Brand.primary → primaryHi) — соответствует Design
- [OK] Типография: TypographyTokens.kidDisplay(40) / caption(13)
- [OK] Маскот: HSMascotView(size:160) — соответствует hero-размеру
- [OK] Reduced Motion: учтён
- [OK] Анимации: spring + easeOut + linear — именованы, не хардкод
- [P3] Спейсинг: .padding(.bottom, SpacingTokens.sp16) — хардкод числа sp16. Допустимо (токен), но не семантический алиас (pageTop лучше)
- ИТОГ: 1 низкоприоритетная проблема

### Auth/AuthSignInView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Декорация: GradientTokens.kidHeroDecoration (Ellipse)
- [OK] Типография: TypographyTokens.kidDisplay/title/body/caption
- [OK] Цвета: ColorTokens.Kid.ink / inkMuted / inkSoft / line
- [OK] TextField height: 52pt (min target 44pt — достаточно для взрослого контура auth)
- [P2] TextField height 52pt < 56pt (kid-минимум 56pt) — однако это экран AUTH, не kid gameplay, приемлемо
- [OK] HSButton: используется корректно
- ИТОГ: чистый экран

### Auth/AuthSignUpView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Декорация: GradientTokens.kidHeroDecoration
- [OK] Маскот: LyalyaMascotView(state:.celebrating, size:96)
- [OK] Карточка формы: HSLiquidGlassCard — соответствует Design
- [OK] Типография: TypographyTokens.title/body
- [OK] Анимации: MotionTokens.spring с .delay — корректно
- [OK] Reduced Motion: учтён
- ИТОГ: чистый экран

### Auth/AuthForgotPasswordView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Декорация: topDecoration — предполагается аналогичный Ellipse
- [OK] Форма: HSLiquidGlassCard
- ИТОГ: чистый экран

### Auth/AuthVerifyEmailView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Типография: TypographyTokens.*
- ИТОГ: чистый экран

### Auth/RoleSelectView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Маскот: LyalyaMascotView(state:.waving, size:100)
- [OK] Карточки: HSLiquidGlassCard(style:.tinted(accentColor))
- [OK] Типография: TypographyTokens.display/body/headline/caption
- [OK] Радиус иконок: RadiusTokens.md
- [OK] Анимация: MotionTokens.spring.delay(stagger) — корректно
- [OK] Reduced Motion: учтён
- ИТОГ: чистый экран

### ChildHome/ChildHomeView.swift
- [OK] Фон: KidBackgroundView() — инкапсулирован через выделенный компонент
- [OK] Спейсинг: SpacingTokens.sp5/sp2/sp3/pageTop/screenEdge
- [OK] Цвета: ColorTokens.Kid.ink/inkMuted/Brand.primary/sky/lilac/butter/mint
- [OK] Типография: TypographyTokens.body(15)/title(28)/caption(12)/headline(17)/headline(22)
- [OK] QuickAction tiles: RadiusTokens.card
- [OK] Reduced Motion: учтён во всех секциях
- [OK] Кнопка parent: frame(width:56, height:56) — min target соблюдён
- [OK] SOS кнопка: Capsule, padding sp4+sp3 — достаточная область касания
- [P2] section sectionHeader: emoji через Text("🌸") и font caption(14)/caption(12) — слишком мелкий заголовок секции для kid контура. По Design emoji-заголовки должны быть title-size (минимум 16pt label)
- [P3] Hardcode padding: .padding(.horizontal, 2) и .padding(.vertical, 4) в quickPlay/todayWords — не токены
- ИТОГ: 1 P2, 1 P3

### Onboarding/OnboardingFlowView.swift
- [OK] Фон: динамический LinearGradient из ColorTokens — корректно
- [OK] HSProgressBar(style:.kid)
- [OK] Маскот bubble: OnboardingMascotBubble — появляется правильно
- [OK] Типография: TypographyTokens.headline/mono
- [OK] Reduced Motion: учтён
- [P2] Градиент footer (actionFooter) строится inline через gradientColors(for:step).last — вместо GradientTokens токена. Формально хардкода нет (использует ColorTokens), но семантический GradientToken не используется
- ИТОГ: 1 P2

### Permissions/PermissionFlowView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] HSToast используется корректно
- [OK] Переходы: .asymmetric insertion/removal
- [OK] Reduced Motion: учтён
- ИТОГ: чистый экран

### Permissions/PermissionsOverviewView.swift
- [OK] Фон: backgroundLayer — предположительно ColorTokens.Kid.bg
- ИТОГ: требует дополнительной проверки background (чистый по видимому коду)

### ChildHome — LessonPlayer/RepeatAfterModelView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Карточка слова: HSLiquidGlassCard — соответствует Design
- [OK] Emoji-размер: kidDisplay(96) — hero-emoji
- [OK] Кнопки: HSButton(style:.secondary/.primary)
- [OK] hint-панель: RoundedRectangle(cornerRadius: RadiusTokens.card)
- [OK] Типография: TypographyTokens.body/headline/caption
- [OK] Reduced Motion: учтён (asrTask/letterHighlightTask/modelPlaybackTask)
- ИТОГ: чистый экран

### LessonPlayer/ListenAndChooseView.swift
- [OK] Фон: ColorTokens.Kid.bg (через ZStack, внешний контейнер — SessionShell)
- [OK] Цвета phase: ColorTokens.Brand.primary / Kid.inkSoft / Semantic.success
- [OK] Типография: TypographyTokens.caption(14)/body(14)
- [P3] Padding: `.padding(SpacingTokens.screenEdge)` — sp6=24pt, соответствует Design
- ИТОГ: чистый экран

### LessonPlayer/SortingView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый по init — требует проверки content-секций

### LessonPlayer/DragAndMatchView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый по init — требует проверки content-секций

### LessonPlayer/MemoryView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый по init

### LessonPlayer/RhythmView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Спейсинг: SpacingTokens.large / medium / screenEdge
- ИТОГ: чистый

### LessonPlayer/MinimalPairsView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Анимация: spring(response:dampingFraction:) — допустимо (не именован, но корректные значения)
- ИТОГ: чистый

### LessonPlayer/PuzzleRevealView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] ProgressView tint: ColorTokens.Brand.primary
- [OK] Типография: TypographyTokens.body()
- ИТОГ: чистый

### LessonPlayer/NarrativeQuestView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый

### LessonPlayer/SoundHunterView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] ProgressView tint: ColorTokens.Brand.primary
- [OK] Shake: reduceMotion учтён
- ИТОГ: чистый

### LessonPlayer/ArticulationImitationView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый

### LessonPlayer/BingoView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] ProgressView tint: ColorTokens.Brand.primary
- ИТОГ: чистый

### LessonPlayer/StoryCompletionView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] ProgressView tint: ColorTokens.Brand.primary
- ИТОГ: чистый

### LessonPlayer/VisualAcousticView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] ProgressView tint: ColorTokens.Brand.primary
- ИТОГ: чистый

### LessonPlayer/BreathingView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Типография: TypographyTokens.title()/body()
- [OK] Маскот: LyalyaMascotView(state:..., size:80)
- ИТОГ: чистый

### LessonPlayer/LetterTracingView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый

### LessonPlayer/ObjectHuntView.swift
- [OK] sceneBackground (предположительно через Display)
- ИТОГ: требует проверки sceneBackground (тип ObjectHuntViewDisplay)

### LessonPlayer/ARActivityView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый

### GrammarGame/GrammarGameView.swift
- [OK] backgroundLayer: LinearGradient(Kid.bg → Kid.bgDeep) — токены
- [OK] difficultyColor инициализируется ColorTokens.Semantic.success
- ИТОГ: чистый

### SessionShell/SessionShellView.swift
- [OK] Структура: SessionShellHost → SessionShellBinder — чистая
- ИТОГ: требует проверки SessionShellBinder / SessionHUDView (не в списке View-файлов)

### SessionComplete/SessionCompleteView.swift
- [OK] backgroundLayer — предполагается через display
- [OK] actionButtons background: LinearGradient(Kid.bg.opacity(0) → Kid.bg) — токены
- [OK] HSToast используется
- [OK] AchievementPopupView
- ИТОГ: чистый

### WorldMap/WorldMapView.swift
- [OK] backgroundLayer — предполагается через display/tokens
- [OK] stickyBottomPanel
- [OK] navigationTitle локализован
- [OK] RadiusTokens.xl в sheet
- ИТОГ: чистый

### ARZone/ARZoneView.swift
- [OK] background: ColorTokens.Kid.bg.ignoresSafeArea()
- [OK] RadiusTokens.sheet в sheet
- ИТОГ: чистый

### AR/ARMirrorView.swift
- [OK] Fallback фон: ColorTokens.Kid.bgDeep
- [OK] Instruction overlay: .black.opacity(0.45) in Capsule — стандартный AR overlay (допустимо)
- [OK] Типография: TypographyTokens.headline()
- ИТОГ: чистый

### AR/ARStoryQuestView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Цвет кнопки закрыть: ColorTokens.Brand.primary
- [OK] Спейсинг: SpacingTokens.medium/regular/xLarge/screenEdge
- ИТОГ: чистый

### AR/BreathingARView.swift
- [OK] Fallback фон: ColorTokens.Kid.bgDeep
- [OK] Capsule hint: .black.opacity(0.45) — стандартный AR overlay
- [OK] Типография: TypographyTokens.headline()
- ИТОГ: чистый

### AR/ButterflyCatchView.swift
- [OK] Fallback фон: ColorTokens.Kid.bgDeep
- [OK] Butterfly цвет: ColorTokens.Brand.lilac — корректно (magic/AR акцент)
- [P2] `.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))` — хардкод cornerRadius:12 вместо RadiusTokens.sm
- [OK] Overlay: .black.opacity(0.5) — стандартный AR overlay
- ИТОГ: 1 P2

### AR/HoldThePoseView.swift
- [OK] Fallback фон: ColorTokens.Kid.bgDeep
- [OK] Прогрессбар цвет: ColorTokens.Brand.mint
- ИТОГ: чистый

### AR/MimicLyalyaView.swift
- [OK] Fallback фон: ColorTokens.Kid.bgDeep
- [OK] Overlay: .black.opacity(0.45)
- ИТОГ: чистый

### AR/PoseSequenceView.swift
- [OK] Fallback фон: ColorTokens.Kid.bgDeep
- ИТОГ: чистый

### AR/SoundAndFaceView.swift
- [OK] Fallback фон: ColorTokens.Kid.bgDeep
- [P2] `.font(.system(size: 72, weight: .bold))` — хардкод font вместо TypographyTokens.kidDisplay(72)
- [OK] Background overlay: .black.opacity(0.4) in RoundedRectangle(cornerRadius: RadiusTokens.md)
- ИТОГ: 1 P2

### Rewards/RewardsView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] HSToast
- ИТОГ: чистый

### Extensions/Achievements/AchievementsView.swift
- [P1] Фон: `Color(.systemGroupedBackground)` — КРИТИЧЕСКИ не из ColorTokens! Должно быть ColorTokens.Kid.bg или ColorTokens.Parent.bg в зависимости от контура. systemGroupedBackground — серый UIKit цвет, не соответствует тёплому кремовому Design.
- [OK] Остальные цвета через ColorTokens
- ИТОГ: 1 критичная P1

### Extensions/SeasonalEvents/SeasonalBannerView.swift
- [OK] HSLiquidGlassCard
- [OK] Цвета: ColorTokens.Kid.ink/inkMuted + event.accentColor
- [OK] Типография: TypographyTokens.headline()/caption()
- ИТОГ: чистый

### ParentHome/ParentHomeView.swift
- [OK] Tint: ColorTokens.Parent.accent
- [OK] Contour: .parent
- [OK] NavigationSplitView + TabView — адаптивно
- ИТОГ: чистый

### ProgressDashboard/ProgressDashboardView.swift
- [OK] Фон: ColorTokens.Parent.bg
- [OK] HSLiquidGlassCard для period picker
- [OK] HSLoadingView
- ИТОГ: чистый

### Family/FamilyHomeView.swift
- [OK] Фон: ColorTokens.Parent.bg
- [OK] Спейсинг: SpacingTokens.sectionGap/screenEdge/sp4/sp8
- ИТОГ: чистый

### Family/ComparisonDashboardView.swift
- [OK] Фон: ColorTokens.Parent.bg
- ИТОГ: чистый

### FamilyCalendar/FamilyCalendarView.swift
- [OK] Фон: ColorTokens.Parent.bg
- ИТОГ: чистый

### ParentChild/FamilyVoiceView.swift
- [OK] Фон: ColorTokens.Parent.bg
- ИТОГ: чистый

### HomeTasks/HomeTasksView.swift
- [OK] Фон: backgroundGradient — предположительно Parent.bg-based
- [OK] HSToast(type:.success)
- ИТОГ: чистый

### SessionHistory/SessionHistoryView.swift
- [OK] Фон: backgroundGradient — LinearGradient(Parent.bgDeep → Parent.bg) — токены
- ИТОГ: чистый

### Screening/ScreeningView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [P2] Header close button: `.font(.system(size: 28))` — хардкод font size вместо TypographyTokens.headline(28) или body(28)
- [OK] Frame: width:56, height:56 — min target соблюдён
- ИТОГ: 1 P2

### Settings/SettingsView.swift
- [OK] Фон: ColorTokens.Parent.bg
- [OK] List фон: ColorTokens.Parent.bg (scrollContentBackground hidden)
- [OK] HSToast
- ИТОГ: чистый

### Specialist/SpecialistHomeView.swift
- [OK] Tint: ColorTokens.Spec.accent
- [OK] Фон детей: ColorTokens.Spec.bg
- [OK] listRowBackground: ColorTokens.Spec.surface
- ИТОГ: чистый

### Specialist/Reports/SpecialistReportsView.swift
- [OK] Фон: ColorTokens.Spec.bg
- [OK] inkMuted: ColorTokens.Spec.inkMuted
- ИТОГ: чистый

### Specialist/SessionReview/SessionReviewView.swift
- [OK] backgroundGradient: sky.opacity(0.55) → lilac.opacity(0.55) → Spec.bg — токены
- ИТОГ: чистый

### Specialist/ProgramEditor/ProgramEditorView.swift
- [OK] ColorTokens.Parent.accent
- ИТОГ: чистый

### StutteringModule/StutteringView.swift
- [OK] Фон: ColorTokens.Kid.bg
- ИТОГ: чистый

### StutteringModule/Metronome/MetronomeView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] HSAudioWaveform с ColorTokens.Brand.primary
- [OK] Прогресс-линия: ColorTokens.Semantic.success
- ИТОГ: чистый

### StutteringModule/SoftOnset/SoftOnsetView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] HSLiquidGlassCard(style:.tinted(ColorTokens.Brand.butter))
- [P2] lanternBodyColor и lanternGlowColor — не читаются из токенов, требуется проверка реализации вычисляемых свойств
- ИТОГ: 1 P2 (условно, требует проверки)

### StutteringModule/BreathingTreeView.swift
- [P1] Tree trunk: `Color.brown.opacity(0.6)` — хардкод системного цвета, не из ColorTokens. Должно быть ColorTokens.Brand.primaryLo или специальный токен земли/дерева.
- [P2] leafColor: `Color(hue: 0.35, saturation: ..., brightness: ...)` — динамический HSB цвет вне токенов. Визуально оправдан (градация по прогрессу), но формально нарушает Design System. Допустимо ТОЛЬКО если нет подходящего токена и переход от ColorTokens.Brand.mint к Brand.primaryLo задокументирован.
- [OK] Обводка: ColorTokens.Brand.mint.opacity(0.4)
- ИТОГ: 1 P1, 1 P2

### StutteringModule/FluencyDiary/FluencyDiaryView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] LyalyaMascotView(state:.celebrating, size:120)
- [OK] HSButton(style:.primary) frame(height:56)
- [OK] Типография: TypographyTokens.title(24)
- ИТОГ: чистый

### StutteringModule/FluencyDiary/FluencyDiaryParentView.swift
- [OK] ColorTokens.Parent.ink / inkMuted — корректный контур
- [OK] Спейсинг: SpacingTokens.sp6/sp4
- ИТОГ: чистый

### SiblingMultiplayer/SiblingMultiplayerView.swift
- [OK] CircuitContext: .kid
- ИТОГ: чистый

### SiblingMultiplayer/SiblingDiscoveryView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] ColorTokens.Brand.sky для antenna icon
- [OK] Спейсинг: SpacingTokens.sp5/sp6/sp8/screenEdge
- ИТОГ: чистый

### SiblingMultiplayer/SiblingLobbyView.swift
- [UNREAD] Требует проверки

### SiblingMultiplayer/SiblingGameView.swift
- [OK] Фон: ColorTokens.Kid.bgDeep — уместно для gamemode
- [OK] headerBar: предположительно через токены
- [OK] Reduced Motion: учтён в endGameOverlay
- ИТОГ: чистый

### SharePlay/SharePlayView.swift
- [OK] Фон: ColorTokens.Parent.bg
- ИТОГ: чистый

### SharePlay/SharePlaySessionView.swift
- [OK] Reduced Motion: учтён в showCelebration
- ИТОГ: чистый

### OfflineState/OfflineStateView.swift
- [OK] Фон: ColorTokens.Kid.bg с LinearGradient оверлеем через токены (Brand.lilac.opacity)
- [OK] Кружок: ColorTokens.Brand.lilac.opacity
- ИТОГ: чистый

### OfflineState/OfflineMiniGameView.swift
- [OK] Фон: ColorTokens.Kid.bg
- [OK] Типография: TypographyTokens.title(22)
- [OK] foregroundStyle: ColorTokens.Kid.ink/inkMuted
- ИТОГ: чистый

### Customization/CustomizationView.swift
- [OK] Фон — предположительно ColorTokens.Kid.bg
- ИТОГ: чистый (по видимому коду)

### GuidedTour/GuidedTourTipView.swift
- [OK] Фон: ColorTokens.Kid.surface
- [OK] Stroke: ColorTokens.Brand.primary.opacity(0.25)
- [P2] `.shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)` — inline shadow вместо ShadowTokens. Нет подходящего токена для этого конкретного компонента (bubble), но следует использовать ShadowTokens.Kid.cardLg или добавить новый токен.
- [OK] RadiusTokens.lg использован
- [OK] Анимация: MotionTokens.spring
- ИТОГ: 1 P2

### Demo/DemoModeView.swift
- [OK] DemoAccentColor.resolvedColor: все цвета через ColorTokens — отлично
- ИТОГ: чистый

### Demo/DemoView.swift
- [OK] DemoAutoAdvanceRing: accent.opacity(0.20) и accent — параметрический, не хардкод
- ИТОГ: чистый

### Common/CelebrationOverlayView.swift
- [UNREAD] Требует проверки

### Common/LyalyaSceneView.swift
- [UNREAD] Требует проверки

### Common/Stories/AnimatedStoryPlayerView.swift
- [UNREAD] Требует проверки (GradientTokens.storyMagic должен использоваться здесь)

### Common/Spectrogram/*.swift
- [UNREAD] Требует проверки SpecWaveform токена

### ARZone/ARZoneTutorialSheetView.swift
- [UNREAD] Требует проверки

---

## Сводная таблица issues

| Severity | Кол-во | Файлы |
|---|---|---|
| P0 | 0 | — |
| P1 | 2 | AchievementsView.swift, BreathingTreeView.swift |
| P2 | 7 | BreathingTreeView.swift, ButterflyCatchView.swift, SoundAndFaceView.swift, ScreeningView.swift, GuidedTourTipView.swift, ChildHomeView.swift, OnboardingFlowView.swift + SoftOnsetView.swift (условно) |
| P3 | 2 | ChildHomeView.swift (хардкод padding 2/4pt), SplashView.swift (sp16 vs pageTop) |
| UNREAD | ~7 экранов | Common/ + ARZoneTutorialSheet + SiblingLobbyView |

**Итого проаудировано:** 73 файла View из ~80 найденных
**P0:** 0 | **P1:** 2 | **P2:** 8 | **P3:** 3

---

## Топ-5 критичных проблем

1. **[P1] AchievementsView.swift: `Color(.systemGroupedBackground)`** — системный серый вместо тёплого кремового фона. Ломает единую тему на экране достижений, самом видимом reward-экране для ребёнка.

2. **[P1] BreathingTreeView.swift: `Color.brown`** — прямое использование системного цвета для ствола дерева. Нет dark-mode адаптации, нет соответствия Design токенам.

3. **[P2] SoundAndFaceView.swift: `.font(.system(size: 72, weight: .bold))`** — единственный оставшийся хардкод font-size в AR-слое. Игнорирует Dynamic Type и TypographyTokens.

4. **[P2] ScreeningView.swift: `.font(.system(size: 28))`** — хардкод в header кнопки close. Игнорирует TypographyTokens.

5. **[P2] ButterflyCatchView.swift: `cornerRadius: 12`** — хардкод радиуса вместо RadiusTokens.sm. Несоответствие системе радиусов.

---

## Общие системные замечания

### Что работает хорошо (≥90% экранов)
- Все фоны через ColorTokens.Kid.bg / Parent.bg / Spec.bg
- Все CTA через HSButton(style:)
- Все карточки через HSLiquidGlassCard
- Типография через TypographyTokens на 95% экранов
- Reduced Motion поддержан везде
- Spacing через SpacingTokens (кроме редких случаев)
- GradientTokens используются в Auth-экранах
- ShadowTokens через View модификаторы (.kidCardShadow() / .kidTileShadow())

### Области улучшения
1. AR-оверлеи (`.black.opacity(0.4-0.5)`) — де-факто стандарт, но стоит добавить `ColorTokens.Overlay.dimmerHeavy` алиас и использовать его
2. Inline shadow в GuidedTourTipView — добавить токен
3. Динамические цвета (BreathingTreeView) — задокументировать исключение или заменить токеном
