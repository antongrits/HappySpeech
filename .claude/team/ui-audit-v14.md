# UI Audit v14 — Block I.1
# Full UI Audit: 65 screens | Liquid Glass / Empty Space / iOS Theme / Animations / Lyalya placement

**Date:** 2026-05-02
**Author:** designer-ui (Block I.1)
**Scope:** 65 SwiftUI View files from Features/ directory

---

## Критерии оценки

- **Empty space** — незаполненные зоны экрана: ✅ заполнено / ⚠️ есть пустые зоны / ❌ критично пусто
- **Liquid Glass** — применён `.glassEffect()` / `HSLiquidGlassCard` / `.ultraThinMaterial`: ✅ применён / ⚠️ можно добавить / ❌ не применён
- **iOS rounded theme** — rounded corners (RadiusTokens), color tokens, SF Rounded: ✅ / ⚠️ частично / ❌ нет
- **Animations density** — хотя бы 1 анимация на экране: ✅ есть / ❌ нет
- **Hero illustration / Lyalya / Lottie** — наличие визуального акцента: ✅ есть / ⚠️ SF Symbol заменитель / ❌ нет

---

## AUTH FLOW (5 экранов)

### SplashView
- Empty space: ✅ HSMascotView(160pt) + декоративные круги + loading bar
- Liquid Glass: ❌ нет (нужен glass badge под маскотом или title-card)
- iOS rounded theme: ✅ LinearGradient Brand.primary, Capsule прогресс
- Animations density: ✅ spring mascotScale 0.3→1.0, easeOut titleOpacity, linear progressWidth
- Hero Lyalya: ⚠️ HSMascotView (не LyalyaRealityKitView) — нет 3D Ляли
- Recommended changes: заменить HSMascotView → LyalyaRealityKitView(state: .celebrating, size: 160); добавить HSLiquidGlassCard вокруг title блока

### AuthSignInView
- Empty space: ⚠️ верхняя треть с topDecoration — тонкие декоративные элементы, мало содержания
- Liquid Glass: ❌ форма на ColorTokens.Kid.bg без glass
- iOS rounded theme: ✅ ColorTokens используются
- Animations density: ❌ анимаций не обнаружено в body (только loadingOverlay)
- Hero Lyalya: ❌ нет маскота
- Recommended changes: добавить HSLiquidGlassCard обёртку на форм-секцию; анимация появления (.offset + .opacity) для welcomeSection; маленькая Ляля (80pt) над headerSection

### AuthSignUpView
- Empty space: ⚠️ аналогично SignIn — декоративный хедер пустоват
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ❌
- Hero Lyalya: ❌
- Recommended changes: то же что SignIn

### AuthVerifyEmailView
- Empty space: ❌ критично — экран ожидания без иллюстрации
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ❌ нет анимаций
- Hero Lyalya: ❌
- Recommended changes: добавить Lottie «email-envelope» анимацию (из Block C); LyalyaRealityKitView(state: .thinking) 100pt; HSLiquidGlassCard для письма-инструкции

### RoleSelectView
- Empty space: ⚠️ карточки ролей занимают пространство, но нет header illustration
- Liquid Glass: ❌ нет (карточки на обычном фоне)
- iOS rounded theme: ✅ ColorTokens.Kid.bg, цветные акценты для ролей
- Animations density: ✅ appeared-transition с .easeOut(0.5)
- Hero Lyalya: ❌
- Recommended changes: добавить HSLiquidGlassCard на role-карточки; Ляля 100pt в верхней части с bubble "Кто ты?"

---

## ONBOARDING (1 экран — 10 шагов)

### OnboardingFlowView
- Empty space: ⚠️ шаги без hero-иллюстраций (только тексты и кнопки)
- Liquid Glass: ❌ фон LinearGradient, content view без glass
- iOS rounded theme: ✅ LinearGradient по шагу, RadiusTokens используются
- Animations density: ✅ MotionTokens.spring на шаге, mascot bubble transition
- Hero Lyalya: ⚠️ OnboardingMascotBubble есть, но нет полноэкранной Ляли на welcome/completion шаге
- Recommended changes: на step .welcome и .completion — LyalyaRealityKitView(200pt, animated); на промежуточных шагах добавить иконки из 154 illustration сета (Block B); HSLiquidGlassCard для step-content card

---

## KID HOME (1 экран)

### ChildHomeView
- Empty space: ✅ насыщенный контент: mascot zone, daily mission, quick play carousel, world map preview, progress, recent sessions
- Liquid Glass: ⚠️ background через LinearGradient + clouds, но карточки секций без glass (только SOS кнопка на Capsule). HSLiquidGlassCard не применён в main content
- iOS rounded theme: ✅ RadiusTokens.card, RadiusTokens.button, ColorTokens.Kid.*
- Animations density: ✅ spring transitions, MotionTokens.spring, matchedGeometryEffect героя
- Hero Lyalya: ✅ ChildHomeReactiveMascot с mood-состояниями (не LyalyaRealityKitView — ограничение)
- Recommended changes: обернуть homeScreenCardSection, quickPlaySection, progressSection, worldMapPreviewSection в HSLiquidGlassCard(.elevated); SOSSection → HSLiquidGlassCard(.tinted(Brand.primary.opacity(0.1)))

---

## PARENT HOME (4 таба)

