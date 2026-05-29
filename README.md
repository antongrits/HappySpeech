# HappySpeech

**HappySpeech** is a Russian-language, offline-first iOS application for speech
correction and language development in children aged 5–8. It is built for the
Apple Kids Category and is methodologically grounded in classical Russian
speech-therapy practice (Filicheva, Chirkina, Tkachenko, Kartushina).

The app helps a child set and automate the sounds of Russian, develop phonemic
hearing, expand vocabulary, work on prosody and breathing, and practice
connected speech — all while running **completely without an internet
connection**. Parents get progress analytics and a speech-growth diary;
speech-language pathologists get a dedicated screening and assessment workspace.

---

## Table of Contents

- [Overview](#overview)
- [Target Audiences](#target-audiences)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Architecture](#architecture)
- [On-Device ML Models](#on-device-ml-models)
- [Requirements](#requirements)
- [Build & Run](#build--run)
- [Firebase Setup (optional)](#firebase-setup-optional)
- [Testing](#testing)
- [Repository Structure](#repository-structure)
- [Content Engine](#content-engine)
- [Localization](#localization)
- [Accessibility](#accessibility)
- [Privacy & COPPA](#privacy--coppa)

---

## Overview

HappySpeech supports a 5–8 year-old child in:

- **setting and automating** the sounds of the Russian language;
- developing **phonemic hearing** (discriminating opposing phonemes);
- expanding **object, verb, and attribute vocabulary**;
- working on **prosody, speech tempo/rhythm, and breathing**;
- practicing **retelling and connected speech**.

All learning content — text, audio, illustrations, and ML models — is bundled
into the app at build time, so the core experience runs **fully offline**.
Firebase is used only for optional cross-device progress sync between a parent's
and a child's device; it is not required for the app to work.

The experience is organized into three user "contours" (kid / parent /
specialist), plus a hidden adaptive planner that assembles each child's daily
route of exercises.

---

## Target Audiences

| Contour        | Who uses it                    | UI tone                               |
| -------------- | ------------------------------ | ------------------------------------- |
| **Kid**        | Child aged 5–8                 | Playful, warm, low-text               |
| **Parent**     | Parent / guardian              | Calm, structured, jargon-free         |
| **Specialist** | SLP / defectologist            | Analytical, with assessment tooling   |

The **`AdaptivePlannerService`** composes a daily exercise route taking into
account the child's fatigue and spaced repetition, so practice stays effective
without overwhelming the child.

---

## Features

### Sound production

- **4 sound groups** (whistling С/З/Ц, hissing Ш/Ж/Ч/Щ, sonorant Р/Рь/Л/Ль,
  velar К/Г/Х) × **14 correction stages**, from articulation preparation to
  free speech.
- **4 `PronunciationScorer` Core ML models** (one per group) that evaluate the
  quality of a produced sound entirely on-device.
- **16 exercise templates** (`listen-and-choose`, `repeat-after-model`,
  `drag-and-match`, `puzzle-reveal`, `minimal-pairs`, `narrative-quest`,
  `articulation-imitation`, `sorting`, `memory`, `bingo`, `sound-hunter`,
  `story-completion`, `visual-acoustic`, `breathing`, `rhythm`,
  `listen-and-choose`).

### Vocabulary & grammar

- **20 lexical themes × 60–105 words** with object + verb + attribute vocabulary
  (Filicheva/Chirkina methodology).
- **`GrammarGame`** — agreement of case, number, and gender.
- **`LexicalThemes`** — themed study ("Vegetables", "Wild Animals",
  "Professions", etc.).
- **`SyllableConstructor`** — building words from syllables.
- **`WordBank`** — the child's personal vocabulary.

### Connected speech

- **`Retelling`** — retelling from pictures and a plan.
- **`Storytelling`** — composing a story from a picture series.
- **`OralStoryCreator`** — an oral story from 3 random pictures, with ASR
  transcription and a lexical-diversity (TTR) score.
- **`ObjectDescriptionMap`** — describing an object from a 6–8 pictogram plan
  schema (Tkachenko methodology); ASR + `DescriptionCoverageAnalyzer` measures
  how many plan items are covered.
- **`ComprehensionDetective`** — listening-comprehension game.

### Prosody & tempo/rhythm

- **`Prosody`** — interrogative vs. declarative intonation.
- **`SpeechTempo`** — slow vs. fast tempo.
- **`BreatheAndSpeak`** — breathing exercises with a visual pacer.
- **`Logorhythmics`** — logorhythmics (Kartushina): the child chants rhymes to a
  software beat while the iPhone accelerometer detects taps/stomps and computes
  an F1 match against the beat pattern.
- **`KaraokePitch`** — singing along a reference pitch contour; a YIN pitch
  tracker scores how well the child hits the note.

### Phonemic hearing

- **`PhonemicListening`** — discriminating opposing phonemes.
- **`SoundTrafficLight`** — minimal-pair discrimination (С/Ш, Р/Л, З/Ж, …).
- **`MinimalPairs`** template via the shared `LessonPlayer`.

### Special modules

- **`FingerPlay`** — Vision `VNDetectHumanHandPoseRequest` recognizes the
  child's hand pose for finger games.
- **`LetterTrace`** — letter tracing with PencilKit (iPad + Apple Pencil, or
  finger).
- **`ARFaceFilter`** — ARKit Face Tracking used as a mirror for articulation
  practice.
- **`StutteringModule`** — fluency-training module with 5 techniques.
- **`SpeechVisualization`** — a real-time voice spectrogram (vDSP FFT).

### Parent contour

- **`ParentHome`** — overview of every child's progress in the family.
- **`ProgressDashboard`** — charts by sound, week, and accuracy, with an
  interactive (scrubbable) accuracy trend.
- **`NeurolinguistInsights`** — weekly report with interpreted results.
- **`SpeechGrowthDiary`** — an encrypted (AES-GCM-256, key in Keychain) video
  diary of the child's speech samples.
- **`ParentVoiceNote`** — voice notes from parent to child.
- **`ParentGuide`** — educational cards about speech development.
- **`SpeechNormsEncyclopedia`** — age-based speech-development norms.
- **`DailyTimeCap`** — a parent-configurable daily in-app time limit (internal
  accumulator, no Family Controls dependency).

### Specialist contour

- **`Specialist`** — the SLP workspace.
- **`SpecialistAssessment`** — a formal screening questionnaire (Levina/Arkhipova).
- **`Screening`** — a quick first-pass evaluation.
- **`LogopedistChat`** — a parent ↔ specialist text channel (Firebase).

### Family & social

- **`Family`, `FamilyCalendar`, `FamilyLeaderboard`, `FamilyAchievements`,
  `FamilyAwardsCabinet`** — a multi-user family model.
- **`SharePlay`** — co-op lesson over FaceTime (iOS 15+).
- **`SiblingMultiplayer`** — two children playing on one device.
- **`WeeklyChallenge`, `DailyChallenge`, `DailyStreak`** — gamification.

### Gamification

- **`Rewards`, `RewardShop`, `WorldMap`** — characters, rewards, a world map of
  sound "islands".
- **`LessonPlayer`** — the unified lesson engine featuring the mascot "Lyalya".
- Push notifications via `UNUserNotificationCenter` and Live Activities via
  `ActivityKit` for long lessons.

Each feature lives under `HappySpeech/Features/<FeatureName>/`.

---

## Technology Stack

| Layer                  | Technology                                                                   |
| ---------------------- | ---------------------------------------------------------------------------- |
| UI                     | SwiftUI 6 + UIKit wrappers (PencilKit, AR, Camera)                           |
| Architecture           | Clean Swift (VIP) + protocol-oriented dependency injection                   |
| Concurrency            | Swift 6 strict concurrency, `async/await` throughout                         |
| Local database         | Realm Swift (schema v12, migrations in `Data/Migrations`)                    |
| Cloud (optional)       | Firebase Auth, Firestore, Storage, App Check, Functions, Performance, Messaging |
| Authentication         | Sign in with Apple + Google Sign-In                                          |
| Speech recognition     | WhisperKit (bundled `whisper-base` Russian) + iOS 26 SpeechAnalyzer fallback  |
| Voice activity (VAD)   | SileroVAD (Core ML) + energy-based fallback                                  |
| AR / Computer Vision   | ARKit Face Tracking, Vision Hand Pose, ARFaceAnchor blendshapes              |
| Audio                  | AVAudioEngine (16 kHz mono), AVAudioRecorder, pre-recorded professional voice |
| Voice prompts          | Pre-rendered Russian narrator/mascot voice (AAC `.m4a`), bundled offline      |
| DSP                    | Accelerate / vDSP (FFT, MFCC, YIN pitch detection)                           |
| On-device LLM          | Core ML 7 + MLX Swift (Qwen2.5-1.5B-Instruct-4bit)                           |
| 3D                     | RealityKit (mascot "Lyalya" as USDZ + blendshapes)                          |
| Animation              | Lottie (via SwiftPM) + native SwiftUI                                        |
| Logging                | OSLog (no `print` in code)                                                   |
| Tests                  | XCTest + Swift Testing + SnapshotTesting                                     |
| Linting                | SwiftLint (`--strict`, enforced via pre-commit hook)                         |
| Project generation     | XcodeGen (`project.yml` → `.xcodeproj`)                                      |
| Secrets / encryption   | KeychainAccess (AES-GCM-256 content-encryption keys)                         |

> No third-party trackers, ads, Firebase Analytics, or Crashlytics — these are
> incompatible with the Apple Kids Category and COPPA.

---

## Architecture

Every feature is an **independent Clean Swift (VIP) module**:

```
Features/<FeatureName>/
├── <Feature>View.swift          SwiftUI root (no business logic)
├── <Feature>Interactor.swift    Business logic, request dispatch
├── <Feature>Presenter.swift     Builds the ViewModel from a Response
├── <Feature>Router.swift        Navigation (via AppCoordinator)
├── <Feature>Models.swift        Request / Response / ViewModel types
├── <Feature>DisplayLogic.swift  View ↔ Presenter protocol
└── Workers/                     Isolated service calls
```

Project layers:

```
App/           @main, AppCoordinator, the AppContainer DI container
Core/          Base utilities, Logger, Errors, extensions
DesignSystem/  Tokens (Color/Typography/Spacing/Radius/Shadow/Motion) + HS* components
Shared/        Reusable view modifiers
Features/      Feature modules (Clean Swift VIP)
Services/      AudioService, ASRService, ARService, PermissionService,
               NotificationService, HapticService, SyncService, ContentService,
               AdaptivePlannerService, AnalyticsService, NetworkMonitor,
               DailyUsageTracker, …
Data/          Realm models, repositories, migrations (schema v12)
Content/       ContentEngine, pack schemas, seed packs (JSON)
ML/            Wrappers over WhisperKit / SileroVAD / PronunciationScorer / LocalLLM
Sync/          Firestore bridge, sync queue, conflict resolver
Analytics/     Local event bus (no external SDK)
Resources/     Assets.xcassets, audio, Core ML models, localizations
```

Import rules (arrows = allowed import direction):

```
Features ─→ DesignSystem, Shared, Core, Services (via protocols)
Services ─→ Data, ML, Sync, Core
Data      ─→ Core
Sync      ─→ Data, Core
ML        ─→ Core
DesignSystem ─→ Core
```

Features **never** import `Data`, `ML`, or `Sync` directly — only through
service protocols resolved from `AppContainer`.

---

## On-Device ML Models

All models are bundled in `HappySpeech/Resources/Models/`. There are **no
runtime downloads** from the network.

| Model                                     | Purpose                                          |
| ----------------------------------------- | ------------------------------------------------ |
| `PronunciationScorer_hissing.mlpackage`   | Scores hissing sounds (Ш, Ж, Ч, Щ)              |
| `PronunciationScorer_whistling.mlpackage` | Scores whistling sounds (С, З, Ц)               |
| `PronunciationScorer_sonants.mlpackage`   | Scores sonorant sounds (Р, Рь, Л, Ль)           |
| `PronunciationScorer_velar.mlpackage`     | Scores velar sounds (К, Г, Х)                   |
| `RussianPhonemeClassifier.mlpackage`      | Classifies 42 Russian phonemes                   |
| `Wav2Vec2RuChild.mlpackage`               | Wav2Vec2 fine-tuned for child speech             |
| `SileroVAD.mlpackage`                     | Voice activity detection                         |
| `SoundClassifier.mlpackage`               | Acoustic-environment classification              |
| `SpeakerVerification.mlpackage`           | Distinguishes "child's voice vs. parent's voice" |
| `EmotionDetection.mlpackage`              | Detects the child's emotion from voice           |
| `TonguePostureClassifier.mlpackage`       | Classifies tongue poses (from ARKit blendshapes) |
| `LLM/` (Qwen2.5-1.5B-Instruct-4bit)       | On-device LLM via MLX Swift                      |
| `Whisper/`                                | WhisperKit Russian base model                    |

---

## Requirements

- macOS 14+
- Xcode 16+ (Swift 6)
- iOS 17.0+ (deployment target)
- Test simulators: iPhone SE (3rd generation), iPhone 17 Pro
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint) — `brew install swiftlint`
- [Pillow](https://pillow.readthedocs.io/) for asset processing — `pip install Pillow`
- Node.js 20+ (for Firebase Cloud Functions, optional)

---

## Build & Run

```bash
# Clone
git clone git@github.com:antongrits/HappySpeech.git
cd HappySpeech

# Generate the .xcodeproj from project.yml
xcodegen generate

# Open in Xcode
open HappySpeech.xcodeproj

# Or build from the command line on a simulator:
xcodebuild \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  build
```

### SwiftLint

```bash
swiftlint --strict
```

All Swift files must pass `--strict` with zero violations. A pre-commit hook
runs SwiftLint on changed files automatically.

---

## Firebase Setup (optional)

Cloud sync is optional. To enable it:

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Add an iOS app with bundle ID `com.mmf.bsu.HappySpeech`.
3. Download `GoogleService-Info.plist` and place it in `HappySpeech/Resources/`.
   The file is git-ignored — every developer keeps their own.
4. Without `GoogleService-Info.plist`, the app runs fully offline with no sync.

---

## Testing

```bash
# Full suite on iPhone 17 Pro
xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# A single test class
xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:HappySpeechTests/LogorhythmicsTests
```

The project ships an extensive test suite (6000+ test cases): unit tests on
Presenters/Interactors/Workers, integration tests on services, snapshot tests on
DesignSystem components and key screens, and XCUITest UI tests. Snapshot tests
render with Reduce Motion forced on, so animated backgrounds are frozen to a
deterministic resting state.

---

## Repository Structure

```
HappySpeech/
├── HappySpeech/                       Main iOS application
│   ├── App/                           @main, AppCoordinator, DI
│   ├── Core/                          Base utilities, Logger, Errors
│   ├── DesignSystem/                  Tokens + HS* components
│   ├── Shared/                        Reusable modifiers
│   ├── Features/                      Feature modules (Clean Swift VIP)
│   ├── Services/                      Service layer
│   ├── Data/                          Realm models, migrations, repositories
│   ├── Content/                       ContentEngine, JSON packs
│   ├── ML/                            Core ML / WhisperKit / MLX wrappers
│   ├── Sync/                          Firebase bridge, queue, conflict resolver
│   ├── Analytics/                     Local event bus
│   └── Resources/                     Assets, audio, ML models, localizations
├── HappySpeechTests/                  Unit & snapshot tests
├── HappySpeechUITests/                UI tests
├── HappySpeechWidgetExtension/        "Today" home-screen widgets
├── functions/                         Firebase Cloud Functions (TypeScript)
├── docs/                              Documentation (privacy, App Store metadata)
├── scripts/                           Build & asset scripts
├── project.yml                        XcodeGen configuration
└── README.md                          This file
```

---

## Content Engine

- **Schema:** `HappySpeech/Content/Schemas/content-pack.schema.json`
- **Seed packs:** `HappySpeech/Content/Seed/pack_*.json` and `sound_*_pack.json`
  (vegetables, fruits, animals, professions, berries, trees, flowers, fish,
  logorhythmics, objects-to-describe, finger play, story-creator stimuli, and
  the per-sound articulation packs).
- **Lesson assembly:** `ContentEngine.swift` composes a `Lesson` from a pack by
  combining exercise-template builders.
- **Word → illustration mapping:** `word_manifest.json` maps each Russian word
  to a bundled `word_*` illustration asset, surfaced via `LessonContentMap`.

All packs are bundled under `Resources/Content/` and `Resources/Audio/Content/`.

---

## Localization

The app is Russian-first. All user-facing strings go through
`String(localized:)` backed by a String Catalog (`Localizable.xcstrings`).

An English string set exists as a placeholder for App Store metadata, but the
kid/parent interface is currently Russian only. The bilingual module
(`BilingualMode`) lets a child hear translations of basic words in Belarusian
(be-BY) and English (en-US) via pre-recorded professional voice clips bundled
with the app.

---

## Accessibility

- **Dynamic Type** — supported from `.small` to `.accessibilityLarge`. Every CTA
  uses `.lineLimit(nil)` + `.minimumScaleFactor(0.85)` so text never clips.
- **Reduce Motion** — animations fall back to static rendering when
  `@Environment(\.accessibilityReduceMotion) == true`.
- **VoiceOver** — labels and hints on every interactive element.
- **WCAG AA contrast** — all DesignSystem colors meet 4.5:1 for text.
- **Haptics** — custom `CHHapticEngine` patterns for feedback.
- **Touch targets** — ≥ 56 pt, per Apple HIG for kids' apps.

---

## Privacy & COPPA

- All of the child's audio recordings are processed **on-device only** and are
  never uploaded.
- The speech-growth video diary is encrypted with AES-GCM-256; the key lives in
  the Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- No third-party trackers, ads, or third-party analytics.
- All external links are gated behind a parental gate.
- The daily in-app time limit is parent-configured (internal accumulator, no iOS
  Screen Time API).
- Apple Kids Category compliant.
