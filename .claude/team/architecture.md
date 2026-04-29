# Architecture Decisions (ADR) — HappySpeech
## Version 1.0 — 2026-04-21
## Managed by iOS Lead + Team Lead.

---

## Stack

| Concern | Solution | Version |
|---------|----------|---------|
| Platform | iOS 17+ | Swift 6.x |
| UI | SwiftUI-first + UIKit wrappers (AR, AVAudio) | SwiftUI 6.0 |
| Architecture | Clean Swift (VIP) per feature | — |
| State | `@Observable` (iOS 17+) for ViewModels | — |
| Concurrency | `async/await` + Swift 6 strict concurrency | — |
| DI | Protocol-based, `AppContainer` as single entry | — |
| Local DB | Realm Swift | 10.x |
| Auth | Firebase Auth + Sign in with Apple | — |
| Cloud | Firebase Firestore + Storage + App Check | 11.x |
| ASR | GigaAM-v3 (sherpa-onnx) primary, WhisperKit fallback | — |
| VAD | Silero VAD (.mlpackage) | — |
| AR | ARKit Face Tracking | iOS 17 |
| Audio | AVAudioEngine (16kHz mono), AVAudioRecorder | — |
| DSP | Accelerate / vDSP | — |
| ML | Core ML + MLC-LLM (Qwen2.5-1.5B) | — |
| Logging | OSLog only (no print) | — |
| Tests | XCTest + Swift Testing + SnapshotTesting (SPM) | — |
| Localization | String Catalog (Localizable.xcstrings), ru + en | — |
| Build | xcodegen (project.yml) | — |
| Lint | SwiftLint --strict | — |
| Dependencies | SPM only (no CocoaPods, no Carthage) | — |

---

## Module Dependency Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          App Layer                              │
│  App/  (AppEntry @main, AppCoordinator, AppContainer DI)        │
└────────────────────────┬────────────────────────────────────────┘
                         │ uses
         ┌───────────────▼───────────────────────┐
         │            Features Layer             │
         │  Features/<FeatureName>/              │
         │  (View, Interactor, Presenter,        │
         │   Router, Models, Workers)            │
         └───┬──────────────────────┬────────────┘
             │                     │
    ┌────────▼────────┐   ┌────────▼──────────────┐
    │  DesignSystem   │   │  Services (protocols)  │
    │  Tokens, Theme, │   │  AudioService          │
    │  Components     │   │  ASRService            │
    └────────┬────────┘   │  ARService             │
             │            │  ContentService        │
    ┌────────▼────────┐   │  AdaptivePlannerService│
    │   Shared Layer  │   │  SyncService           │
    │  Modifiers,     │   │  AnalyticsService      │
    │  ViewBuilders,  │   │  PronunciationService  │
    │  a11y helpers   │   │  LocalLLMService       │
    └────────┬────────┘   │  NotificationService   │
             │            │  HapticService         │
    ┌────────▼────────┐   └────────┬───────────────┘
    │   Core Layer    │◄───────────┘
    │  Logger         │
    │  AppError       │←── ML Layer (Core ML wrappers, MLC)
    │  Extensions     │←── Data Layer (Realm models, repos)
    │  Types          │←── Sync Layer (Firestore bridge, queue)
    └─────────────────┘←── Content Layer (ContentEngine, schemas)
                       ←── Analytics Layer (local event bus only)

FORBIDDEN IMPORTS:
  Features → Data (must go through Service protocols)
  Features → ML (must go through ASRService/PronunciationService)
  Features → Sync (must go through SyncService)
  Any layer → Features (no reverse deps)
  Any layer → external analytics SDK (Kids Category violation)
