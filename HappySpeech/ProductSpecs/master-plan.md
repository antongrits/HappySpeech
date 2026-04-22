# HappySpeech Master Plan
## Version 1.0 — 2026-04-21
### Synthesized from: speech-methodology.md, speech-games-tz.md, speech-competitor-analysis.md, deep-research-report-happyspeech.md, CLAUDE.md

---

## 1. Product Vision and Scope

### What HappySpeech IS

HappySpeech is an **offline-first, Russian-language iOS speech therapy support platform** for children aged 5–8. It provides:

- A structured **child circuit** (gamified sessions, mascot "Lyalya", adaptive daily route)
- A **parent circuit** (progress dashboard, session recordings, home task recommendations, no jargon)
- A **specialist circuit** (analytics, waveform/spectrogram, manual scoring, PDF/CSV export)
- A **hidden adaptive planner** (AdaptivePlannerService — assembles daily route, tracks fatigue, spaces repetitions)
- **On-device AI** (Russian ASR, Silero VAD, pronunciation scorer, local LLM Qwen2.5-1.5B for structured decisions)
- **AR articulation** (ARKit Face Tracking — mouth open, tongue out, lip rounding, cheek puff)
- **Visual-acoustic biofeedback** (waveform + mel spectrogram overlay against reference)
- **16 game templates** covering all 8 correction stages for 4 Russian sound groups
- **6,000+ content units** generated from template × sound × stage matrix

### Honest Product Boundaries (What It Does NOT Do)

| Boundary | Reason |
|---|---|
| No medical diagnosis | Pedagogical support only — does NOT label "дислалия", "ОНР", etc. |
| No clinical outcome guarantee | Cannot promise correction in specific time |
| No full tongue tracking inside mouth | ARKit only provides external face blendshapes (tongueOut coefficient only) |
| Does not replace a live speech therapist | Recommends in-person visit for severe cases (stuttering, dysarthria, ОНР Level II and below) |
| No third-party trackers or analytics SDKs | Kids Category compliance — MetricKit + OSLog only |
| No advertising or 3rd-party in-app purchases | Kids Category compliance |
| No open external links without parental gate | Kids Category compliance |
| No real-time server-side speech scoring | All ML inference is on-device |
| No chat interface for the LLM | LLM makes structured decisions only (planner, summaries, micro-content) |

### Target Audience

- **Primary:** Children 5–8 years old (child circuit)
- **Secondary:** Parents (parent circuit — home practice coordinator)
- **Tertiary:** Speech therapists / logopedists (specialist circuit — observation and annotation tool)

### Positioning

> "HappySpeech is not just another speech therapy app — it's the only Russian-language offline-first platform combining an evidence-based correction ladder, on-device AI pronunciation scoring, AR articulation, visual-acoustic biofeedback, a parent dashboard with real analytics, and a specialist mode. No competitor has all of these simultaneously."

---

## 2. Five Phases of Work

### Phase 0 — Research & Spec Finalization (Week 1)

**Goal:** Complete all planning artifacts before any code is written.

**Deliverables:**
- `master-plan.md` (this document) — approved by user
- `screen-map.md` — ≥60 screens with status
- `~/.claude/team/backlog.md` — full backlog with P1/P2/P3 priorities
- `~/.claude/team/sprint.md` — Sprint 1 fully defined
- `~/.claude/team/ml-models.md` — model registry
- `~/.claude/team/architecture.md` — updated ADRs
- `~/.claude/team/api-contracts.md` — Realm ↔ Firestore contracts
- `project.yml` (xcodegen config — drafted, not yet generated)

**Phase DoD:**
- [ ] master-plan approved by user (Антон)
- [ ] All team artifacts at ~/.claude/team/ non-empty and consistent
- [ ] No implementation started

---

### Phase 1 — Foundation (Weeks 2–3, 2 weeks)

**Goal:** Working Xcode project, DesignSystem with Swift tokens, all layer shells, CI skeleton, AppContainer DI.

**Deliverables:**
- `project.yml` → `HappySpeech.xcodeproj` (xcodegen)
- `HappySpeech/Core/` — Logger, ErrorTypes, extensions, AppError
- `HappySpeech/DesignSystem/` — ColorTokens, TypographyTokens, SpacingTokens, RadiusTokens, MotionTokens, ThemeEnvironment, 8 base components
- `HappySpeech/App/` — AppEntry, AppCoordinator, AppContainer (DI)
- `HappySpeech/Data/` — Realm models (child profile, session, attempt, content pack), LiveChildRepository
- `HappySpeech/Services/` — protocol shells for all 11 services
- `HappySpeech/Shared/` — ViewModifiers, accessibility helpers
- `Localizable.xcstrings` — ru + en, all string keys for Foundation layer
- SwiftLint config (`.swiftlint.yml`)
- Snapshot test target configured (SnapshotTesting SPM)

**Phase DoD:**
- [ ] `xcodebuild build` passes with zero warnings
- [ ] `swiftlint --strict` passes
- [ ] DesignSystem Preview app shows all tokens in light + dark
- [ ] At least 1 snapshot test green

---

### Phase 2 — MVP (Weeks 4–6, 3 weeks)

**Goal:** Child can complete a real session. Parent can see results. Adaptive planner routes first 3 templates.

**Deliverables:**
- Auth flow (Firebase Auth + Sign in with Apple)
- Onboarding (5 screens: splash, welcome, child name, sound group selection, age)
- Child home screen with mascot Lyalya + daily mission card
- Lesson player with 3 game templates: `listen-and-choose`, `repeat-after-model`, `sorting`
- `AudioService` (AVAudioEngine 16kHz mono recording)
- `ASRService` wrapper (WhisperKit, Russian model, local inference)
- `AdaptivePlannerService` skeleton (daily route, fatigue detection)
- Parent home screen (basic: child name, last session date, streak)
- Rewards: star counter + 3 stickers unlocked
- `ContentEngine` with seed pack for sound "С" (sibilants, stages 0–3)
- Offline-first: all seed content embedded in app bundle

**Phase DoD:**
- [ ] Child can start session → complete 3 exercises → see reward screen
- [ ] Parent can log in and see child's last session summary
- [ ] ASR recognizes at least 5 Russian words correctly in test harness
- [ ] `xcodebuild test` passes (unit tests on Presenter + Interactor for 3 templates)
- [ ] Snapshot tests: light + dark for child home, lesson player, reward screen

---

### Phase 3 — Content Scale (Weeks 7–9, 3 weeks)

**Goal:** All 16 game templates implemented. All 4 sound groups seeded. Parent dashboard complete. Specialist circuit functional.

**Deliverables:**
- All 16 game template Views, Interactors, Presenters:
  `drag-and-match`, `story-completion`, `puzzle-reveal`, `memory`, `bingo`,
  `sound-hunter`, `articulation-imitation`, `visual-acoustic`, `breathing`,
  `rhythm`, `narrative-quest`, `minimal-pairs`