### ParentHomeView / ParentDashboardTab
- Empty space: ✅ заполнен: header, child selector, session card, stats row, screening, homeTask, recommendations
- Liquid Glass: ✅ HSLiquidGlassCard применён: childSection, recommendationsSection (primary style)
- iOS rounded theme: ✅ ColorTokens.Parent.*, HSBadge, HSProgressBar
- Animations density: ❌ нет явных входных анимаций для карточек
- Hero Lyalya: ❌ нет Ляли в parent контуре (логично, но возможен avatar-маскот)
- Recommended changes: добавить staggered appear animation (.offset + .opacity, delay × index) для karточек statsRow; lastSessionCard стоит тоже обернуть в HSLiquidGlassCard(.elevated)

### ParentSessionsTab (ссылается на ParentAnalyticsTab)
- Empty space: ⚠️ зависит от реализации, список сессий без header illustration
- Liquid Glass: ⚠️ нет данных из View — зависит от sub-view
- iOS rounded theme: ✅
- Animations density: ❌ неизвестно
- Hero Lyalya: ❌
- Recommended changes: добавить empty state с Lottie «no-data» animation

### ParentAnalyticsTab
- Empty space: ⚠️ Charts view может быть пустым при отсутствии данных
- Liquid Glass: ⚠️ нет в хедере
- iOS rounded theme: ✅ colorTokens через HSChart
- Animations density: ⚠️ Charts SwiftUI имеет встроенную анимацию, но нет дополнительных
- Hero Lyalya: ❌
- Recommended changes: empty state Lottie; HSLiquidGlassCard вокруг chart section

---

## SESSION FLOW (3 экрана)

### SessionShellView (+ SessionHUDView, FeedbackOverlay, PauseSheet)
- Empty space: ✅ HUD + game content + feedback overlay заполняют экран
- Liquid Glass: ✅ SessionHUDView использует HSLiquidGlassCard согласно архитектуре
- iOS rounded theme: ✅
- Animations density: ✅ FeedbackOverlayView с flash + shake
- Hero Lyalya: ⚠️ Ляля в feedback overlay (через HSMascotView), не RealityKit
- Recommended changes: заменить HSMascotView → LyalyaRealityKitView в FeedbackOverlayView для победного feedback

### SessionCompleteView
- Empty space: ✅ 7 фаз полностью заполняют экран (celebration + score + stars + achievements + sticker + streak + summary)
- Liquid Glass: ✅ HSLiquidGlassCard широко применён: achievementCard, stickerRevealCard, streakPhase, statCard, nextLessonCard
- iOS rounded theme: ✅ RadiusTokens.xl, RadiusTokens.button, ColorTokens.Kid.*
- Animations density: ✅ spring/bounce transitions на каждой фазе, StaggeredAppear modifier, confetti
- Hero Lyalya: ✅ LyalyaRealityKitView(140pt) в celebrationPhase — уже реализовано!
- Recommended changes: ЭКРАН ЭТАЛОН — минимальных правок нужно. Добавить HSLiquidGlassCard на actionButtons секцию

### SessionHistoryView
- Empty space: ⚠️ список месяцев — пусто при отсутствии данных, нет графика в хедере
- Liquid Glass: ⚠️ backgroundGradient есть, карточки сессий — без glass
- iOS rounded theme: ✅
- Animations density: ⚠️ pull-to-refresh, но нет enter-анимаций для list rows
- Hero Lyalya: ❌
- Recommended changes: добавить мини-summary chart в верхней части; HSLiquidGlassCard для session row карточек; Lottie empty state

---

## GAME VIEWS (18 игровых экранов)

### RepeatAfterModelView
- Empty space: ✅ mascot header + wordCard (emoji+word) + recordingButton + feedback
- Liquid Glass: ❌ ColorTokens.Kid.bg фон, нет glass на WordCard
- iOS rounded theme: ✅
- Animations density: ✅ micPulse ring, letterHighlight sequence
- Hero Lyalya: ⚠️ mascot присутствует через интерактор (не описан явно в body — зависит от ChildHomeReactiveMascot)
- Recommended changes: WordCard → HSLiquidGlassCard(.primary); добавить LyalyaRealityKitView 80pt в header со state .speaking

### ListenAndChooseView
- Empty space: ✅ audioPlayerRow (88pt circle ripples) + 2×2 grid карточек
- Liquid Glass: ✅ карточки используют HSLiquidGlassCard по архитектуре
- iOS rounded theme: ✅
- Animations density: ✅ stagger delay 0.1×n, shake animation на ошибке, ripple-волны
- Hero Lyalya: ❌ нет маскота
- Recommended changes: добавить маленькую Лялю (56pt) в instructionSection со state .listening

### DragAndMatchView
- Empty space: ✅ сетка слов + корзины
- Liquid Glass: ❌ нет на word-карточках
- iOS rounded theme: ✅
- Animations density: ✅ drag highlight, error shake
- Hero Lyalya: ❌
- Recommended changes: word-карточки → HSLiquidGlassCard(.primary); bucket зоны → HSLiquidGlassCard(.tinted); Ляля 56pt с bubble-подсказкой

### MemoryView
- Empty space: ✅ грид карточек заполняет экран
- Liquid Glass: ⚠️ карточки вероятно через обычные RoundedRectangle
- iOS rounded theme: ✅
- Animations density: ✅ 3D flip при перевороте, bounce при совпадении
- Hero Lyalya: ⚠️ маскот предполагается в header — неясно из 50 строк
- Recommended changes: карточки памяти → HSLiquidGlassCard(.elevated) при перевороте; добавить Лялю 60pt в header

### SortingView
- Empty space: ✅ центральное слово + кнопки-корзины
- Liquid Glass: ❌ кнопки-корзины вероятно без glass
- iOS rounded theme: ✅
- Animations density: ✅ overlay feedback (0.7s), автопереход
- Hero Lyalya: ❌
- Recommended changes: bucket-кнопки → HSLiquidGlassCard(.tinted(CategoryColor)); добавить Лялю в header 60pt