```

---

## ADR Log

### ADR-001: ASR Engine Selection — GigaAM primary, WhisperKit fallback

**Date:** 2026-04-21  
**Status:** Accepted  
**Decision:** Use GigaAM-v3 ONNX via sherpa-onnx as primary Russian ASR engine. WhisperKit (whisper-tiny) as fallback.

**Reasoning:**
- GigaAM-v3 outperforms Whisper-large-v3 on Russian speech benchmarks (per Sber AI Lab paper)
- GigaAM provides word-level timestamps (needed for pronunciation scoring alignment)
- GigaAM is Apache 2.0 (compatible with App Store Kids Category)
- WhisperKit is a proven iOS library with easy SPM integration — ideal fallback

**Alternatives considered:**
1. WhisperKit only — simpler but lower Russian accuracy
2. Apple AVSpeechRecognizer — requires internet, not acceptable for offline-first
3. Kaldi — too complex to integrate on iOS without major effort

**Risk:** sherpa-onnx iOS integration complexity. Mitigation: start integration S5 (parallel to WhisperKit), have WhisperKit ready before GigaAM.

---

### ADR-002: Local LLM — Qwen2.5-1.5B via MLC, structured output only

**Date:** 2026-04-21  
**Status:** Accepted  
**Decision:** Use Qwen2.5-1.5B-Instruct via MLC LLM Swift SDK. No chat interface. Strictly structured JSON output.

**Reasoning:**
- Qwen2.5-1.5B is 950 MB on device — acceptable for iPhone 12+ with 4GB+ RAM
- Supports Russian language well
- Apache 2.0 license
- MLC LLM has iOS Swift SDK with ready model hub
- Structured output (JSON) is reliable with Qwen-2.5 instruction-tuned models

**Alternatives considered:**
1. Gemma 3n — newer, but less mature Russian support
2. Phi-3 mini — good quality, but English-primary
3. No LLM (rule-based only) — acceptable fallback but reduces product differentiation

**Risk:** 950 MB download on first run. Mitigation: optional download, rule-based fallback fully functional.

---

### ADR-003: Local DB — Realm, not CoreData or SQLite

**Date:** 2026-04-21  
**Status:** Accepted  
**Decision:** Realm Swift as local database.

**Reasoning:**
- Realm is mobile-first, offline-first (matches our architecture goal)
- Realm live queries work well with SwiftUI `@Observable`
- Realm has been proven in production iOS apps with similar data models
- CoreData: more complex migration path, less mobile-friendly API
- SQLite: too low-level, would require additional ORM layer

**Risk:** Schema migrations. Mitigation: version all schemas, dedicated MigrationTests target.

---

### ADR-004: No third-party analytics SDK

**Date:** 2026-04-21  
**Status:** Accepted (non-negotiable)  
**Decision:** No Firebase Analytics, no Crashlytics, no Amplitude, no Mixpanel. Local `AnalyticsService` event bus only. MetricKit for performance.

**Reasoning:** Apple Kids Category compliance. Any third-party analytics in a Kids Category app risks rejection or removal. MetricKit provides crash and performance data without violating privacy rules.

---

### ADR-005: Clean Swift (VIP) as feature architecture

**Date:** 2026-04-21  
**Status:** Accepted  
**Decision:** Clean Swift (VIP) pattern for all feature modules.

**Reasoning:**
- Diploma defense requires demonstrable architectural rigor
- VIP separates concerns cleanly: View (renders), Interactor (business logic), Presenter (transforms)
- Highly testable: Interactor and Presenter tested in isolation with mocks
- Router handles navigation cleanly

**Alternatives considered:**
1. MVVM + Combine — simpler but harder to test at scale
2. TCA (The Composable Architecture) — powerful but steep learning curve, overkill for diploma

---

### ADR-006: SPM only, no CocoaPods or Carthage

**Date:** 2026-04-21  
**Status:** Accepted  
**Decision:** All dependencies via Swift Package Manager only.

**Reasoning:**
- SPM is native to Xcode, no additional tooling
- Consistent with Swift 6 + Xcode 16+ ecosystem
- Firebase SDK, RealmSwift, WhisperKit all have official SPM support

---

## Folder Structure

```
HappySpeech/
├── App/
│   ├── HappySpeechApp.swift          @main
│   ├── AppCoordinator.swift
│   └── DI/
│       └── AppContainer.swift
├── Core/
│   ├── Logger/
│   ├── Errors/
│   ├── Extensions/
│   └── Types/
├── DesignSystem/
│   ├── Tokens/
│   │   ├── ColorTokens.swift
│   │   ├── TypographyTokens.swift
│   │   ├── SpacingTokens.swift
│   │   ├── RadiusTokens.swift
│   │   └── MotionTokens.swift
│   ├── Theme/
│   │   └── ThemeEnvironment.swift
│   └── Components/
│       ├── HSButton.swift
│       ├── HSCard.swift
│       ├── HSMascotView.swift
│       ├── HSProgressBar.swift
│       ├── HSAudioWaveform.swift
│       ├── HSSticker.swift
│       ├── HSBadge.swift
│       └── HSToast.swift
├── Shared/
│   ├── ViewModifiers/
│   └── Accessibility/
├── Features/
│   ├── Auth/
│   ├── Onboarding/
│   ├── ChildHome/
│   ├── WorldMap/
│   ├── LessonPlayer/
│   │   ├── ListenAndChoose/
│   │   ├── RepeatAfterModel/
│   │   ├── DragAndMatch/
│   │   ├── StoryCompletion/
│   │   ├── PuzzleReveal/
│   │   ├── Sorting/
│   │   ├── Memory/
│   │   ├── Bingo/
│   │   ├── SoundHunter/
│   │   ├── Breathing/
│   │   ├── Rhythm/
│   │   ├── NarrativeQuest/
│   │   ├── MinimalPairs/
│   │   ├── VisualAcoustic/
│   │   └── ARActivity/
│   ├── SessionComplete/
│   ├── Rewards/
│   ├── ARZone/
│   ├── ParentHome/
│   ├── ProgressDashboard/
│   ├── SessionHistory/
│   ├── HomeTasks/
│   └── Specialist/
├── Services/
│   ├── AudioService.swift (protocol + live)
│   ├── ASRService.swift
│   ├── ARService.swift
│   ├── ContentService.swift
│   ├── AdaptivePlannerService.swift
│   ├── SyncService.swift
│   ├── AnalyticsService.swift
│   ├── PronunciationScorerService.swift
│   ├── LocalLLMService.swift
│   ├── NotificationService.swift
│   └── HapticService.swift
├── Data/
│   ├── Models/ (Realm models)
│   ├── Repositories/
│   └── Migrations/
├── ML/
│   ├── ASR/ (GigaAM + WhisperKit wrappers)
│   ├── VAD/ (Silero VAD)
│   ├── Scorer/ (PronunciationScorer)
│   └── LLM/ (MLC Qwen wrapper)
├── Sync/
│   ├── FirestoreBridge.swift
│   ├── SyncQueue.swift
│   └── ConflictResolver.swift
├── Content/
│   ├── ContentEngine.swift
│   ├── Schemas/
│   └── Seed/
├── Analytics/
│   └── LocalEventBus.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── Models/  (SileroVAD.mlpackage, PronunciationScorer.mlpackage)
│   ├── Audio/   (reference pronunciations, UI sounds)
│   └── Localizable.xcstrings
├── ResearchDocs/
└── ProductSpecs/

