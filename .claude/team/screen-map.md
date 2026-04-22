# Screen Map — HappySpeech
## Version 1.0 — 2026-04-21
## Total: 65 screens

### Legend
- [D] = Designed in Claude Design (JSX file exists in happyspeech-design/project/)
- [N] = Needs design (no JSX yet)
- [S] = State screen (empty/error/loading/offline)

---

## Circuit 0: Core / Auth (7 screens)

| # | Screen | SwiftUI View | Status |
|---|---|---|---|
| 1 | SplashScreen | SplashView | [D] |
| 2 | WelcomeScreen | WelcomeView | [D] |
| 3 | SignInScreen (Apple + email) | AuthSignInView | [N] |
| 4 | OnboardingChildName | OnboardingNameView | [N] |
| 5 | OnboardingAgeSelect | OnboardingAgeView | [N] |
| 6 | OnboardingSoundGroupSelect | OnboardingSoundView | [N] |
| 7 | OnboardingComplete | OnboardingDoneView | [N] |

---

## Circuit 1: Child (Kid) (22 screens)

| # | Screen | SwiftUI View | Status |
|---|---|---|---|
| 8 | ChildHome (mascot Lyalya + daily mission) | ChildHomeView | [D] |
| 9 | WorldMap (sound groups as islands) | WorldMapView | [D] |
| 10 | SoundGroupDetail | SoundGroupView | [N] |
| 11 | DailyMissionCard | DailyMissionView | [D] |
| 12 | LessonPlayer — WarmUp (articulation intro) | LessonWarmUpView | [N] |
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

---

## Circuit 2: AR (6 screens)

| # | Screen | SwiftUI View | Status |
|---|---|---|---|
| 30 | ARHub (entry to AR zone) | ARHubView | [N] |
| 31 | ARArticulationMirror (face + blendshape overlay) | ARMirrorView | [N] |
| 32 | ARActivity — tongue-catch | ARTongueCatchView | [N] |
| 33 | ARActivity — balloon-blow | ARBalloonView | [N] |
| 34 | ARActivity — smile-wider | ARSmileView | [N] |
| 35 | ARPermissionRequest | ARPermissionView | [S] |

---

## Circuit 3: Parent (13 screens)

| # | Screen | SwiftUI View | Status |
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
| 47 | PrivacySettings | PrivacyView | [N] |
| 48 | ParentSettings (account) | ParentSettingsView | [N] |

---

## Circuit 4: Specialist (8 screens)

| # | Screen | SwiftUI View | Status |
|---|---|---|---|
| 49 | SpecialistHome (child list, quick stats) | SpecialistHomeView | [D] |
| 50 | SpecialistChildProfile (target sound config) | SpecChildProfileView | [D] |
| 51 | SpecialistSessionReview (attempt table) | SessionReviewView | [N] |
| 52 | WaveformSpectrogram (acoustic analysis) | WaveformView | [N] |
| 53 | ManualScoring (override ASR score) | ManualScoringView | [N] |
| 54 | ProgressReport (charts, export) | ProgressReportView | [D] |
| 55 | ExportModal (PDF / CSV) | ExportView | [N] |
| 56 | SpecialistSettings | SpecSettingsView | [N] |

---

## State Screens (9 screens)

| # | Screen | When Shown | Status |
|---|---|---|---|
| 57 | LoadingScreen (app init) | App cold start | [S] |
| 58 | EmptyState — no sessions yet | Child has no history | [S] |
| 59 | EmptyState — no content packs | Offline, no packs | [S] |
| 60 | OfflineBanner | No network, sync pending | [S] |
| 61 | ErrorScreen (generic) | Unrecoverable error | [S] |
| 62 | PermissionDenied — microphone | Mic not granted | [S] |
| 63 | PermissionDenied — camera (AR) | Camera not granted | [S] |
| 64 | ModelDownloading (ASR/LLM first run) | First-run model download | [S] |
| 65 | SessionTimedOut (fatigue detection) | Planner stops session | [S] |

---

## Summary

| Circuit | Count | Designed [D] | Needs Design [N] | State [S] |
|---|---|---|---|---|
| Core/Auth | 7 | 2 | 5 | 0 |
| Child | 22 | 8 | 14 | 0 |
| AR | 6 | 0 | 5 | 1 |
| Parent | 13 | 3 | 10 | 0 |
| Specialist | 8 | 3 | 5 | 0 |
| State | 9 | 0 | 0 | 9 |
| **Total** | **65** | **16** | **39** | **10** |

**Priority design queue (Phase 1–2 Sprint 3–4):**
1. AuthSignInView (needed for Sprint 3)
2. OnboardingNameView, AgeView, SoundView, DoneView (Sprint 3)
3. LessonWarmUpView (Sprint 4)
4. DragMatchView, SortingView (Sprint 4)
5. ParentHomeView extension (already designed, needs content expansion)
