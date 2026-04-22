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