HappySpeechTests/
├── Unit/
│   ├── Interactors/
│   ├── Presenters/
│   └── Services/
├── Snapshot/
│   ├── DesignSystem/
│   ├── ChildCircuit/
│   ├── ParentCircuit/
│   └── StateScreens/
├── Integration/
│   ├── RealmTests/
│   └── SyncTests/
└── Mocks/

HappySpeechUITests/
├── Flows/
│   ├── OnboardingFlowTests.swift
│   ├── SessionFlowTests.swift
│   ├── ParentDashboardFlowTests.swift
│   └── SpecialistExportFlowTests.swift
└── ScreenshotTour/
    └── ScreenshotTourTests.swift
```

---

### ADR-V11-LOTTIE — Real Lottie hand-composed tutorials (Block A)

> Полный ADR в `.claude/team/decisions.md`. Кратко: 8 tutorial Lottie JSON v5.x написаны вручную (python-lottie deprecated API → отказ). Commit `dc6dc82`.

---

### ADR-V11-BODY-TRACKING — ARKit body pose в PoseSequence

**Дата:** 2026-04-29
**Статус:** Accepted
**Автор:** ios-dev-arch (Block G, Plan v11)

**Контекст:** Plan v11 Block G — замена mock body tracking реальным ARKit ARBodyTrackingConfiguration для игры PoseSequence.

**Решение:**
- `ARBodyTrackingConfiguration` на A12+ устройствах (iPhone XS, XR и новее)
- 8 отслеживаемых суставов: root, head, leftHand, rightHand, leftFoot, rightFoot, leftShoulder, rightShoulder
- Cosine similarity per joint (relative to root), weighted average → score 0...100
- Порог удержания позы: score >= 65 на протяжении 20 кадров (~2 секунды при 10fps mock, ~0.7 секунды при 30fps)
- Graceful fallback: `isAvailable == false` → mock-обновления (~10fps) для работы на симуляторе и старых устройствах
- Face-режим (blendshapes) сохранён и выбирается автоматически если ARBodyTrackingConfiguration не поддерживается
- 5 эталонных поз в `TargetPosesRepository`: armsUp, handsOnHips, cobra, warrior, tree

**Альтернативы рассмотрены:**
1. `VNDetectHumanBodyPoseRequest` (Vision) — 2D-only, менее точно для 3D-поз, отложено
2. `ARBodyAnchor` через дополнительный `ARView` с body-конфигурацией — сложнее в интеграции с существующим ARFaceViewContainer, отложено

**Следствия:**
- iPhone XS+ (A12+) требуется для real body tracking
- Старые устройства и симулятор: автоматический mock (graceful degradation)
- `PoseSequenceModels` расширены новым case `UpdateBodyPose`
- `PoseSequencePresenter` расширен методом `presentUpdateBodyPose`
- Новые файлы: `Workers/BodyPoseWorker.swift`, `Workers/PoseSimilarityWorker.swift`, `TargetPosesRepository.swift`

---

### ADR-V11-APPLE-GUIDELINES — Kids Category compliance polish

**Дата:** 2026-04-29
**Статус:** Accepted
**Контекст:** Plan v11 Block I — финальная полировка для App Store Kids Category review (Sprint 12).

**Решение:**
- `ParentalGate` (math-problem verification) добавлен в `DesignSystem/Components/ParentalGate.swift`
- Все внешние ссылки в Settings проходят через `ParentalGate` (licenses → GitHub repo URL)
- `NSUserTrackingUsageDescription` удалён из Info.plist и project.yml (Kids Category запрещает трекинг)
- `LSApplicationCategoryType = public.app-category.education` добавлен в Info.plist и project.yml
- Добавлены: `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSUserNotificationsUsageDescription` на русском
- `ITSAppUsesNonExemptEncryption = false` подтверждён (уже присутствовал)
- `CFBundleDevelopmentRegion = ru` подтверждён (уже присутствовал)
- `docs/app-privacy-checklist.md` — чеклист для App Store Connect Privacy Nutrition Label
- Локализационные ключи `parental_gate.*` добавлены в `Localizable.xcstrings`

**Apple guidelines покрытые:**
- App Review 1.3: Kids Category
- App Review 5.1.4: Apps in Kids Category — no external links without parental gate
- App Review 4.5: Compatibility — math problem как доступный parental gate (не жест, не пароль)
- COPPA: дети не вводят личные данные напрямую

**Выбор типа Parental Gate:**
- Math problem (выбран): accessible, не требует родительского пароля, достаточно сложен для 5–8 лет
- Sustained press gesture: менее accessible для пользователей с motor disabilities
- Device password: требует системных API, не App Store Kids compliant без MFI

**Следствия:**
- `SettingsLicenseDetailSheet` получил `onOpenURL: (URL) -> Void` callback вместо прямого `@Environment(\.openURL)`
- `SettingsView` управляет `showParentalGate` и `parentalGatePendingURL` state
- Unit тесты: `HappySpeechTests/DesignSystem/ParentalGateTests.swift`

---

## ADR-V11-SPOTLIGHT — CoreSpotlight indexing

**Дата:** 2026-04-29
**Статус:** Accepted
**Автор:** iOS Lead (Block K)

### Контекст

Plan v11 Block K — индексация уроков / достижений / сессий в iOS Spotlight Search.
Пользователь ищет "звук Ш" в iOS → видит релевантные уроки и сессии в результатах.

### Решение

- **3 домена индексации:**
  - `ru.happyspeech.spotlight.lessons` — все уроки из ContentService.allPacks()
  - `ru.happyspeech.spotlight.achievements` — разблокированные достижения
  - `ru.happyspeech.spotlight.sessions` — последние 30 сессий (prefix(30))
- **COPPA-safe:** SpotlightSessionItem не содержит childName / childId. В индексе только soundId + score.
- **Re-index throttle:** 5 минут между повторными индексациями
- **Polling:** каждые 30 минут в фоне через Task.sleep
- **Deep link:** onContinueUserActivity(CSSearchableItemActionType) → AppCoordinator routing
  - `lesson_<id>` → LessonPlayer
  - `achievement_<id>` → Achievements screen
  - `session_<id>` → SessionHistory screen
- **Actor isolation:** LiveSpotlightIndexer — `actor`, MockSpotlightIndexer — `actor`
- **DI:** lazy property `spotlightIndexer` в AppContainer, mock в preview()

### Альтернативы отклонены

- **App Search (NSUserActivity search):** deprecated, менее гибкий
- **Spotlight App Extension:** избыточен, требует отдельного extension target

### Файлы

- `Features/Extensions/Spotlight/SpotlightIndexer.swift`
- `Features/Extensions/Spotlight/SpotlightIndexCoordinator.swift`
- `Features/Extensions/Spotlight/SpotlightDeepLinkHandler.swift`
- `HappySpeechTests/Unit/Services/SpotlightIndexerTests.swift`

---

## ADR-V11-APPINTENTS — Siri App Shortcuts

**Дата:** 2026-04-29
**Статус:** Accepted
**Автор:** iOS Lead (Plan v11 Block L)

### Контекст

Plan v11 Block L — голосовое управление приложением через Siri Shortcuts.
Пользователь говорит "Сири, открой урок звука Ш в HappySpeech" → приложение открывается на нужном экране.

### Решение

- **AppShortcutsProvider** (`HappySpeechAppShortcuts`) — 5 статических shortcuts, iOS регистрирует их автоматически без действий пользователя.
- **5 AppIntents:** OpenLessonIntent (с параметром soundId), ShowChildProgressIntent, StartBreathingIntent, PlayWithLyalyaIntent, ShowTodaysMissionIntent.
- **DeepLinkRouter** — `@MainActor final class`, singleton, хранит pending actions до регистрации coordinator, воспроизводит по FIFO.
- **AppCoordinatorBridge** — протокол-мост, изолирует intents от конкретного класса AppCoordinator.
- **SiriDeepLinkHandler.swift** — extension `AppCoordinator: AppCoordinatorBridge`, аналогично SpotlightDeepLinkHandler (K-блок).
- **Регистрация:** `DeepLinkRouter.shared.register(coordinator:)` вызывается в `bootstrapApp()` после `Realm.open()`.
- **iOS 17+** — все типы помечены `@available(iOS 17.0, *)`. Регистрация в `bootstrapApp` завёрнута в `if #available(iOS 17.0, *)`.
- **Все фразы / заголовки / описания — на русском** (Russian-only mandate).
- **Параметр soundId** в OpenLessonIntent нормализует регистр и мягкий знак (РЬ → Рь, ЛЬ → Ль).