- Content seed packs: all 4 sound groups × stages 0–8 = 1,440+ content units
- Full parent dashboard: heatmap of attempts, audio recordings, word-error lists, weekly recommendations
- Specialist circuit: manual scoring toggle, waveform viewer, session export (PDF + CSV)
- `AdaptivePlannerService` full implementation (spaced repetition, fatigue detection, rotation rule)
- `ContentService` with downloadable content packs (Firebase Storage)
- `SyncService` full implementation (Realm → Firestore, conflict resolution, offline queue)
- `AnalyticsService` (local event bus, no external SDK)
- Notification support for daily practice reminders
- Settings screen (child, parent, specialist)

**Phase DoD:**
- [ ] All 16 templates render and accept input on iPhone SE and iPhone 17 Pro
- [ ] Content unit count ≥ 1,440 (verified by test)
- [ ] Parent can view heatmap of last 7 days
- [ ] Specialist can export PDF report for one child session
- [ ] Unit coverage ≥ 60% on all Interactors
- [ ] Snapshot coverage ≥ 80% on all Views (light + dark)

---

### Phase 4 — AR + ML + LLM (Weeks 10–11, 2 weeks)

**Goal:** ARKit articulation games live. Pronunciation scorer functional. Local LLM provides structured recommendations.

**Deliverables:**
- `ARService` — ARKit Face Tracking (tongueOut, mouthOpen, jawOpen, eyeBlink symmetry)
- AR game template `ar-activity` (tongue-catch, balloon-blow, smile-wider) + `articulation-imitation`
- `PronunciationScorerService` (Core ML .mlpackage — binary correct/incorrect per phoneme attempt)
- Silero VAD Core ML model integrated into ASR pipeline
- `LocalLLMService` (Qwen2.5-1.5B via MLC, structured JSON output only)
  - Input: structured session log (JSON)
  - Output: parent_summary (string), next_session_tasks (array), micro_story_words (array)
- `VisualAcousticView` — real-time waveform + mel spectrogram (AVAudioEngine + Accelerate/vDSP)
- ML model registry populated (`~/.claude/team/ml-models.md`)
- _workshop/scripts/ — dataset fetch, preprocess, train, convert scripts in Python

**Phase DoD:**
- [ ] AR tongue-catch game works in Simulator (face tracking mock) and on device
- [ ] PronunciationScorer returns score 0.0–1.0 for at least 3 sound targets
- [ ] LLM produces valid JSON output for parent_summary in < 3 seconds on iPhone 15+
- [ ] Visual-acoustic waveform updates in real-time < 50ms latency
- [ ] All ML models listed in ml-models.md with size, license, fallback

---

### Phase 5 — Polish + QA + App Store (Weeks 12–13, 2 weeks)

**Goal:** App Store ready. Screenshot tour automated. Diploma defense quality.

**Deliverables:**
- Full Dynamic Type audit (Small → AccessibilityLarge, all screens)
- Full VoiceOver audit (all interactive elements labeled)
- Reduced Motion support (all animations respect `@Environment(\.accessibilityReduceMotion)`)
- Light + dark theme final pass on all screens
- Screenshot tour script (`scripts/generate_screenshots.sh`) — iPhone SE 4th gen + iPhone 17 Pro
- App Store metadata: description (ru + en), keywords, age rating, privacy policy URL
- `AppPrivacyInfo.xcprivacy` — privacy manifest
- Final regression QA (UI test suite on key flows)
- Release build: zero warnings, zero lint errors
- TestFlight build uploaded

**Phase DoD:**
- [ ] Screenshot tour script generates 40+ screenshots per device (2 × 40 = 80 total)
- [ ] Zero App Store review blockers (privacy manifest, no external links without gate, no ads)
- [ ] All accessibility checks pass (Dynamic Type, VoiceOver, Reduced Motion)
- [ ] Unit test coverage ≥ 70% on Interactors/Presenters
- [ ] Snapshot test coverage ≥ 85% on Views
- [ ] Release build uploaded to TestFlight
- [ ] Diploma presentation materials ready

---

## 3. Sprint Plan (13 Sprints × 1 Week Each)

| Sprint | Week | Goal | Key Tasks | Deliverable |
|--------|------|------|-----------|-------------|
| S0 | 1 | Planning complete | master-plan, screen-map, backlog, architecture.md, api-contracts, ml-models registry | All ~/.claude/team/ artifacts populated |
| S1 | 2 | Xcode project boots | project.yml, xcodegen, Core layer, Logger, AppError, SPM dependencies | `xcodebuild build` green |
| S2 | 3 | DesignSystem + DI | ColorTokens, TypographyTokens, SpacingTokens, ThemeEnvironment, AppContainer, 8 components | DesignSystem Preview app |
| S3 | 4 | Auth + Onboarding | Firebase Auth, Sign in with Apple, 5 onboarding screens, ChildProfile Realm model | User can complete onboarding |
| S4 | 5 | Child home + 1st template | Child HomeView, MascotView, DailyMissionCard, listen-and-choose template, AudioService | Child sees home screen + plays 1 game |
| S5 | 6 | Core ASR + 2 more templates | WhisperKit integration, repeat-after-model, sorting, ContentEngine seed pack С | Full 3-template session works |
| S6 | 7 | AdaptivePlanner + Rewards | AdaptivePlannerService, RewardsView, StickerCollectionView, 3 reward sticker sets | Daily mission routes correctly |
| S7 | 8 | Templates 4–10 | drag-and-match, story-completion, puzzle-reveal, memory, bingo, sound-hunter, breathing | 10 templates functional |
| S8 | 9 | Templates 11–16 + all sound groups | articulation-imitation, visual-acoustic, rhythm, narrative-quest, minimal-pairs, ar-activity skeleton | All 16 templates functional |
| S9 | 10 | Parent dashboard + Sync | ParentHomeView, heatmap, AudioRecordingPlayer, SyncService, Firestore schema live | Parent sees child progress |
| S10 | 11 | AR + ML models | ARService, tongue-catch, balloon-blow, PronunciationScorer .mlpackage, Silero VAD | AR games on device |
| S11 | 12 | LLM + Specialist circuit | LocalLLMService, parent_summary JSON, SpecialistView, waveform viewer, PDF export | LLM produces parent summary |
| S12 | 13 | Polish + QA + App Store | Accessibility audit, screenshot tour, App Store metadata, TestFlight build | TestFlight build live |

**Milestones:**
- **M1 (S5 end):** MVP — child completes real 3-template session
- **M2 (S8 end):** Content Scale — all 16 templates + all 4 sound groups
- **M3 (S9 end):** Parent circuit complete
- **M4 (S10 end):** AR + ML on device
- **M5 (S11 end):** LLM + Specialist circuit complete
- **M6 (S12 end):** App Store submission ready + diploma materials ready

---