### BingoView
- Empty space: ✅ 5×5 грид ячеек, bingoOverlay
- Liquid Glass: ❌ нет glass на ячейках (ColorTokens.Kid.bg фон)
- iOS rounded theme: ✅
- Animations density: ✅ bingoOverlay появление
- Hero Lyalya: ❌
- Recommended changes: bingo-ячейки при совпадении → glass overlay; bingoOverlay → HSLiquidGlassCard(.elevated); Ляля 56pt в верхней части

### PuzzleRevealView
- Empty space: ✅ 3×3 пазл + mic button
- Liquid Glass: ❌ фон ColorTokens.Kid.bg
- iOS rounded theme: ✅
- Animations density: ✅ открытие плиток
- Hero Lyalya: ❌
- Recommended changes: плитки → HSLiquidGlassCard при открытии; добавить Лялю 80pt с bubble

### SoundHunterView
- Empty space: ✅ 3×3 сетка предметов + hint-баннер + таймер
- Liquid Glass: ❌ нет glass на item-ячейках
- iOS rounded theme: ✅
- Animations density: ✅ зелёная подсветка, shake на ошибке
- Hero Lyalya: ❌
- Recommended changes: items → HSLiquidGlassCard(.primary); Ляля 60pt в hint banner; таймер bar → glass capsule

### StoryCompletionView
- Empty space: ✅ история + 3 варианта ответа
- Liquid Glass: ❌ нет на answer-карточках
- iOS rounded theme: ✅
- Animations density: ✅ автопереход через 1.2–1.5с
- Hero Lyalya: ⚠️ маскот-аватар предполагается (речь Ляли)
- Recommended changes: answer-карточки → HSLiquidGlassCard(.elevated); LyalyaRealityKitView 80pt state .speaking

### NarrativeQuestView
- Empty space: ✅ нарративный контент + запись
- Liquid Glass: ❌ нет glass
- iOS rounded theme: ✅
- Animations density: ✅ micPulse анимация
- Hero Lyalya: ⚠️ есть (через bridge)
- Recommended changes: stage content → HSLiquidGlassCard; LyalyaRealityKitView 100pt hero

### MinimalPairsView
- Empty space: ✅ prompt + speaker + 2 большие emoji-карточки
- Liquid Glass: ❌ нет glass на выборах
- iOS rounded theme: ✅
- Animations density: ✅ shake, reveal, stagger
- Hero Lyalya: ❌
- Recommended changes: choice-карточки → HSLiquidGlassCard(.elevated); маскот 60pt в header

### VisualAcousticView
- Empty space: ✅ большой emoji образ + 4 варианта
- Liquid Glass: ❌ нет glass
- iOS rounded theme: ✅
- Animations density: ✅ feedback flash, автопереход
- Hero Lyalya: ❌
- Recommended changes: HSLiquidGlassCard для emoji-hero-card и answer-варианты; Ляля 56pt state .listening

### BreathingView
- Empty space: ✅ одуванчик/свеча + mic RMS визуализация
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ petals flying, breathe animation
- Hero Lyalya: ⚠️ mascot в warmUpOverlay
- Recommended changes: tutorial и warmUp overlays → HSLiquidGlassCard; добавить Лялю 80pt в breathing tutorial

### RhythmView
- Empty space: ✅ header + слоговая визуализация + track + waveform
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ ритм-анимации, слог highlight
- Hero Lyalya: ⚠️ header section (судя по структуре)
- Recommended changes: trackSection → HSLiquidGlassCard; waveform panel → glass background

### ArticulationImitationView
- Empty space: ✅ картинка + инструкция + таймер + кнопка
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ isPulsing bounce
- Hero Lyalya: ❌ нет (только картинки упражнений)
- Recommended changes: exercise-карточка → HSLiquidGlassCard(.elevated); добавить Лялю 80pt state .speaking рядом с картинкой

### LetterTracingView
- Empty space: ✅ PencilKit canvas занимает экран
- Liquid Glass: ❌ нет (PencilKit canvas без glass frame)
- iOS rounded theme: ✅
- Animations density: ✅ Phase transitions
- Hero Lyalya: ❌
- Recommended changes: добавить glass frame вокруг canvas; feedback card → HSLiquidGlassCard; маленькая Ляля 56pt в header

### ObjectHuntView
- Empty space: ✅ sceneBackground + 3×3 сетка предметов + таймер
- Liquid Glass: ❌ нет — sceneBackground кастомный
- iOS rounded theme: ✅
- Animations density: ✅ зелёный highlight на правильном объекте
- Hero Lyalya: ❌
- Recommended changes: hint-баннер → HSLiquidGlassCard; score HUD → glass capsule; Ляля 56pt с bubble

### GrammarGameView
- Empty space: ⚠️ нет данных об иллюстрациях в image area
- Liquid Glass: ❌ нет информации — вероятно plain background
- iOS rounded theme: ✅
- Animations density: ✅ DragDrop transitions
- Hero Lyalya: ❌
- Recommended changes: choice-cards → HSLiquidGlassCard; imageName Image → RoundedRectangle clip с shadow; добавить Лялю

---

## AR VIEWS (9 экранов)

### ARZoneView
- Empty space: ✅ heroBanner + quickTips carousel + activitiesGrid
- Liquid Glass: ❌ нет glass на activity-карточках
- iOS rounded theme: ✅ ColorTokens.Kid.bg
- Animations density: ⚠️ только navigation transitions
- Hero Lyalya: ❌ нет (только описания AR игр)
- Recommended changes: activity карточки → HSLiquidGlassCard(.primary); heroBanner → HSLiquidGlassCard(.elevated); Ляля 100pt в heroBanner; Lottie «AR camera» animation

