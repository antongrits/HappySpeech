# HappySpeech Design Audit v3 (2026-04-23)

**Автор:** designer agent (M7.1)
**Контекст:** Подготовка M7.2 batch 1 (10 экранов), M7.3 DS-компоненты.

## Методология аудита

1. Инвентаризация реализованных View-файлов в `HappySpeech/Features/` (grep `struct.*View.*: View`)
2. Сверка с существующими спеками в `.claude/team/design-specs.md` (1831 LOC)
3. Выделение отсутствующих экранов по пользовательским контурам (kid / parent / specialist / shared)
4. Сопоставление с целевой картой 60+ экранов из плана v3
5. Приоритизация batch 1 из 10 экранов для M7.2

## Реализованные экраны (21 — краткая таблица)

| # | Экран | Контур | LOC Interactor | Статус |
|---|---|---|---|---|
| 1 | ChildHomeView | kid | 105 | ⚠️ нужно углубить до 900+ |
| 2 | ParentHomeView | parent | partial | ⚠️ |
| 3 | SpecialistHomeView | specialist | partial | ⚠️ |
| 4 | OnboardingView | shared | 499 → цель 800+ | ⚠️ |
| 5 | SessionShell | kid | 246 | ✅ deep |
| 6 | OfflineState | shared | 101 | ⚠️ полировка M8.5 |
| 7 | GuidedTourContainerView | shared | (11 шагов wired) | ✅ |
| 8 | ScreeningView | shared | full VIP | ✅ |
| 9 | ProgramEditorView | specialist | full VIP | ✅ |
| 10 | ReportsView | specialist | full VIP | ✅ |
| 11 | SessionReviewView | specialist | full VIP | ✅ |
| 12 | ARZoneView | kid | 520 | ⚠️ полировка M5.4 |
| 13–19 | 7 AR-игр deep | kid | deep | ✅ |
| 20 | ListenAndChoose | kid | 152 | ✅ единственная deep из 16 игр |
| 21 | SoundAndFaceView | kid | deep | ✅ |

## Отсутствующие 39+ экранов

### Kid-контур (29 экранов)
- **Онбординг:** welcome / role-select / avatar-pick / lyalya-intro / first-quest-invite
- **Домашние:** HomeTasks (задания от специалиста), DailyMissionCard, StreakBanner, WorldMap (карта-ландшафт 5 зон)
- **Игровые stubs (15 игр — нужно углубить, M6):** ArticulationImitation, RepeatAfterModel, MinimalPairs, DragAndMatch, Sorting, Memory, Bingo, SoundHunter, StoryCompletion, PuzzleReveal, Rhythm, VisualAcoustic, NarrativeQuest, Breathing (deep ведётся), ARActivity, ARStoryQuest
- **Reward:** SessionComplete, Rewards (album), SoundMapView (mini), StickerReveal
- **Мета:** LyalyaTalk, StoryBook, AudioJournal (M13)

### Parent-контур (9 экранов)
- ProgressDashboard (Swift Charts)
- SessionHistory
- Settings (Theme/Language/Notifications/Models/Privacy)
- DataExportView (GDPR callable)
- NotificationScheduleView
- WeeklyReportView (LLM-generated summary)
- ParentTipsView
- FamilyCalendar (M13)
- AppleHealthImport (M13)

### Specialist-контур (6 экранов)
- SpecialistDashboard
- ChildAssignmentView
- ExerciseLibraryView
- SpecialistNotesView
- VideoConsultationView (M13, WebRTC)
- InterSpecialistChat (M13)

### Shared (7 экранов)
- Permissions (микрофон/камера/уведомления + state machine)
- DemoMode (15-шаговый walkthrough)
- About
- Help/Faq
- PrivacyCenterView
- ModelPackManagerView (WhisperKit / Qwen скачать)
- ErrorStateTemplates

## Отсутствующие 13 DS-компонентов (для M7.3)