## 4. Modular Architecture — Dependency Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          App Layer                              │
│  App/  (AppEntry, AppCoordinator, AppContainer DI)              │
└────────────────────────┬────────────────────────────────────────┘
                         │ uses
         ┌───────────────▼───────────────────────┐
         │            Features Layer             │
         │  Features/<FeatureName>/              │
         │  (View, Interactor, Presenter,        │
         │   Router, Models, Workers)            │
         └───┬──────────────────────┬────────────┘
             │ depends on           │ depends on
    ┌────────▼────────┐   ┌────────▼──────────────┐
    │  DesignSystem   │   │  Services (protocols)  │
    │  (Tokens, Theme,│   │  AudioService          │
    │   Components)   │   │  ASRService            │
    └────────┬────────┘   │  ARService             │
             │            │  ContentService        │
    ┌────────▼────────┐   │  AdaptivePlannerService│
    │   Shared Layer  │   │  SyncService           │
    │  (Modifiers,    │   │  AnalyticsService      │
    │   Helpers,      │   │  PronunciationScorer   │
    │   ViewBuilders) │   │  LocalLLMService       │
    └────────┬────────┘   │  NotificationService   │
             │            │  HapticService         │
    ┌────────▼────────┐   └────────┬───────────────┘
    │   Core Layer    │◄───────────┘
    │  (Logger,       │
    │   AppError,     │←── ML Layer (Core ML wrappers)
    │   Extensions,   │←── Data Layer (Realm models, repos)
    │   Types)        │←── Sync Layer (Firestore bridge)
    └─────────────────┘←── Content Layer (ContentEngine, schemas)
                       ←── Analytics Layer (local event bus)

ALLOWED IMPORT DIRECTIONS:
  Features → DesignSystem, Shared, Core, Services (via protocols ONLY)
  Services → Data, ML, Sync, Core
  Data → Core
  Sync → Data, Core
  ML → Core
  DesignSystem → Core
  Content → Core
  Analytics → Core

FORBIDDEN:
  Features → Data (direct)
  Features → ML (direct)
  Features → Sync (direct)
  Any layer → Features
```

**SPM Dependencies:**

| Package | Version | Purpose |
|---|---|---|
| RealmSwift | 10.x | Local database |
| Firebase iOS SDK | 11.x | Auth, Firestore, Storage, AppCheck |
| WhisperKit | 0.9.x | On-device Russian ASR |
| swift-snapshot-testing | 1.17.x | Snapshot tests |
| MLC-LLM Swift SDK | latest | Local Qwen2.5-1.5B inference |

Note: Silero VAD and PronunciationScorer are converted .mlpackage files bundled in Resources/Models/ — no SPM package needed.

---

## 5. Screen Map (≥60 Screens)

### Legend
- [D] = Designed in Claude Design (JSX exists)
- [N] = Needs design (no JSX yet)
- [S] = State screen (empty/error/loading/offline)

### Circuit 0: Core / Auth (7 screens)

| # | Screen Name | File | Status |
|---|---|---|---|
| 1 | SplashScreen | SplashView | [D] |
| 2 | WelcomeScreen | WelcomeView | [D] |
| 3 | SignInScreen (Sign in with Apple + email) | AuthSignInView | [N] |
| 4 | OnboardingChildName | OnboardingNameView | [N] |
| 5 | OnboardingAgeSelect | OnboardingAgeView | [N] |
| 6 | OnboardingSoundGroupSelect | OnboardingSoundView | [N] |
| 7 | OnboardingComplete | OnboardingDoneView | [N] |

### Circuit 1: Child (Kid) (22 screens)

| # | Screen Name | File | Status |
|---|---|---|---|
| 8 | ChildHome (mascot + daily mission) | ChildHomeView | [D] |
| 9 | WorldMap (sound groups as islands) | WorldMapView | [D] |
| 10 | SoundGroupDetail (sound island) | SoundGroupView | [N] |
| 11 | DailyMission card | DailyMissionView | [D] |
| 12 | LessonPlayer — WarmUp (articulation) | LessonWarmUpView | [N] |
| 13 | LessonPlayer — listen-and-choose | ListenChooseView | [D] |
| 14 | LessonPlayer — repeat-after-model | RepeatModelView | [D] |
| 15 | LessonPlayer — drag-and-match | DragMatchView | [N] |
| 16 | LessonPlayer — story-completion | StoryCompletionView | [N] |
| 17 | LessonPlayer — puzzle-reveal | PuzzleRevealView | [N] |
| 18 | LessonPlayer — sorting | SortingView | [N] |
| 19 | LessonPlayer — memory | MemoryView | [N] |
| 20 | LessonPlayer — bingo | BingoView | [N] |
| 21 | LessonPlayer — sound-hunter | SoundHunterView | [N] |
| 22 | LessonPlayer — breathing | BreathingView | [N] |
| 23 | LessonPlayer — rhythm | RhythmView | [N] |
| 24 | LessonPlayer — narrative-quest | NarrativeQuestView | [N] |
| 25 | LessonPlayer — minimal-pairs | MinimalPairsView | [N] |
| 26 | LessonPlayer — visual-acoustic | VisualAcousticView | [N] |
| 27 | SessionComplete (reward + next preview) | SessionCompleteView | [D] |
| 28 | RewardCollection (stickers + stars) | RewardsView | [D] |
| 29 | StickerAlbum | StickerAlbumView | [D] |

### Circuit 2: AR (6 screens)

| # | Screen Name | File | Status |
|---|---|---|---|
| 30 | ARHub (entry to AR zone) | ARHubView | [N] |
| 31 | ARArticulationMirror (face + blendshape) | ARMirrorView | [N] |
| 32 | ARActivity — tongue-catch | ARTongueCatchView | [N] |
| 33 | ARActivity — balloon-blow | ARBalloonView | [N] |
| 34 | ARActivity — smile-wider | ARSmileView | [N] |
| 35 | ARPermissionRequest | ARPermissionView | [S] |

### Circuit 3: Parent (13 screens)

| # | Screen Name | File | Status |
|---|---|---|---|
| 36 | ParentHome (overview, streak, last session) | ParentHomeView | [D] |
| 37 | ParentChildProfile (name, age, target sounds) | ParentProfileView | [D] |
| 38 | ProgressDashboard (heatmap 7/30 days) | ProgressDashboardView | [D] |
| 39 | SessionHistory (list) | SessionHistoryView | [N] |
| 40 | SessionDetail (attempts, audio player) | SessionDetailView | [N] |
| 41 | AudioRecordingPlayer | AudioPlayerView | [N] |
| 42 | HomeTasks (today's recommendations) | HomeTasksView | [N] |
| 43 | ParentGuide (methodology explainer) | ParentGuideView | [N] |
| 44 | SoundGroupProgress (per-sound bar charts) | SoundProgressView | [N] |
| 45 | DownloadablePacks (content pack manager) | ContentPacksView | [N] |
| 46 | NotificationSettings | NotifSettingsView | [N] |
| 47 | PrivacySettings (local data, cloud sync toggle) | PrivacyView | [N] |
| 48 | ParentSettings (account, subscription) | ParentSettingsView | [N] |

### Circuit 4: Specialist (8 screens)

| # | Screen Name | File | Status |
|---|---|---|---|
| 49 | SpecialistHome (child list, quick stats) | SpecialistHomeView | [D] |
| 50 | SpecialistChildProfile (target sound config) | SpecChildProfileView | [D] |
| 51 | SpecialistSessionReview (attempt table) | SessionReviewView | [N] |
| 52 | WaveformSpectrogram (acoustic analysis) | WaveformView | [N] |
| 53 | ManualScoring (override ASR score) | ManualScoringView | [N] |
| 54 | ProgressReport (charts, export) | ProgressReportView | [D] |
| 55 | ExportModal (PDF / CSV) | ExportView | [N] |
| 56 | SpecialistSettings | SpecSettingsView | [N] |

### State Screens (9 screens)

| # | Screen Name | When Shown | Status |
|---|---|---|---|
| 57 | LoadingScreen (app init) | App cold start | [S] |
| 58 | EmptyState — no sessions yet | Child has no history | [S] |
| 59 | EmptyState — no content packs | Offline, no packs downloaded | [S] |
| 60 | OfflineBanner (persistent) | No network, sync pending | [S] |
| 61 | ErrorScreen (generic) | Unrecoverable error | [S] |
| 62 | PermissionDenied — microphone | Mic not granted | [S] |
| 63 | PermissionDenied — camera (AR) | Camera not granted | [S] |
| 64 | ModelDownloading (ASR/LLM) | First-run model download | [S] |
| 65 | SessionTimedOut (fatigue detection) | Planner stops session | [S] |

**Total: 65 screens**
**Designed in Claude Design: 20**
**Needs design: 36**
**State screens: 9**

---

## 6. Content Engine

### Schema

Content is organized as a matrix: **Sound Target × Stage × Template**

```
ContentPack
├── id: String                    // "sibilants-s-stage0-v1"
├── targetSound: SoundTarget      // .s, .sh, .r, .l, .k, etc.
├── stage: CorrectionStage        // .prep, .isolated, .syllable, .word, .phrase, .sentence, .story, .differentiation
├── templateType: TemplateType    // .listenAndChoose, .repeatAfterModel, etc.
├── difficulty: Int               // 1, 2, 3
├── wordPool: [ContentItem]       // words with audio + image paths
├── version: String
└── locale: String                // "ru"