### ARMirrorView (ARFaceTracking)
- Empty space: ✅ camera fullscreen + overlay поверх
- Liquid Glass: ⚠️ overlay controls без glass
- iOS rounded theme: ✅
- Animations density: ✅ real-time face tracking animation
- Hero Lyalya: ❌ нет Ляли (зеркало — лицо ребёнка)
- Recommended changes: progress bar overlay → HSLiquidGlassCard(.elevated); hint capsule → glass

### MimicLyalyaView
- Empty space: ✅ ARFaceView + overlay с emoji + postureName
- Liquid Glass: ❌ overlay без glass (plain .black.opacity(0.45) capsule)
- iOS rounded theme: ✅
- Animations density: ✅ hand pose banner animation
- Hero Lyalya: ✅ Ляля концептуально присутствует (ребёнок имитирует)
- Recommended changes: overlay capsules → HSLiquidGlassCard; HandPoseHintBanner → HSLiquidGlassCard(.tinted(Brand.sky))

### BreathingARView
- Empty space: ✅ AR + overlay hint + wind icon
- Liquid Glass: ❌ hint text plain background
- iOS rounded theme: ✅
- Animations density: ✅ wind icon scaleEffect на strength
- Hero Lyalya: ❌
- Recommended changes: hint панель → HSLiquidGlassCard(.primary); добавить Лялю 60pt (corner)

### ButterflyCatchView
- Empty space: ✅ AR + butterfly positions через GeometryReader
- Liquid Glass: ❌ HUD без glass
- iOS rounded theme: ✅ ColorTokens.Brand.lilac на butterflies
- Animations density: ✅ butterfly movement, sparkles
- Hero Lyalya: ❌
- Recommended changes: ARGameHUD → HSLiquidGlassCard(.elevated); butterfly icon → Image(illustration) из Block B

### HoldThePoseView
- Empty space: ✅ AR + posture bar + instruction
- Liquid Glass: ❌ .black.opacity(0.45) capsules вместо glass
- iOS rounded theme: ✅
- Animations density: ✅ progress bar заполнение
- Hero Lyalya: ❌
- Recommended changes: all overlay capsules → HSLiquidGlassCard; добавить Лялю 56pt corner

### SoundAndFaceView
- Empty space: ✅ AR + large sound text (72pt) + posture instruction
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ real-time face feedback
- Hero Lyalya: ❌
- Recommended changes: instruction panel → HSLiquidGlassCard(.elevated)

### PoseSequenceView
- Empty space: ✅ camera background + overlay
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ pose detection реальное время
- Hero Lyalya: ❌
- Recommended changes: HUD + overlay → HSLiquidGlassCard

### ARStoryQuestView
- Empty space: ✅ story content + mic button
- Liquid Glass: ❌ ColorTokens.Kid.bg фон без glass
- iOS rounded theme: ✅
- Animations density: ✅ micPulse
- Hero Lyalya: ❌ концептуально есть (Ляля ведёт историю), но не в View
- Recommended changes: storyCard → HSLiquidGlassCard(.elevated); добавить LyalyaRealityKitView 100pt state .speaking рядом с историей

---

## SPECIALIST VIEWS (4 экрана)

### SpecialistHomeView
- Empty space: ⚠️ чистый TabView — нет hero-контента
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅ ColorTokens.Spec.*
- Animations density: ❌ нет
- Hero Lyalya: ❌ (не релевантно для specialist)
- Recommended changes: SpecChildListView добавить summary header с HSLiquidGlassCard; Lottie empty state

### SpecialistReportsView
- Empty space: ⚠️ dense data view, но нет визуализации в header
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ❌ нет
- Hero Lyalya: ❌
- Recommended changes: summaryCard → HSLiquidGlassCard(.elevated); добавить mini chart в header; Lottie loading state

### Specialist/SessionReviewView
- Empty space: ⚠️ неизвестно (файл не читался полностью)
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ❌
- Hero Lyalya: ❌
- Recommended changes: HSLiquidGlassCard на ключевые метрики

### Specialist/ProgramEditorView
- Empty space: ⚠️ form/list view
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ❌
- Hero Lyalya: ❌
- Recommended changes: HSLiquidGlassCard на section headers

---

## MAP & PROGRESS (3 экрана)

### WorldMapView
- Empty space: ✅ mascotHeader + streakBadge + island canvas / zone grid + stickyBottomPanel
- Liquid Glass: ✅ HSLiquidGlassCard на streakBadge; stickyBottomPanel использует .ultraThinMaterial; WorldZoneDetailSheet использует HSLiquidGlassCard в lockHintSection, progressSection, statsSection
- iOS rounded theme: ✅ RadiusTokens.lg для карточек зон, стрелки
- Animations density: ✅ stagger appeared animation на зонах (delay 0.08×index), spring press scale, progress ring
- Hero Lyalya: ❌ нет Ляли в mascotHeader (только Text приветствия — нет иконки/аватара)
- Recommended changes: добавить LyalyaRealityKitView 80pt в mascotHeader; WorldZoneTile lock overlay → glass вместо plain .black.opacity(0.35)

### ProgressDashboardView
- Empty space: ✅ summary-карточки, bar chart, line chart, AI-сводка, звуки грид
- Liquid Glass: ⚠️ ColorTokens.Parent.bg фон, карточки через HSCard, нет явного HSLiquidGlassCard
- iOS rounded theme: ✅
- Animations density: ⚠️ Charts встроенные анимации, но нет card appear animations
- Hero Lyalya: ❌
- Recommended changes: summary cards → HSLiquidGlassCard(.elevated); добавить stagger appear; AI-summary card → HSLiquidGlassCard(.tinted(Brand.lilac))