| # | Компонент | Назначение | Зависимость |
|---|---|---|---|
| 1 | HSChart | Swift Charts линейные / столбчатые для ProgressDashboard | SwiftUI 6 Charts |
| 2 | HSAudioRecorderView | Визуализация записи с амплитудой + waveform | AVAudioEngine + vDSP |
| 3 | HSLottieContainer | Wrapper для Lottie JSON (RuntimeLottie SPM) | airbnb/lottie-ios |
| 4 | HSRiveView | Wrapper для Rive state-machine | rive-app/rive-ios (M9.3 готов) |
| 5 | HSARSceneView | Wrapper для RealityKit + ARFaceAnchor | ARKit + RealityKit |
| 6 | HSLiquidGlassCard | iOS 26 `.glassBackgroundEffect()` с fallback blur | iOS 17+ fallback |
| 7 | HSAccessibleText | Авто Dynamic Type Small→AccessibilityLarge с scaling | SwiftUI ScaledMetric |
| 8 | HSPermissionRow | Строка разрешения с иконкой + статусом + CTA | — |
| 9 | HSTaskCard | Карточка задания от специалиста (status pill, deadline, star) | — |
| 10 | HSSoundFamilyChip | Чип группы звуков (свистящие/шипящие/сонорные/велар) | — |
| 11 | HSWeekdayGrid | Сетка дней недели 7×1 с состояниями (completed/today/future) | — |
| 12 | HSModalSheet | Универсальный bottom sheet с handle, 3 detent'а | iOS 17 presentationDetents |
| 13 | HSEmptyState | Пустое состояние с Lottie + CTA + иллюстрация | — |

## Приоритизация batch 1 (10 экранов для M7.2)

Выбор основан на: (1) блокирующие зависимости для M6 игр и M8.7 stub-фич; (2) видимость в onboarding/daily flows; (3) максимальная польза для diploma demo.

| # | Экран | Контур | Критичность | Dependency |
|---|---|---|---|---|
| 1 | HomeTasksView | kid | HIGH | блокирует M8.7 HomeTasks deepening |
| 2 | WorldMapView | kid | HIGH | hero navigation для ChildHome |
| 3 | PermissionsView | shared | HIGH | блокирует microphone/camera flows |
| 4 | SessionHistoryView | parent | MEDIUM | — |
| 5 | SettingsView | parent/specialist | HIGH | блокирует Model Pack manager (M4.6/M4.7) |
| 6 | ProgressDashboardView | parent | HIGH | Swift Charts hero для parent |
| 7 | SessionCompleteView | kid | HIGH | каждая сессия заканчивается этим экраном |
| 8 | RewardsView | kid | MEDIUM | мотивация |
| 9 | DemoView | shared | HIGH | для diploma demo первое впечатление |
| 10 | OnboardingView | shared | HIGH | первое касание нового пользователя |

## Batch 2 планируется (M7.2 follow-up — 10 экранов)

- LyalyaTalkView
- StoryBookView
- DailyMissionCardView (standalone)
- WeeklyReportView
- NotificationScheduleView
- ExerciseLibraryView (specialist)
- ChildAssignmentView (specialist)
- DataExportView
- ModelPackManagerView
- ErrorStateTemplates

## Batch 3 (19+ экранов)

Остальные второстепенные + mini-views (StickerReveal, SoundMapView compact, About, Help, Faq, PrivacyCenter + 13 more).

## Риски

- **Claude Design-прототипа нет** (`happyspeech-design/` отсутствует) — приходится проектировать с нуля по CLAUDE.md + ResearchDocs, без эталонных JSX компонентов
- **Swift Charts** в iOS 17+ — стабильно, но HSChart wrapper должен быть lazy (import heavy)
- **Liquid Glass (iOS 26)** — fallback до iOS 17 обязателен
- **Rive runtime SPM** (от M9.3) — уже добавлен, `HSRiveView` используется в HSMascotView

## Следующие шаги

1. `designer` создаёт 10 design specs в `design-specs.md` (batch 1) — **делегировано ios-developer'у т.к. designer без Write**
2. `ios-developer` реализует 7 DS-компонентов из списка (HSChart, HSAudioRecorderView, HSLottieContainer, HSARSceneView, HSLiquidGlassCard, HSAccessibleText, HSPermissionRow) в M7.3
3. `ios-developer` реализует экраны HomeTasks, WorldMap, Permissions по спекам в M8.7