### Альтернативы отклонены

- **Старый Intents framework (INExtension):** deprecated в iOS 18, требует отдельный extension target.
- **Custom URL scheme:** менее интегрирован с Siri, нет Shortcuts.app интеграции.
- **SiriKit Domains (messaging/workout):** не подходит для логопедического контента.

### Файлы

- `Features/Extensions/SiriShortcuts/AppShortcutsProvider.swift`
- `Features/Extensions/SiriShortcuts/DeepLinkRouter.swift`
- `Features/Extensions/SiriShortcuts/SiriDeepLinkHandler.swift`
- `Features/Extensions/SiriShortcuts/Intents/OpenLessonIntent.swift`
- `Features/Extensions/SiriShortcuts/Intents/ShowChildProgressIntent.swift`
- `Features/Extensions/SiriShortcuts/Intents/StartBreathingIntent.swift`
- `Features/Extensions/SiriShortcuts/Intents/PlayWithLyalyaIntent.swift`
- `Features/Extensions/SiriShortcuts/Intents/ShowTodaysMissionIntent.swift`
- `HappySpeechTests/Unit/Features/Extensions/AppShortcutsTests.swift`

---

## ADR-V11-LIVEACTIVITY — Live Activities + Dynamic Island

**Дата:** 2026-04-29
**Статус:** Accepted
**Автор:** ios-dev-arch (Block M, Plan v11)