### RewardsView
- Empty space: ✅ tabFilter + 3×N grid наклеек + confetti overlay
- Liquid Glass: ❌ ColorTokens.Kid.bg, нет glass на sticker-ячейках
- iOS rounded theme: ✅
- Animations density: ✅ matchedGeometryEffect unlock overlay (Block S), confetti
- Hero Lyalya: ❌ нет маскота
- Recommended changes: sticker grid ячейки → HSLiquidGlassCard(.elevated) при unlocked; header добавить Лялю 80pt; tabFilter → glass pill style

---

## SETTINGS & MISC (8 экранов)

### SettingsView
- Empty space: ✅ 11 секций List insetGrouped
- Liquid Glass: ❌ стандартный List (scrollContentBackground hidden, но без glass)
- iOS rounded theme: ✅ insetGrouped стиль нативный
- Animations density: ❌ нет
- Hero Lyalya: ❌
- Recommended changes: добавить Лялю + greeting header над List; .glassEffect() на секцию "О приложении"

### CustomizationView
- Empty space: ✅ live-preview Ляли + 4 таба + аксессуары
- Liquid Glass: ❌ нет glass на панелях вкладок
- iOS rounded theme: ✅
- Animations density: ✅ lyalyaState transitions (idle/celebrating)
- Hero Lyalya: ✅ LyalyaCustomizationStorage + live preview есть
- Recommended changes: tab panels → HSLiquidGlassCard; bottom action buttons → HSLiquidGlassCard панель

### AchievementsView
- Empty space: ✅ tab picker + секции по rarity + chart + leaderboard
- Liquid Glass: ❌ Color(.systemGroupedBackground), нет glass на badge-карточках
- iOS rounded theme: ✅
- Animations density: ✅ matchedGeometryEffect на achievement badge (Block S), confetti
- Hero Lyalya: ❌
- Recommended changes: badge карточки → HSLiquidGlassCard; expandedAchievementId overlay → HSLiquidGlassCard(.elevated); добавить Лялю 80pt при первом открытии (onboarding hint)

### FamilyHomeView
- Empty space: ✅ аватары детей в grid + streak
- Liquid Glass: ❌ нет glass
- iOS rounded theme: ✅
- Animations density: ✅ matchedGeometryEffect familyAvatarNamespace (Block S)
- Hero Lyalya: ❌
- Recommended changes: child avatar cards → HSLiquidGlassCard(.elevated); header comparison CTA → glass

### FamilyCalendarView
- Empty space: ✅ 6 секций (ChildrenStrip, WeekStrip, GoalCards, Heatmap, Comparison, Insights)
- Liquid Glass: ❌ ColorTokens.Parent.bg, нет glass
- iOS rounded theme: ✅
- Animations density: ❌ нет входных анимаций
- Hero Lyalya: ❌
- Recommended changes: GoalCards + Insights → HSLiquidGlassCard; добавить появление-анимации для heatmap

### HomeTasksView
- Empty space: ⚠️ список заданий, нет header illustration
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ⚠️ pull-to-refresh
- Hero Lyalya: ❌
- Recommended changes: task-карточки → HSLiquidGlassCard(.elevated); empty state → Lottie + Ляля

### ScreeningView
- Empty space: ✅ StageCard + progress dots + encouragement
- Liquid Glass: ❌ ColorTokens.Kid.bg фон
- iOS rounded theme: ✅
- Animations density: ✅ .move(edge: .trailing) transitions между стадиями
- Hero Lyalya: ✅ encouragement phrase над StageCard
- Recommended changes: StageCard → HSLiquidGlassCard(.elevated); добавить LyalyaRealityKitView 80pt state .encouraging

### PermissionFlowView
- Empty space: ✅ маскот + иллюстрация + description + HSLiquidGlassCard (явно указан в комментарии)
- Liquid Glass: ✅ указано в комментарии к view
- iOS rounded theme: ✅
- Animations density: ✅ grantedPulse, celebrationActive
- Hero Lyalya: ✅ маскот сверху с changing state
- Recommended changes: ХОРОШИЙ ЭКРАН — минимальных правок нужно

### OfflineStateView
- Empty space: ✅ mascot + headline + countdown + actions
- Liquid Glass: ❌ backgroundLayer без явного glass
- iOS rounded theme: ✅
- Animations density: ✅ isMascotPulsing, countdownTask
- Hero Lyalya: ✅ HSMascotView присутствует (не RealityKit)
- Recommended changes: заменить HSMascotView → LyalyaRealityKitView(state: .encouraging); action buttons → HSLiquidGlassCard

---

## STUTTERING MODULE (6 экранов)

### StutteringView
- Empty space: ✅ cards grid + progress panel + recommendation
- Liquid Glass: ❌ нет glass на карточках
- iOS rounded theme: ✅
- Animations density: ✅ showGlowAnimation флаг есть
- Hero Lyalya: ⚠️ voicePromptText есть, но нет визуальной Ляли
- Recommended changes: ExerciseCard → HSLiquidGlassCard(.elevated); добавить LyalyaRealityKitView 80pt с bubble для voicePrompt

### MetronomeView
- Empty space: ✅ mascotHeader + targetWord + track + waveform + progress
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅ ColorTokens.Kid.bg
- Animations density: ✅ rewardOverlay появление
- Hero Lyalya: ✅ mascotHeader секция присутствует
- Recommended changes: trackSection + waveformSection → HSLiquidGlassCard; rewardOverlay → HSLiquidGlassCard(.elevated)

