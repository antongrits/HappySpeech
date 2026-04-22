# Sprint Plan — HappySpeech
## Version 2.0 — 2026-04-22 (PM audit after code review)

> Audit 2026-04-22: 246 Swift files. S1-S11 code done.
> Gaps: tests, content packs (only S exists), missing services, App Store prep.

## Sprints 0-3 [COMPLETE]
Planning artifacts, Core layer, DesignSystem (5 tokens + 12 components),
Auth/Onboarding/Permissions full VIP, Realm models, AppContainer DI.

## Sprints 4-5 [CODE DONE, tests missing]
3 MVP templates (ListenAndChoose, RepeatAfterModel, Sorting), AudioService,
ASRServiceLive (WhisperKit), ContentEngine, sound_s_pack.json.
MISSING: unit tests for interactors.

## Sprints 6-8 [CODE DONE, content+tests missing]
All 16 templates full VIP. AdaptivePlannerService NOT FOUND. NotificationService NOT FOUND.
HapticService NOT FOUND. Only S sibilant content pack. Unit+snapshot tests MISSING.

## Sprints 9-11 [CODE DONE, deploy+tests missing]
ProgressDashboard, SyncService, OfflineQueueManager, ARZone, LLMDecisionService (full),
RuleBasedDecisionService, Specialist, Settings, Demo full VIP.
.mlpackage files NOT in Resources/Models/. Firestore not deployed. PDF export MISSING.

---

## Sprint 12 — CURRENT (2026-04-22 to 2026-05-05)
Goal: Close all gaps. App Store + Diploma ready.

| ID | Task | Owner | Priority | Status |
|----|------|-------|----------|--------|
| S12-001 | AdaptivePlannerService (route, spaced repetition, fatigue) | ios-dev-arch | P1 | [ ] TODO |
| S12-002 | NotificationService + daily reminder | ios-dev-arch | P1 | [ ] TODO |
| S12-003 | HapticService | ios-dev-perf | P2 | [ ] TODO |
| S12-004 | Content pack Sh (shibilant) stages 0-5, >=200 items | speech-content-curator | P1 | [ ] TODO |
| S12-005 | Content pack R (sonor) stages 0-5, >=200 items | speech-content-curator | P1 | [ ] TODO |
| S12-006 | Content packs L/Z/Zh/Ts stubs | speech-content-curator | P2 | [ ] TODO |
| S12-007 | .mlpackage files (SileroVAD + PronunciationScorer) in Resources/Models/ | ml-trainer | P1 | [ ] TODO |
| S12-008 | PDF + CSV export (SpecialistExportService) | ios-dev-arch | P2 | [ ] TODO |
| S12-009 | Unit tests: ListenAndChoose, RepeatAfterModel, Sorting, Bingo, Memory interactors | qa-unit | P1 | [ ] TODO |
| S12-010 | Unit tests: SyncService, AdaptivePlannerService | qa-unit | P1 | [ ] TODO |
| S12-011 | Unit tests: LLMDecisionService | qa-unit | P2 | [ ] TODO |
| S12-012 | Snapshot tests: all 16 template Views (light + dark) | qa-simulator | P1 | [ ] TODO |
| S12-013 | Snapshot tests: Auth, Onboarding, ChildHome, Rewards | qa-simulator | P1 | [ ] TODO |
| S12-014 | Dynamic Type audit all screens | ios-dev-ui | P1 | [ ] TODO |
| S12-015 | VoiceOver labels all interactive elements | ios-dev-ui | P1 | [ ] TODO |
| S12-016 | Reduced Motion audit | ios-dev-ui | P1 | [ ] TODO |
| S12-017 | Light+dark final pass all screens | ios-dev-ui | P1 | [ ] TODO |
| S12-018 | AppPrivacyInfo.xcprivacy manifest | ios-dev-arch | P1 | [ ] TODO |
| S12-019 | App Store metadata ru+en (description, keywords) | pm | P1 | [ ] TODO |
| S12-020 | Screenshot tour (80 screenshots, 2 devices) | qa-simulator | P1 | [ ] TODO |
| S12-021 | TestFlight build upload | ios-dev-arch | P1 | [ ] TODO |
| S12-022 | Firestore security rules deploy + verify | backend-dev-infra | P1 | [ ] TODO |
| S12-023 | Diploma presentation deck | pm | P1 | [ ] TODO |

Acceptance Criteria:
- Unit coverage >= 70% on Interactors
- Snapshot tests green (light+dark) for 16 templates + 8 key screens
- Content: S + Sh packs complete (>=400 items total)
- .mlpackage files present in Resources/Models/
- TestFlight build boots on simulator
- 0 swiftlint warnings
- App Store metadata complete (ru+en)
- MILESTONE M6 gate review

Milestones summary:
M1 MVP            code done  needs unit tests
M2 All templates  code done  needs content + snapshots
M3 Dashboard      code done  needs Firestore deploy
M4 AR+ML          wrappers   needs .mlpackage files
M5 LLM+Spec       mostly     needs AdaptivePlanner + PDF export
M6 App Store      Sprint 12  tests + content + metadata
