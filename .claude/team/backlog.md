# Product Backlog — HappySpeech
## Version 2.0 — 2026-04-22 (PM audit: status updated from code inspection)

---

## COMPLETED (Sprints 1-11 code done)

| ID | Title | Sprint | Status |
|----|-------|--------|--------|
| B-001 | Xcode project via xcodegen | S1 | DONE |
| B-002 | Core layer: HSLogger, AppError, extensions, KeychainStore, types | S1 | DONE |
| B-003 | DesignSystem: 5 token files | S2 | DONE |
| B-004 | DesignSystem: 12+ base components | S2 | DONE |
| B-005 | AppContainer DI, Service protocols | S2 | DONE |
| B-006 | Firebase Auth + Sign in with Apple (AuthSignInView VIP) | S3 | DONE |
| B-007 | Onboarding 5-screen flow (full VIP) | S3 | DONE |
| B-008 | Realm models (RealmModels, Repos, RealmActor) | S3 | DONE |
| B-009 | ChildHomeView | S4 | DONE |
| B-010 | listen-and-choose VIP | S4 | DONE |
| B-011 | AudioService (241 lines, AVAudioEngine 16kHz) | S4 | DONE |
| B-012 | WhisperKit integration (ASRServiceLive) | S5 | DONE |
| B-013 | repeat-after-model VIP | S5 | DONE |
| B-014 | sorting VIP | S5 | DONE |
| B-015 | ContentEngine + seed pack S (sound_s_pack.json) | S5 | DONE |
| B-017 | RewardsView VIP | S6 | DONE |
| B-018 | SessionComplete VIP | S5 | DONE |
| B-019 | drag-and-match VIP | S7 | DONE |
| B-020 | story-completion VIP | S7 | DONE |
| B-021 | puzzle-reveal VIP | S7 | DONE |
| B-022 | memory VIP | S7 | DONE |
| B-023 | bingo VIP | S7 | DONE |
| B-024 | sound-hunter VIP | S7 | DONE |
| B-025 | breathing VIP | S7 | DONE |
| B-026 | articulation-imitation VIP | S8 | DONE |
| B-027 | visual-acoustic VIP | S8 | DONE |
| B-028 | rhythm VIP | S8 | DONE |
| B-029 | narrative-quest VIP | S8 | DONE |
| B-030 | minimal-pairs VIP | S8 | DONE |
| B-031 | ar-activity VIP | S8 | DONE |
| B-033 | ParentHomeView | S9 | DONE |
| B-034 | ProgressDashboard VIP | S9 | DONE |
| B-035a | SessionHistory VIP | S9 | DONE |
| B-035b | SyncService + OfflineQueueManager | S9 | DONE |
| B-037 | ARZone VIP (ARKit blendshape extraction) | S10 | DONE |
| B-040 | SileroVAD wrapper (SileroVAD.swift) | S10 | DONE |
| B-041a | PronunciationScorer wrapper (PronunciationScorer.swift) | S10 | DONE |
| B-042 | LocalLLMService (MLX Swift, Qwen2.5-1.5B) | S11 | DONE |
| B-043 | LLMDecisionService full (429 lines) + RuleBasedDecisionService | S11 | DONE |
| B-044 | Specialist VIP | S11 | DONE |
| B-056 | HomeTasks VIP | S9 | DONE |
| B-063 | AnalyticsService event bus | S6 | DONE |
| B-065 | WorldMap VIP | S7 | DONE |
| B-067 | ARZone hub + VIP | S10 | DONE |
| B-068 | LLMDecisionServiceProtocol (506 lines) + LLMPrompts | S11 | DONE |

---

## P1 — Sprint 12 Critical Path (must complete for diploma)

| ID | Title | Owner | Status |
|----|-------|-------|--------|
| B-016 | AdaptivePlannerService (daily route, spaced repetition, fatigue) | ios-dev-arch | TODO |
| B-060 | NotificationService + daily reminder | ios-dev-arch | TODO |
| B-032a | Content pack: Sh (shibilant) stages 0-5, >=200 items | speech-content-curator | TODO |
| B-032b | Content pack: R (sonor) stages 0-5, >=200 items | speech-content-curator | TODO |
| B-041b | .mlpackage files in Resources/Models/ (SileroVAD + Scorer) | ml-trainer | TODO |
| B-036 | Firestore security rules deploy + verify | backend-dev-infra | TODO |
| B-054a | Unit tests: ListenAndChoose, RepeatAfterModel, Sorting interactors | qa-unit | TODO |
| B-054b | Unit tests: Bingo, Memory, SyncService, AdaptivePlanner | qa-unit | TODO |
| B-055a | Snapshot tests: 16 template Views (light + dark) | qa-simulator | TODO |
| B-055b | Snapshot tests: Auth, Onboarding, ChildHome, Rewards | qa-simulator | TODO |
| B-047 | Dynamic Type audit all screens | ios-dev-ui | TODO |
| B-048 | VoiceOver labels all interactive elements | ios-dev-ui | TODO |
| B-049 | Reduced Motion audit | ios-dev-ui | TODO |
| B-050 | Screenshot tour script (80 screenshots, 2 devices) | qa-simulator | TODO |
| B-051 | App Store metadata ru+en | pm | TODO |
| B-052 | AppPrivacyInfo.xcprivacy manifest | ios-dev-arch | TODO |
| B-053 | TestFlight build upload | ios-dev-arch | TODO |

---

## P2 — Sprint 12 Important (complete before App Store)

| ID | Title | Owner | Status |
|----|-------|-------|--------|
| B-080 | HapticService integration | ios-dev-perf | TODO |
| B-045 | PDF + CSV export (SpecialistExportService) | ios-dev-arch | TODO |
| B-054c | Unit tests: LLMDecisionService | qa-unit | TODO |
| B-032c | Content packs: L, Z, Zh, Ts stubs (P2) | speech-content-curator | TODO |
| B-057 | ParentGuide screen (methodology explainer) | ios-dev-ui | TODO |
| B-058 | SoundGroupProgress charts | ios-dev-ui | TODO |
| B-059 | DownloadablePacks manager screen | ios-dev-ui | TODO |
| B-064 | ContentPackMeta sync (Firebase Storage) | ios-dev-arch | TODO |
| B-074 | Sound assets: UI sounds (tap, correct, reward) | sound-curator | IN PROGRESS |
| B-075 | Voice prompts RU Lyalya (50+ phrases) | sound-curator | IN PROGRESS |

---

## P3 — Nice-to-Have (post-diploma)

| ID | Title | Status |
|----|-------|--------|
| B-061 | ManualScoring override for specialist | TODO |
| B-066 | AR smile-wider game | TODO |
| B-077 | Specialist links multiple children | TODO |
| B-079 | iCloud Keychain sync for child profile | TODO |
| B-081 | Content packs L, Z, Zh full stages | TODO |
| B-082 | Differentiation S-Sh minimal pairs seed | TODO |
| B-083 | Multiple child profiles per parent | TODO |