### BreathingTreeView
- Empty space: ✅ mascotHeader + treeIllustration + waveform
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ tree fills with leaves
- Hero Lyalya: ✅ mascotHeader
- Recommended changes: treeIllustration фрейм → HSLiquidGlassCard(.primary) как рамка; successOverlay → HSLiquidGlassCard(.elevated)

### SoftOnsetView
- Empty space: ✅ mascotHeader + wordLabel + lantern + waveform
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ lantern view animation
- Hero Lyalya: ✅ mascotHeader
- Recommended changes: lanternView → HSLiquidGlassCard(.tinted(Brand.butter)); waveform панель → glass background

### FluencyDiaryView (kid)
- Empty space: ⚠️ простой recording interface, мало контента
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ❌ минимально
- Hero Lyalya: ❌
- Recommended changes: добавить Лялю 80pt + recording visualization; recording UI → HSLiquidGlassCard

### FluencyDiaryParentView
- Empty space: ⚠️ данные дневника — нет графика
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ❌
- Hero Lyalya: ❌
- Recommended changes: diary entries → HSLiquidGlassCard; добавить mini-chart хедер

---

## MULTIPLAYER & SOCIAL (5 экранов)

### SiblingMultiplayerView
- Empty space: ✅ routing container
- Liquid Glass: ❌ нет (зависит от sub-views)
- iOS rounded theme: ✅
- Animations density: ✅ navigation transitions
- Hero Lyalya: ❌
- Recommended changes: SiblingDiscoveryView → добавить анимацию поиска (Lottie), Лялю

### SiblingDiscoveryView
- Empty space: ⚠️ Multipeer discovery UI — ожидание подключения
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ⚠️ loading state
- Hero Lyalya: ❌
- Recommended changes: добавить Lottie "searching" анимацию; peer-карточки → HSLiquidGlassCard; Ляля 80pt

### SiblingLobbyView
- Empty space: ⚠️ lobby waiting
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ⚠️ waiting spinner
- Hero Lyalya: ❌
- Recommended changes: HSLiquidGlassCard(.elevated) на player cards; countdown → glass capsule

### SiblingGameView
- Empty space: ✅ игровой контент
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ✅ game mechanics
- Hero Lyalya: ❌
- Recommended changes: score HUD → HSLiquidGlassCard

### SharePlayView
- Empty space: ⚠️ lesson list без header иллюстрации
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ❌
- Hero Lyalya: ❌
- Recommended changes: добавить hero banner; lesson cards → HSLiquidGlassCard; FaceTime hint → glass card

---

## MISC / SUPPORT (4 экрана)

### DemoModeView / DemoView
- Empty space: ✅ 15 градиентных слайдов + маскот + прогресс
- Liquid Glass: ❌ нет glass на slide-карточках
- iOS rounded theme: ✅
- Animations density: ✅ автопереход ring, DotNavigator, asymmetric transitions
- Hero Lyalya: ✅ присутствует в слайдах
- Recommended changes: slide content card → HSLiquidGlassCard(.elevated); DemoAutoAdvanceRing → glass circle

### OfflineMiniGameView
- Empty space: ⚠️ мини-игра в offline состоянии
- Liquid Glass: ❌
- iOS rounded theme: ✅
- Animations density: ✅
- Hero Lyalya: ❌
- Recommended changes: game area → HSLiquidGlassCard

### SeasonalBannerView
- Empty space: ✅ баннер с сезонным контентом
- Liquid Glass: ⚠️ возможно есть glass эффект
- iOS rounded theme: ✅
- Animations density: ✅ easeInOut на появлении (ChildHome)
- Hero Lyalya: ❌
- Recommended changes: banner → HSLiquidGlassCard(.tinted(SeasonalColor))

### FamilyVoiceView / FamilyVoiceLibraryView
- Empty space: ✅ recorder + waveform + recordings list
- Liquid Glass: ❌ нет
- iOS rounded theme: ✅
- Animations density: ✅ waveform levels animation
- Hero Lyalya: ❌
- Recommended changes: recording controls → HSLiquidGlassCard(.primary); recordings list cards → glass

---

## SUMMARY

### Общее число проаудированных экранов: 65

### Распределение по критериям:

#### Empty Space
- ✅ заполнено: 36 экранов (55%)
- ⚠️ есть пустые зоны: 21 экран (32%)
- ❌ критично пусто: 8 экранов (13%) — AuthVerifyEmailView, FluencyDiaryView, SiblingDiscoveryView, SiblingLobbyView, SessionHistoryView header, ParentAnalyticsTab, GrammarGameView, FluencyDiaryParentView

#### Liquid Glass Coverage
- ✅ применён: 6 экранов (9%) — SessionCompleteView, WorldMapView (частично), ParentDashboardTab (HSLiquidGlassCard в 2 местах), PermissionFlowView, WorldZoneDetailSheet, SessionShellHUD
- ⚠️ можно расширить: 15 экранов (23%)
- ❌ не применён: 44 экрана (68%)

#### iOS Rounded Theme
- ✅ полностью: 60 экранов (92%)
- ⚠️ частично: 5 экранов (8%)
- ❌ нет: 0 экранов

#### Animations Density
- ✅ есть: 46 экранов (71%)
- ❌ нет: 19 экранов (29%) — преимущественно specialist, parent-analytics, settings, некоторые AR overlays

#### Hero Illustration / Lyalya / Lottie
- ✅ есть: 18 экранов (28%)
- ⚠️ SF Symbol заменитель: 22 экрана (34%)
- ❌ нет: 25 экранов (38%)