### Контекст

Plan v11 #13 — реализовать Live Activity для сессии урока. Пользователь должен видеть прогресс урока прямо с экрана блокировки и из Dynamic Island без открытия приложения.

### Решение

- `LessonSessionAttributes` — ActivityKit-атрибуты (shared между main app и widget extension)
- `LiveActivityManager` — singleton `@MainActor`, управляет жизненным циклом активности
- `HappySpeechWidgetExtension` — отдельный Widget Extension target (iOS 16.1+)
- `LessonSessionLiveActivity` — Widget конфигурация: Lock Screen + Dynamic Island (compact/expanded/minimal)
- Интеграция в `SessionShellInteractor`: start при startSession, update при completeActivity, end при завершении
- `NSSupportsLiveActivities = YES` в main app Info.plist

### COPPA-соблюдение

- Атрибуты не содержат имени ребёнка, возраста или иных персональных данных
- `sessionId` = `childId + UUID` — не раскрывает личность
- `lessonTitle` = идентификатор звука (например, «Звук С»), без персонификации

### Минимальная версия iOS

- Live Activities: iOS 16.1 (`@available(iOS 16.1, *)` везде)
- Dynamic Island: доступен только на iPhone 14 Pro+; на остальных устройствах показывается только Lock Screen
- Main app target остаётся iOS 17.0; Widget Extension target — iOS 16.1