ContentItem
├── id: String
├── word: String                  // "сани"
├── audioPath: String             // "Content/Seed/audio/sani.mp3"
├── imagePath: String             // "Content/Seed/images/sani.png"
├── targetSoundPosition: Position // .initial, .medial, .final
├── syllableCount: Int
└── phonemeTranscription: String  // "с-а-н-и"
```

### Content Dimension Matrix

| Dimension | Values | Count |
|---|---|---|
| Sound targets | С, Сь, З, Зь, Ц, Ш, Ж, Ч, Щ, Л, Ль, Р, Рь, К, Г, Х + 6 contrast pairs | 22 |
| Correction stages | prep, isolated, syllable, word-initial, word-medial, word-final, phrase, sentence, story, differentiation | 10 |
| Template types | 16 templates × 3 difficulty levels | 48 |
| Words per sound per stage | ~30–50 words | 40 avg |

**Calculation:**
- Core training content: 22 sounds × 10 stages × 3 difficulty levels = **660 content pack slots**
- Words per slot: ~10 words used per session, 30–40 in pool → ~40 avg
- **Total content items: 22 × 10 × 40 = 8,800 word-image-audio triplets**
- **Total sessions possible: 22 × 10 × 3 × 8 templates (primary) = 5,280+ unique sessions**

### Seed Pack (Bundled in App)

For MVP launch the app bundles:
- Sound С (sibilants): stages 0–5, templates: listen-and-choose, repeat-after-model, sorting, drag-and-match → 6 packs × ~40 words = **240 seed items**
- Sound Ш (shibilants): stages 0–3 → 4 packs × 40 = **160 seed items**
- Sound Р (sonors): stages 0–2 → 3 packs × 40 = **120 seed items**
- **MVP seed total: ~520 items**

Additional packs downloaded via Firebase Storage (ContentPacksView).

### File sizes
- Audio (16-bit 16kHz WAV → MP3 64kbps): ~15 KB per word
- Image (PNG 512×512 → WebP): ~25 KB per image
- Per content item: ~40 KB
- MVP seed bundle: 520 × 40 KB = **~21 MB**
- Full content (8,800 items): ~350 MB (delivered as downloadable packs, not bundled)

---

## 7. Data Architecture

### Realm Models (Local — Device Source of Truth)

| Model | Key Fields | Purpose |
|---|---|---|
| ChildProfile | id, name, age, targetSounds, createdAt | Child identity |
| ParentProfile | id, firebaseUID, childIds, settings | Parent account |
| Session | id, childId, date, templateType, targetSound, stage, duration | Session record |
| Attempt | id, sessionId, word, audioPath, asrScore, manualScore, isCorrect, timestamp | Per-attempt result |
| ContentPackMeta | id, soundTarget, stage, templateType, version, isDownloaded, lastSyncAt | Pack registry |
| ProgressEntry | id, childId, soundTarget, stage, date, successRate, sessionCount | Daily progress |
| AdaptivePlan | id, childId, date, plannedRoute: [RouteStep], actualRoute: [RouteStep], fatigueLevel | Daily plan |
| RewardState | id, childId, stars, unlockedStickers: [String], lastRewardAt | Reward tracking |
| SyncQueueItem | id, entityType, entityId, operation, createdAt, syncedAt | Offline queue |

### Firestore Collections

```
/users/{userId}
  - uid, email, role (parent | specialist)
  - createdAt, lastActiveAt

/users/{userId}/children/{childId}
  - name, age, targetSounds, createdAt
  - progressSummary (denormalized for fast reads)

/users/{userId}/children/{childId}/sessions/{sessionId}
  - date, templateType, targetSound, stage, duration
  - summary: { totalAttempts, correctAttempts, successRate }

/users/{userId}/children/{childId}/sessions/{sessionId}/attempts/{attemptId}
  - word, asrScore, manualScore, isCorrect, timestamp
  - audioStoragePath (Firebase Storage reference)

/users/{userId}/children/{childId}/progress/{soundTarget}
  - stageProgress: { prep: {done, rate}, isolated: {done, rate}, ... }
  - lastUpdatedAt

/contentPacks/{packId}
  - soundTarget, stage, templateType, version, storageUrl, sizeBytes
  - updatedAt (for version-based invalidation)

/specialists/{specialistId}
  - linkedChildIds, clinicName
```

### Sync Flow

```
Write (offline-first):
  1. Write to Realm immediately (optimistic)
  2. Append SyncQueueItem to Realm
  3. When network available: SyncService drains queue → Firestore write
  4. On Firestore write success: mark SyncQueueItem.syncedAt