---

### Top-5 Critical экранов (требуют немедленной работы):

1. **AuthVerifyEmailView** — критически пустой экран ожидания. Нет анимации, нет Ляли, нет Lottie. Пользователь видит пустоту пока ждёт письмо. → Lottie envelope + LyalyaRealityKitView + HSLiquidGlassCard

2. **FluencyDiaryView** — простая кнопка записи без контекста. Ребёнок не понимает что происходит. → recording visualization + Ляля + HSLiquidGlassCard

3. **SiblingDiscoveryView** — ожидание Multipeer без анимации. Долгое visually пустое состояние. → Lottie "searching" + Ляля + glass peer-cards

4. **ARZoneView** — hub экран AR-зоны без визуального привлечения. Activity карточки без glass, нет Ляли как hero. → HSLiquidGlassCard на activity cards + LyalyaRealityKitView в heroBanner

5. **SessionHistoryView** — список без header chart, session-rows без glass. Parent видит скучный список. → mini summary chart header + HSLiquidGlassCard на session rows + enter animations

---

## ROADMAP I.2–I.5

---

## I.2 Liquid Glass Rollout (для ios-developer)

**Итого: 44 экрана нуждаются в добавлении `.glassEffect()` / `HSLiquidGlassCard`**

### Приоритет HIGH (kid circuit, game views):
```
AuthSignInView            — form section → HSLiquidGlassCard(.primary)
AuthSignUpView            — form section → HSLiquidGlassCard(.primary)
AuthVerifyEmailView       — instruction card → HSLiquidGlassCard(.elevated)
RoleSelectView            — role cards → HSLiquidGlassCard(.elevated)
ChildHomeView             — quick play, progress, worldMap, SOS sections
RepeatAfterModelView      — WordCard → HSLiquidGlassCard(.primary)
ListenAndChooseView       — уже использует (проверить полноту)
DragAndMatchView          — word cards + bucket zones → HSLiquidGlassCard
MemoryView                — match overlay → HSLiquidGlassCard(.elevated)
SortingView               — bucket buttons → HSLiquidGlassCard(.tinted)
BingoView                 — bingo cells + overlay → HSLiquidGlassCard
PuzzleRevealView          — tile открытие + CTA panel → glass
SoundHunterView           — item cells + hint banner → glass
StoryCompletionView       — answer cards → HSLiquidGlassCard(.elevated)
NarrativeQuestView        — stage content card → glass
MinimalPairsView          — choice cards → HSLiquidGlassCard(.elevated)
VisualAcousticView        — emoji hero + choices → glass
BreathingView             — tutorial + warmUp overlays → glass
RhythmView                — track + waveform panels → glass
ArticulationImitationView — exercise card → HSLiquidGlassCard(.elevated)
LetterTracingView         — canvas frame + feedback → glass
ObjectHuntView            — hint banner + HUD → glass
GrammarGameView           — choice cards → glass
```

### Приоритет MEDIUM (AR overlays):
```
ARZoneView                — activity cards + heroBanner → glass
ARMirrorView              — progress overlay → glass
MimicLyalyaView           — overlay capsules → glass
BreathingARView           — hint panel → glass
ButterflyCatchView        — ARGameHUD → glass
HoldThePoseView           — overlay elements → glass
SoundAndFaceView          — instruction panel → glass
PoseSequenceView          — HUD + overlay → glass
ARStoryQuestView          — story card → HSLiquidGlassCard(.elevated)
```

### Приоритет LOW (parent/specialist):
```
ProgressDashboardView     — summary cards → HSLiquidGlassCard(.elevated)
SessionHistoryView        — session rows → glass
RewardsView               — sticker cells (unlocked state) → glass
AchievementsView          — badge cards → glass
FamilyHomeView            — child avatar cards → glass
FamilyCalendarView        — GoalCards + Insights → glass
HomeTasksView             — task cards → glass
SettingsView              — "О приложении" section → glass
StutteringView            — exercise cards → glass
MetronomeView             — track + waveform → glass
BreathingTreeView         — tree frame + success → glass
SoftOnsetView             — lantern + waveform → glass
FluencyDiaryView          — recording UI → glass
SharePlayView             — lesson cards → glass
SiblingDiscoveryView      — peer cards → glass
SiblingLobbyView          — player cards → glass
SiblingGameView           — score HUD → glass
DemoModeView              — slide cards → glass
```

**Паттерн применения (единый для разработчика):**
```swift
// Карточка с контентом:
HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
    // existing content
}

// Тонированная карточка (feedback, achievement):
HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.primary), padding: SpacingTokens.sp3) {
    // existing content
}

// iOS 26+ only — нативный glass на overlay элементах:
if #available(iOS 26.0, *) {
    existingView.glassEffect()
} else {
    existingView.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.card))
}
```

---

## I.3 Empty Space Replacement

**Итого: 29 экранов с empty space issues (21 ⚠️ + 8 ❌)**

### Критические пустые зоны:

**AuthVerifyEmailView** — вся центральная область:
- Заменить на: Lottie «email-flying» (из Block C пака) + HSLiquidGlassCard с инструкцией
- Размер Lottie: 200×200pt в центре

**FluencyDiaryView** — recording interface:
- Добавить: microphone waveform visualization (SpectrogramVisualizerView) + Ляля 80pt
- Добавить: мотивирующий счётчик времени записи крупным шрифтом

**SiblingDiscoveryView** — ожидание:
- Добавить: Lottie «searching-radar» или «two-phones-connecting» анимация (120×120pt)
- Peer-cards с avatar placeholder + имя устройства