### Альтернативы отклонены

- **Push-уведомления вместо Live Activities:** менее богатый UI, нет realtime-обновлений
- **Widget Timeline без ActivityKit:** нет realtime, не подходит для сессии
- **Отдельный target для каждого типа контента:** избыточно, один WidgetBundle вмещает все

### Файлы

- `HappySpeech/Features/Extensions/LiveActivities/LessonSessionAttributes.swift` (shared)
- `HappySpeech/Features/Extensions/LiveActivities/LiveActivityManager.swift`
- `HappySpeechWidgetExtension/HappySpeechWidgetBundle.swift`
- `HappySpeechWidgetExtension/LessonSessionLiveActivity.swift`
- `HappySpeechTests/Features/LiveActivities/LessonSessionAttributesTests.swift`

---

## ADR-V11-WIDGET — Real Widget Extension (Small/Medium/Large)

**Дата:** 2026-04-29
**Статус:** Accepted
**Контекст:** Plan v11 Block N — real Widget Extension вместо HomeScreenCard-imitation (Plan v10 L9).

**Решение:**
- `DailyMissionWidget`: поддержка Small / Medium / Large families
- `DailyMissionProvider`: TimelineProvider с refresh-политикой `.after(1 hour)`
- App Group `group.com.happyspeech.shared` — shared UserDefaults для передачи данных из main app в виджет
- `LiveDailyMissionSyncService` (actor) вызывается из `ChildHomeInteractor` после успешного fetch
- `WidgetCenter.shared.reloadTimelines(ofKind: "DailyMissionWidget")` — принудительный перерисунок
- Tap deep link: `happyspeech://daily-mission` → `DeepLinkRouter.shared.handleShowTodaysMission()`
- `HappySpeechWidgetBundle` обновлён: включает `DailyMissionWidget` + `LessonSessionLiveActivity`

