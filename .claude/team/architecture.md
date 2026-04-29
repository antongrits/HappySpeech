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