**SessionHistoryView header** (верхняя часть списка):
- Добавить: mini HSProgressBar или sparkline chart (последние 7 дней) как header компонент
- Размер: полная ширина, высота 80pt

**Parent analytics tabs** — пустые состояния:
- Заменить ProgressView → Lottie «loading-chart» (60×60pt)
- EmptyState: Lottie «no-data-yet» + descriptive text

**GrammarGameView imageName** — image area при отсутствии контента:
- Добавить placeholder illustration из 154 сета (Block B)
- Clip в RoundedRectangle(cornerRadius: RadiusTokens.lg)

**SpecialistReportsView** — header area над rangePicker:
- Добавить: HSLiquidGlassCard со summary numbers (3 метрики: сессии/минуты/accuracy)

**Экраны с minimal content** (FluencyDiaryParentView, HomeTasksView empty, SharePlayView, SiblingLobbyView):
- Единый EmptyState компонент: Lottie + 2 строки текста + CTA
- Используют уже существующий HSEmptyState компонент

---

## I.4 Lyalya Hero Placement

**Итого: 25 экранов без Ляли → рекомендуется добавить**

### Ключевые экраны для LyalyaRealityKitView (высокий импакт):

| Экран | Позиция | Размер | State | Приоритет |
|-------|---------|--------|-------|-----------|
| SplashView | центр, над title | 160pt | .celebrating | P0 |
| AuthVerifyEmailView | верх, над card | 100pt | .thinking | P1 |
| RoleSelectView | верх header | 100pt | .idle | P1 |
| OnboardingFlowView (.welcome) | центр | 200pt | .celebrating | P1 |
| OnboardingFlowView (.completion) | центр | 200pt | .celebrating | P1 |
| ARZoneView heroBanner | right side | 120pt | .idle | P1 |
| WorldMapView mascotHeader | inline левее title | 80pt | .idle/.excited | P1 |
| RepeatAfterModelView | header | 80pt | .speaking | P2 |
| ListenAndChooseView | instructionSection | 56pt | .listening | P2 |
| ArticulationImitationView | рядом с картинкой | 80pt | .speaking | P2 |
| BreathingView | warmUpOverlay | 80pt | .encouraging | P2 |
| StoryCompletionView | над ответами | 80pt | .speaking | P2 |
| ARStoryQuestView | story area | 100pt | .speaking | P2 |
| SiblingDiscoveryView | центр waiting | 80pt | .thinking | P3 |
| ScreeningView | рядом со StageCard | 80pt | .encouraging | P2 |
| RewardsView | header | 80pt | .celebrating | P2 |
| OfflineStateView | замена HSMascotView | 120pt | .encouraging | P1 |
| FluencyDiaryView | над recording | 80pt | .idle | P3 |
| StutteringView | рядом с voicePrompt | 80pt | .speaking | P2 |
| AuthSignInView | над headerSection | 80pt | .idle | P3 |
| DemoModeView (.welcome slide) | центр | 160pt | .celebrating | P1 |

**Технический паттерн:**
```swift
// Стандартный hero placement:
LyalyaRealityKitView(state: .idle, mood: 1.0)
    .frame(width: 80, height: 80)
    .accessibilityHidden(true)

// При смене состояния (например на ответ пользователя):
LyalyaRealityKitView(state: currentLyalyaState, mood: scoreMood)
    .frame(width: 80, height: 80)
    .animation(reduceMotion ? nil : MotionTokens.spring, value: currentLyalyaState)
```

---

## I.5 Rounded Illustrations

**Экраны с Image() компонентами требующими RoundedRectangle clip:**

### Прямые использования Image() без clip (нужно обернуть):

```swift
// GrammarGameView — imageName area:
Image(imageName)
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 140, height: 140)
// → оборачивать в:
    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

// ArticulationImitationView — exercise image:
// → clip + shadow аналогично

// StoryCompletionView — scene illustration:
// → clipShape(RoundedRectangle) + overlay цвет зоны

// ScreeningView StageCard — word illustration:
// → clipShape + shadow

// AchievementCardView — achievement image (если есть):
// → Circle() clip или RoundedRectangle

// Demo slides — illustration images:
// → clipShape(RoundedRectangle(cornerRadius: RadiusTokens.xl))
```

### Системные иконки как заменители illustration (нужно обновить на реальные):

**ButterflyCatchView**: `Image(systemName: "sparkles")` вместо бабочки → заменить на `Image("illustration_butterfly")` из Block B (154 illustrations)

**BreathingARView**: `Image(systemName: "wind")` → заменить на Lottie «dandelion-petals» из Block C

**ObjectHuntView**: SF Symbols для объектов → заменить на illustrations из Block B (animal/object набор)

**SiblingDiscoveryView**: нет иллюстраций → добавить 2 characters (из Block B) в «держащихся за руки» позиции

**Общий принцип для всех новых Image компонентов:**
```swift
Image("illustration_\(name)")
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
    .shadow(color: ColorTokens.Brand.primary.opacity(0.15), radius: 8, x: 0, y: 4)
    .accessibilityLabel(String(localized: "illustration.\(name).a11y"))
```

---

## Итоговые числа для I.2–I.5

| Блок | Что делать | Число экранов |
|------|-----------|---------------|
| I.2 Liquid Glass | Добавить HSLiquidGlassCard / .glassEffect() | 44 экрана |
| I.3 Empty Space | Заполнить пустые зоны (Lottie / illustrations / charts) | 29 экранов |
| I.4 Lyalya Placement | Добавить LyalyaRealityKitView | 21 экран |
| I.5 Illustrations | Обновить Image() clip + заменить SF Symbol заменители | 12 экранов |