Read (cache-first):
  1. Read from Realm (always, instant)
  2. SyncService subscribes to Firestore changes (when online)
  3. On conflict: Firestore timestamp wins for progress; local wins for AdaptivePlan

Deletion / Export (GDPR-adjacent):
  1. Parent taps "Delete data" → local Realm objects deleted + Firestore delete queued
  2. Audio files: Firebase Storage delete queued
  3. Export: generate CSV/PDF from Realm data locally (no server roundtrip)
```

### Firebase Security Rules (summary)

```
users/{userId}: read/write if request.auth.uid == userId
users/{userId}/children/**: read/write if parent owns userId
                           OR specialist has childId in linkedChildIds
contentPacks/**:  read if authenticated
                  write only via Cloud Functions (admin)
```

---

## 8. ML Layer

### Model Registry

| Model | Task | License | Size (on-device) | Fallback |
|---|---|---|---|---|
| GigaAM-v3 ONNX (via sherpa-onnx) | Russian ASR (primary) | Apache 2.0 | ~300 MB | WhisperKit |
| WhisperKit (whisper-tiny) | Russian ASR (fallback) | MIT | ~150 MB | System AVSpeechRecognizer (Russian, online only) |
| Silero VAD | Voice Activity Detection | MIT | ~2 MB | AVAudioEngine amplitude threshold |
| PronunciationScorer (custom) | Binary correct/incorrect per phoneme | Proprietary (trained in-house) | ~5 MB | None (ASR confidence score used) |
| Qwen2.5-1.5B-Instruct (MLC) | Structured decisions: planner, summaries | Apache 2.0 | ~950 MB | Rule-based fallback (no LLM) |

**Note on GigaAM vs WhisperKit decision:**
GigaAM-v3 is the primary choice because it outperforms Whisper-large-v3 on Russian benchmarks and provides word-level timestamps. WhisperKit is the fallback. Both are implemented — PronunciationScorerService checks which model is active. This decision is logged in `~/.claude/team/decisions.md`.

### Data Pipeline (_workshop/)

```
Phase 1 — Dataset Collection (ml-data-engineer):
  Sources:
    - Mozilla Common Voice 17.0 (RU) — ~500h adult speech
    - Golos corpus (OpenSLR) — ~1,000h Russian diverse
    - FLEURS (RU) — 10h curated Russian
    - EmoChildRu — Russian children's emotional speech
    - CHILDRU corpus — Russian children speech
    - Custom micro-corpus (100–200 utterances, logopedist-annotated)
  
  Scripts:
    _workshop/scripts/01_fetch_datasets.py   — download all sources
    _workshop/scripts/02_normalize_audio.py  — resample to 16kHz mono WAV
    _workshop/scripts/03_split_train_val.py  — 80/10/10 split
    _workshop/scripts/04_filter_children.py  — isolate child-speaker utterances

Phase 2 — Model Training (ml-trainer):
  _workshop/scripts/05_finetune_asr.py       — fine-tune GigaAM on child speech corpus
  _workshop/scripts/06_train_vad.py          — validate Silero VAD on corpus
  _workshop/scripts/07_train_scorer.py       — train binary pronunciation scorer (CNN)
  _workshop/scripts/08_convert_coreml.py     — CoreML conversion via coremltools
  _workshop/scripts/09_validate_model.py     — accuracy/latency benchmarks

Phase 3 — Asset Preparation:
  _workshop/scripts/10_record_reference.py   — process logopedist reference recordings
  _workshop/scripts/11_generate_content_meta.py — build ContentPack JSON from word lists
  _workshop/scripts/12_screenshot_tour.sh    — run screenshot tour via xcodebuild
```

### Core ML Conversion

All models converted to `.mlpackage` format:
- `SileroVAD.mlpackage` → `HappySpeech/Resources/Models/`
- `PronunciationScorer.mlpackage` → `HappySpeech/Resources/Models/`
- GigaAM weights loaded via sherpa-onnx framework (not Core ML — ONNX runtime)
- Qwen2.5-1.5B loaded via MLC LLM Swift SDK (weights downloaded on first run, ~950MB)

### Model Storage

- In-repo (git): `SileroVAD.mlpackage` (2 MB), `PronunciationScorer.mlpackage` (5 MB)
- Downloaded on first run: Qwen2.5-1.5B weights (950 MB via MLC model hub)
- Downloaded on first run: GigaAM ONNX weights (300 MB via Firebase Storage)
- _workshop/models/ — training checkpoints, NEVER committed to git

---

## 9. LLM Integration

Qwen2.5-1.5B-Instruct runs on-device via MLC LLM Swift SDK. It has **no chat interface**. It is invoked only by `LocalLLMService` with structured prompts and returns JSON.

### Decision 1: Parent Summary Generator

**Trigger:** End of child session  
**Input JSON:**
```json
{
  "child_name": "Миша",
  "target_sound": "Р",
  "stage": "word",
  "total_attempts": 12,
  "correct_attempts": 9,
  "error_words": ["ворона", "гараж"],
  "session_duration_sec": 480
}
```
**Output JSON:**
```json
{
  "parent_summary": "Миша сегодня тренировал звук Р в словах. Из 12 попыток — 9 правильных (75%). Слова «ворона» и «гараж» пока даются трудно — повторите их дома.",
  "home_task": "Произнесите вместе с Мишей 3 раза: ворона, гараж, огород."
}
```

### Decision 2: Next Session Route Planner

**Trigger:** AdaptivePlannerService requests next route  
**Input:** Progress history (JSON), fatigue flag, sound target, stage  
**Output:** Array of RouteStep JSON objects (templateType, difficulty, wordCount)

### Decision 3: Micro-Story Generator

**Trigger:** narrative-quest template needs a new story  
**Input:** target_sound, stage, age, word_pool (10 words)  
**Output:** JSON with story_text (3–5 sentences) and gap_positions

### Decision 4: Logopedist Recommendation

**Trigger:** Specialist exports report  
**Input:** aggregated session data (30 days)  
**Output:** Natural language paragraph for PDF report (Russian)

### LLM Fallback

If Qwen2.5-1.5B is not yet downloaded or device < iPhone 12:
- Parent Summary: template string substitution (rule-based)
- Route Planner: static priority table by sound/stage
- Micro-Story: pre-written story pool (20 stories bundled)
- Logopedist Recommendation: templated paragraph

---

## 10. Python Tooling (_workshop/scripts/)

| Script | Purpose | Input | Output |
|---|---|---|---|
| `01_fetch_datasets.py` | Download Common Voice RU, Golos, FLEURS, EmoChildRu | Config YAML | Raw audio in _workshop/datasets/raw/ |
| `02_normalize_audio.py` | Resample to 16kHz mono WAV, normalize RMS | datasets/raw/ | datasets/clean/ |
| `03_split_train_val.py` | 80/10/10 train/val/test split, stratified by speaker | datasets/clean/ | datasets/splits/ |
| `04_filter_children.py` | Filter for child-speaker utterances (age metadata) | datasets/clean/ | datasets/children/ |
| `05_finetune_asr.py` | Fine-tune GigaAM on Russian child speech (MPS on Mac Apple Silicon) | datasets/children/ | models/train/gigaam_child/ |
| `06_train_scorer.py` | Train binary CNN pronunciation scorer on logopedist-annotated micro-corpus | micro-corpus/ | models/train/scorer/ |
| `07_convert_coreml.py` | Convert scorer PyTorch → Core ML .mlpackage (coremltools) | models/train/scorer/ | models/converted/PronunciationScorer.mlpackage |
| `08_convert_onnx_gigaam.py` | Export GigaAM to ONNX format for sherpa-onnx runtime | models/train/gigaam_child/ | models/converted/gigaam_child.onnx |
| `09_validate_models.py` | Accuracy + latency benchmarks for all models | models/converted/ | logs/model_benchmarks.csv |
| `10_record_reference_process.py` | Normalize and segment logopedist reference recordings | raw recordings MP3 | datasets/references/ (16kHz WAV) |
| `11_generate_content_meta.py` | Build ContentPack JSON from word lists + phoneme G2P | word_lists/*.csv | Content/Seed/*.json |
| `12_build_seed_pack.py` | Assemble MVP seed pack: audio + images + JSON | datasets/references/, images/ | HappySpeech/Content/Seed/ |
| `13_screenshot_tour.sh` | Run xcodebuild UI test + capture screenshots | Simulator IDs | _workshop/screenshots/ |
| `14_check_content_counts.py` | Validate content unit counts against spec (≥8,800) | Content/Seed/ | logs/content_audit.txt |
| `15_export_localization.py` | Extract all string keys from xcstrings, check ru/en parity | Localizable.xcstrings | logs/localization_audit.txt |

---

## 11. Design System

### Tokens (DesignSystem/Tokens/)

**Colors (ColorTokens.swift)**

| Token | Light | Dark | Use |
|---|---|---|---|
| primary | #FF6B6B (coral) | #FF8585 | Primary CTA, mascot accent |
| primaryDim | #FF6B6B40 | #FF858540 | Pressed state |
| secondary | #4ECDC4 (teal) | #6EE7DF | Secondary actions, progress |
| background | #FFFBF5 | #1A1A2E | App background |
| surface | #FFFFFF | #252540 | Cards, modals |
| surfaceElevated | #F5F0E8 | #2E2E4A | Elevated cards |
| text | #2D2D3A | #F0F0F5 | Primary text |
| textSecondary | #6B6B80 | #A0A0B8 | Secondary text, labels |
| success | #51CF66 | #69E87A | Correct answer, progress |
| warning | #FFD43B | #FFE566 | Almost correct, attention |
| error | #FF6B6B | #FF8585 | Errors (kid-safe: never harsh red) |
| reward | #FFD700 | #FFE44D | Stars, rewards |

**Typography (TypographyTokens.swift)**

| Token | Font | Size | Weight | Use |
|---|---|---|---|---|
| kidDisplay | Rounded (SF Rounded) | 28–34 | Bold | Child screen headers |
| kidTitle | SF Rounded | 22–26 | Semibold | Game titles |
| kidBody | SF Rounded | 17–20 | Regular | Game instructions |
| kidButton | SF Rounded | 17 | Bold | CTA labels |
| parentTitle | SF Pro | 22 | Semibold | Parent headers |
| parentBody | SF Pro | 15–17 | Regular | Parent text |
| specMono | SF Mono | 13 | Regular | Waveform labels, debug |

All font sizes use `@ScaledMetric` for Dynamic Type support (Small → AccessibilityLarge).

**Spacing (SpacingTokens.swift)**

| Token | Value | Use |
|---|---|---|
| xs | 4 | Micro gaps |
| sm | 8 | Component internal padding |
| md | 16 | Standard padding |
| lg | 24 | Section spacing |
| xl | 32 | Screen margins |
| xxl | 48 | Large section separators |

**Radius (RadiusTokens.swift):** xs=4, sm=8, md=12, lg=20, xl=32, pill=999

**Motion (MotionTokens.swift):**

| Token | Duration | Curve | Use |
|---|---|---|---|
| microFeedback | 0.15s | easeOut | Button press |
| standardTransition | 0.3s | spring(0.8) | Screen transitions |
| rewardBurst | 0.6s | spring(0.5) | Reward animations |
| mascotIdle | 2.0s | easeInOut, repeat | Mascot breathing loop |

All animations check `@Environment(\.accessibilityReduceMotion)` — if true, use crossfade (0.2s) instead.

### Base Components (DesignSystem/Components/)

1. `HSButton` — primary/secondary/ghost variants, loading state, haptic feedback
2. `HSCard` — surface card with shadow, elevation levels 1–3
3. `HSProgressBar` — animated, colored by stage
4. `HSMascotView` — Lyalya mascot with emotion states (happy, thinking, cheering, sad-gentle)
5. `HSAudioWaveform` — real-time waveform display
6. `HSSticker` — sticker card with unlock animation
7. `HSBadge` — star/award badge with count
8. `HSToast` — kid-safe feedback toast (no "wrong!" — only positive/gentle)

### Themes

Two themes: `.light`, `.dark`. Both tested via snapshot tests. Theme provided via `@Environment(\.colorScheme)` + `ThemeEnvironment` custom key.

---

## 12. AR Subsystem

### Supported ARKit Blendshapes (honest capabilities)

ARKit Face Tracking provides 52 blendshapes. HappySpeech uses:
- `tongueOut` — tongue visible outside mouth (0.0–1.0)
- `jawOpen` — mouth opening degree
- `mouthFunnel` — lip rounding (for ХО/ШО sounds)
- `mouthSmileLeft` + `mouthSmileRight` — smile width
- `cheekPuff` — cheek inflation

**NOT tracked (honest limitations):**
- Tongue tip position inside mouth (up/down/lateral)
- Teeth contact with tongue
- Velum (soft palate) position
- Precise tongue shape

### 10 AR Scenarios

| # | Scenario | Blendshape Used | Sound Target | Template |
|---|---|---|---|---|
| 1 | Tongue Catch — catch falling objects with tongue | tongueOut > 0.6 | Р, Л | ar-activity |
| 2 | Balloon Blow — inflate balloon by exhaling | jawOpen + audio amplitude | All sounds | ar-activity |
| 3 | Smile Wider — widen smile to match target | mouthSmileLeft+Right | С, З (smile position) | articulation-imitation |
| 4 | Lip Tunnel — round lips into tunnel | mouthFunnel > 0.5 | Ш, Ж, Щ | articulation-imitation |
| 5 | Open Cave — open jaw to target angle | jawOpen target 0.7 | Vowel prep, all sounds | articulation-imitation |
| 6 | Cheek Puff — puff cheeks for breath control | cheekPuff > 0.7 | Breathing exercise | ar-activity |
| 7 | Tongue Flick — quick tongue out and in (rhythm) | tongueOut pulse | Р (motor prep) | ar-activity |
| 8 | Mirror Mirror — free articulation practice with face overlay | All | Any | ARMirrorView |
| 9 | Target Hold — hold articulation position for N seconds | any blendshape | Target-specific | articulation-imitation |
| 10 | Two-Position Switch — alternate between 2 positions | smile ↔ funnel | С↔Ш differentiation | articulation-imitation |

### AR Technical Constraints

- Minimum device: iPhone 12 (TrueDepth camera required)
- If TrueDepth unavailable: AR features hidden, replaced with video demo
- Lighting: warns user if environment too dark for face tracking
- Privacy: no video recording stored; only blendshape coefficient arrays stored per attempt
- Session length: AR sessions capped at 2 minutes (fatigue, camera eye strain)

---

## 13. Test Strategy

### Unit Tests (HappySpeechTests — XCTest + Swift Testing)

**Target: ≥ 70% line coverage on Interactors and Presenters**

| Test Suite | Files | Coverage Target |
|---|---|---|
| ListenChooseInteractorTests | ListenChooseInteractor | 90% |
| RepeatModelInteractorTests | RepeatAfterModelInteractor | 90% |
| AdaptivePlannerTests | AdaptivePlannerService | 85% |
| ContentEngineTests | ContentEngine | 85% |
| SyncServiceTests | SyncService | 80% |
| LocalLLMServiceTests | LocalLLMService JSON parsing | 90% |
| RealmRepositoryTests | ChildRepository, SessionRepository | 75% |
| AllPresenterTests | All 16 template Presenters | 75% |

**Mocking strategy:** All Services have protocol + Mock implementation. AppContainer.preview() provides Mocks.

### Snapshot Tests (SnapshotTesting)

**Target: ≥ 85% of View files have snapshots**

Each View tested in:
- iPhone SE 4th gen (375×667pt), light
- iPhone SE 4th gen, dark
- iPhone 17 Pro (393×852pt), light
- iPhone 17 Pro, dark
- Dynamic Type: `.accessibilityLarge`, light

**Key snapshot suites:**
- DesignSystemSnapshotTests (all 8 components × 5 configs)
- ChildCircuitSnapshotTests (22 screens × 5 configs)
- ParentCircuitSnapshotTests (13 screens × 5 configs)
- StateScreenSnapshotTests (9 state screens × 5 configs)

Total target snapshot count: **44 screens × 5 configs = 220 snapshots**

### Integration Tests

- Firebase Auth integration (TestFirebase project)
- Realm migration tests (schema version upgrade)
- ContentPack loading tests (from bundle + from download)
- ASR smoke test (known Russian word → expected transcript)

### UI Tests (HappySpeechUITests — XCTest)

Key user flows tested end-to-end:
1. Onboarding flow (5 steps → child home)
2. Complete 1 session (listen-and-choose, 8 cards → reward screen)
3. Parent views child progress (home → session detail → audio player)
4. Specialist exports PDF (session review → export)

### Screenshot Tour

Script: `scripts/generate_screenshots.sh`
- Devices: iPhone SE 4th gen + iPhone 17 Pro
- Language: Russian
- Captures: 40 key screens per device = **80 total App Store screenshots**
- Output directory: `_workshop/screenshots/`
- Command: `./scripts/generate_screenshots.sh SE "iPhone SE (4th generation)" && ./scripts/generate_screenshots.sh Pro "iPhone 17 Pro"`

---

## 14. Screenshot Tour Specification

### Screenshot List (40 per device)

| # | Screen | Purpose |
|---|---|---|
| 1–5 | Onboarding (welcome → complete) | App Store preview |
| 6 | ChildHome with mascot | App Store hero |
| 7 | WorldMap | Feature showcase |
| 8–12 | 5 different lesson templates in progress | Feature showcase |
| 13 | SessionComplete with reward | Reward system |
| 14 | StickerAlbum (partial) | Gamification |
| 15–16 | AR Tongue Catch + AR Mirror | AR feature |
| 17–18 | VisualAcoustic (waveform + target overlay) | Unique feature |
| 19 | BreathingView animated | Breathing exercises |
| 20 | ParentHome | Parent circuit |
| 21 | ProgressDashboard (heatmap) | Analytics |
| 22–23 | SessionDetail + AudioPlayer | Session review |
| 24 | HomeTasks | Parent recommendations |
| 25 | SpecialistSessionReview | Specialist circuit |
| 26 | WaveformSpectrogram | Expert feature |
| 27 | ExportModal | PDF export |
| 28–30 | 3 game templates (different sounds) | Content variety |
| 31–35 | 5 reward screens / stickers unlocking | Engagement |
| 36–40 | Dark mode variants of 5 key screens | Dark mode support |

---

## 15. Sprint Plan with Milestones (Detailed)

See Section 3 for full sprint table.

**Key Gate Criteria:**

- **Gate 1 (After S2):** DesignSystem compiles, Preview shows all tokens. iOS Lead sign-off.
- **Gate 2 (After S5 — M1 MVP):** Child completes 3-template session. Parent sees basic dashboard. CTO demos to user.
- **Gate 3 (After S8 — M2 Content Scale):** All 16 templates pass smoke test. Content audit confirms ≥1,440 units.
- **Gate 4 (After S9 — M3 Parent):** Parent dashboard shows heatmap + recording player. Sync round-trip tested.
- **Gate 5 (After S10 — M4 AR+ML):** AR tongue-catch demo on physical iPhone 12+. PronunciationScorer returns scores.
- **Gate 6 (After S11 — M5 LLM):** LLM produces valid parent summary JSON in < 3s.
- **Gate 7 (After S12 — M6 App Store):** TestFlight build uploaded. Screenshot tour script generates 80 screenshots.

---

## 16. Success Metrics and DoD per Phase

### Phase 0 DoD
- [ ] master-plan.md exists and approved
- [ ] All ~/.claude/team/ artifacts populated with real content
- [ ] screen-map.md has ≥60 screens with correct status
- [ ] No Xcode project exists yet (planning only)

### Phase 1 DoD
- [ ] `xcodebuild build` passes, 0 warnings
- [ ] `swiftlint --strict` passes
- [ ] DesignSystem token preview renders in Simulator
- [ ] All 11 Service protocols defined (no implementations yet, except LiveAudioService)

### Phase 2 DoD (MVP)
- [ ] Child completes a 3-template session from onboarding through reward screen
- [ ] Session data written to Realm
- [ ] Parent can log in and see the session record
- [ ] Unit test coverage on MVP interactors ≥ 60%
- [ ] 0 crash in 10 consecutive sessions in Simulator

### Phase 3 DoD (Content Scale)
- [ ] All 16 templates smoke-tested (checklist in test-results.md)
- [ ] Content unit count ≥ 1,440 (script 14_check_content_counts.py passes)
- [ ] Parent heatmap shows data for mock 7-day history
- [ ] Specialist exports PDF without crash
- [ ] Unit coverage on all interactors ≥ 60%
- [ ] Snapshot coverage on all views ≥ 80%

### Phase 4 DoD (AR+ML)
- [ ] AR tongue-catch achieves > 5 correct triggers in 60 sec on test device
- [ ] PronunciationScorer latency < 200ms per attempt
- [ ] Silero VAD correctly detects speech start in 95% of test utterances
- [ ] GigaAM/WhisperKit WER < 15% on internal 50-utterance Russian test set
- [ ] All models listed in ml-models.md with verified checksums

### Phase 5 DoD (App Store)
- [ ] 0 App Store review blockers (validated against Apple App Review Guidelines 4.2, 5.1.4)
- [ ] Privacy manifest (AppPrivacyInfo.xcprivacy) complete
- [ ] Screenshot tour generates 80 screenshots without crash
- [ ] Accessibility: Dynamic Type audit passes for all 65 screens
- [ ] VoiceOver: all interactive elements have accessibility labels
- [ ] TestFlight build uploaded and opens without crash on iPhone SE + iPhone 17 Pro
- [ ] Unit test coverage ≥ 70%
- [ ] Snapshot test coverage ≥ 85%
- [ ] Diploma presentation deck includes: architecture diagram, demo video, ML pipeline, content matrix

---

## 17. Risk Register

| # | Risk | Probability | Impact | Mitigation |
|---|---|---|---|---|
| R1 | GigaAM ONNX integration fails on iOS (sherpa-onnx build issues) | Medium | High | WhisperKit is a proven fallback; implement both in parallel; test on device by S10 |
| R2 | Qwen2.5-1.5B download (950MB) exceeds user patience / storage | High | Medium | Show clear onboarding download screen; make LLM optional (rule-based fallback fully functional); lazy download after first session |
| R3 | ARKit face tracking unavailable on target devices (no TrueDepth) | Medium | Medium | AR features gracefully degraded; video demo substitutes; clearly documented in product spec |
| R4 | PronunciationScorer accuracy too low for child speech | High | High | Start with binary (correct/incorrect) only; collect child speech micro-corpus early; use ASR confidence as proxy until trained scorer ready |
| R5 | Realm schema migration breaks existing data | Low | High | Version all schema changes; test migration in dedicated MigrationTests target; keep rollback schema |
| R6 | Firebase Firestore costs exceed budget (Kids category, many users) | Low | Medium | Implement aggressive local-first caching; batch writes in SyncService; monitor usage with Firebase console |
| R7 | App Store Kids Category review rejects app | Medium | Critical | Strict privacy manifest; no external links without gate; no ads; no analytics SDK; legal review of "no medical diagnosis" disclaimer |
| R8 | Content seed pack too small for meaningful demo (diploma defense) | Low | High | MVP seed: 520 items minimum; script 14 validates count; expand to С+Ш+Р before Gate 2 |
| R9 | Dynamic Type breaks layouts at AccessibilityLarge | Medium | Medium | All text uses .lineLimit(nil) + .minimumScaleFactor(0.85); run DT audit as pre-Phase-5 gate |
| R10 | Diploma timeline slips due to ML training data shortage | High | High | Start dataset collection (S0–S1) in parallel with code; micro-corpus with logopedist is top priority |

---

## 18. Build / Test / Screenshot Command Reference

```bash
# Install tools (once)
brew install xcodegen swiftlint

# Generate Xcode project
cd /Users/antongric/Downloads/HappySpeech
xcodegen generate

# Open in Xcode
open HappySpeech.xcodeproj

# Build (iPhone 17 Pro Simulator)
xcodebuild -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Build (iPhone SE Simulator)
xcodebuild -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone SE (4th generation)' \
  build

# Run unit + snapshot tests
xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -testPlan UnitTests

# Run snapshot tests only
xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:HappySpeechTests/SnapshotTests

# Run linter
swiftlint --strict

# Screenshot tour (both devices)
./scripts/generate_screenshots.sh

# Check content counts
python3 _workshop/scripts/14_check_content_counts.py

# Validate localization
python3 _workshop/scripts/15_export_localization.py

# Fetch ML datasets (run in _workshop/)
cd /Users/antongric/Downloads/HappySpeech/_workshop
python3 scripts/01_fetch_datasets.py

# Convert model to Core ML
python3 scripts/07_convert_coreml.py \
  --input models/train/scorer/best.pth \
  --output models/converted/PronunciationScorer.mlpackage

# Validate models
python3 scripts/09_validate_models.py

# Archive for App Store (requires signing configured)
xcodebuild archive \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -archivePath build/HappySpeech.xcarchive \
  CODE_SIGN_IDENTITY="Apple Distribution"
```

---

## Appendix A: Speech Methodology Summary

Source: `HappySpeech/ResearchDocs/speech-methodology.md`

**4 Sound Groups:**
1. Sibilants: С, Сь, З, Зь, Ц
2. Shibilants: Ш, Ж, Ч, Щ
3. Sonors: Л, Ль, Р, Рь
4. Dorsals: К, Кь, Г, Гь, Х, Хь

**10 Correction Stages per Sound:**
0. Articulation preparation
1. Isolated sound
2. Syllables (direct → reverse → clusters)
3. Words — initial position
4. Words — medial position
5. Words — final position
6. Phrases (2–3 word combinations)
7. Sentences (3–5 words)
8. Stories / connected speech
9. Differentiation (contrast pairs: С–Ш, Р–Л, З–Ж, etc.)

**Session Structure (anti-fatigue rotation rule):**
- Active (speak) → Passive (listen/choose) → Motor (AR/breathing) → Active
- Max session length: 7–9 min (age 5), 10–12 min (age 6), 12–14 min (age 7), 14–15 min (age 8)

**Child-safe feedback (forbidden phrases):**
- "Неправильно" without retry option
- "Это просто, почему ты не можешь?"
- Any comparison to other children

---

## Appendix B: Competitor Differentiators

Source: `HappySpeech/ResearchDocs/speech-competitor-analysis.md`

**Top 5 features no competitor has simultaneously:**
1. Russian-first on-device ASR (GigaAM) — no competitor
2. Visual-acoustic biofeedback (waveform vs reference) — no competitor
3. AR articulation with ARKit blendshapes — no competitor
4. Specialist mode with waveform + manual scoring — only Articulation Station (English only)
5. Differentiation of mixed sounds (С–Ш, Р–Л) as systematic feature — no Russian competitor

**Strategic position:** Don't copy Логопотам's breadth (loses depth). Don't copy Миры Ави's game-count approach (lacks analytics). Match Articulation Station's methodological rigor but make it Russian-first and child-friendly.

---

*Master Plan v1.0 — Compiled by CTO. Awaiting user approval before implementation begins.*
*All agents: speech-methodologist, speech-analyst, designer-ui, ios-lead, ml-trainer, sound-curator, backend-lead, qa-lead contributed to this document.*