**COPPA compliance:**
- В App Group UserDefaults НЕТ имени ребёнка, персональных данных или ID
- Только: title (название звука), description (кол-во раундов), streak (число), lyalyaState (строка), progress (Double)

**Альтернативы отклонены:**
- HomeScreenCard mimics (Plan v10 L9) — оставлен как in-app preview, не является системным виджетом
- Configurable intent widget — избыточен для MVP, добавить в backlog v1.1

**Файлы:**
- `HappySpeechWidgetExtension/DailyMissionWidget/DailyMissionProvider.swift`
- `HappySpeechWidgetExtension/DailyMissionWidget/DailyMissionWidgetView.swift`
- `HappySpeechWidgetExtension/DailyMissionWidget/DailyMissionWidget.swift`
- `HappySpeechWidgetExtension/HappySpeechWidgetBundle.swift` (обновлён)
- `HappySpeech/Features/Extensions/Widget/DailyMissionSyncService.swift`
- `HappySpeechTests/Features/Extensions/Widget/DailyMissionSyncServiceTests.swift`

---

## Plan v11 итог — ЗАВЕРШЁН 2026-04-29

Все 15 блоков A–N выполнены (17 коммитов, от dc6dc82 до финального Block O).

### Список ADR-V11

| ADR | Блок | Краткое описание |
|-----|------|-----------------|
| ADR-V11-LOTTIE | A | 8 Lottie tutorial JSON v5.x hand-composed (python-lottie deprecated) |
| ADR-V11-RIVE-V2 | B | Lyalya multi-layer wrapper (skills.riv + illustration overlay + lip-sync) |
| ADR-V11-FACEMESH-DEFER | C.4 | FaceMesh 478 окончательно defer — Apple Vision 76 + ARKit достаточно |
| ADR-V11-FIREBASE-FULL | D | Firebase 5 services: RC + FCM + Storage + App Check + Performance |
| ADR-V11-BIG-LIBS | E | SPM: Lottie 4.5+ real API + Down 0.11 Markdown + native confetti Canvas |
| ADR-V11-LIPSYNC | F | Real-time lip-sync ARFaceAnchor → MascotLipSyncState → MouthBubbleOverlay |
| ADR-V11-BODY-TRACKING | G | ARBodyTrackingConfiguration (A12+) + PoseSequence cosine similarity |
| ADR-V11-LLM-KID | H | Qwen2.5 kid circuit: KidLLMNarrationService + KidSafetyFilter + COPPA |
| ADR-V11-APPLE-GUIDELINES | I | Kids Category polish: ParentalGate + LSApplicationCategoryType |
| ADR-V11-HEALTHKIT | J | HealthKit mindful sessions (parent opt-in, write-only, COPPA-safe) |
| ADR-V11-SPOTLIGHT | K | CoreSpotlight: 3 домена, COPPA-safe, deep link routing |
| ADR-V11-APPINTENTS | L | Siri AppShortcuts: 5 intents, DeepLinkRouter, Russian-only |
| ADR-V11-LIVEACTIVITY | M | Live Activities + Dynamic Island (ActivityKit, iOS 16.1+) |
| ADR-V11-WIDGET | N | Real Widget Extension Small/Medium/Large (App Group shared UserDefaults) |

### Bundle metrics после Plan v11

| Метрика | Значение |
|---------|---------|
| Resources total | 237 MB |
| Audio .m4a (Lyalya) | 1 526 фраз |
| Audio .m4a (content + refs) | 6 509 файлов |
| Video MP4 | 80 |
| ML models (.mlpackage) | 7 шт (48 MB) |
| Voice clone reference | voice_clone_reference.wav (47.4 MB) |
| Lottie JSON tutorials | 8 (~360 KB) |
| HD illustrations (FLUX) | 18+ (Assets.xcassets/Illustrations/) |
| Localization ru keys | 1 944+ (0 en) |

### Tag

`v1.0.0-pro` — Plan v11 ФИНАЛ
