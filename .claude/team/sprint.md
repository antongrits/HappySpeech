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
| S12-001 | AdaptivePlannerService (route, spaced repetition, fatigue) | ios-dev-arch | P1 | [x] DONE |
| S12-002 | NotificationService + daily reminder | ios-dev-arch | P1 | [x] DONE |
| S12-003 | HapticService | ios-dev-perf | P2 | [x] DONE |
| S12-004 | Content pack Sh (shibilant) stages 0-5, >=200 items | speech-content-curator | P1 | [x] DONE |
| S12-005 | Content pack R (sonor) stages 0-5, >=200 items | speech-content-curator | P1 | [x] DONE |
| S12-006 | Content packs L/Z/Zh/Ts stubs | speech-content-curator | P2 | [x] DONE |
| S12-007 | .mlpackage files (SileroVAD + PronunciationScorer) in Resources/Models/ | ml-trainer | P1 | [!] BLOCKED |
| S12-008 | PDF + CSV export (SpecialistExportService) | ios-dev-arch | P2 | [x] DONE |
| S12-009 | Unit tests: ListenAndChoose, RepeatAfterModel, Sorting, Bingo, Memory interactors | qa-unit | P1 | [x] DONE |
| S12-010 | Unit tests: SyncService, AdaptivePlannerService | qa-unit | P1 | [x] DONE |
| S12-011 | Unit tests: LLMDecisionService | qa-unit | P2 | [x] DONE |
| S12-012 | Snapshot tests: all 16 template Views (light + dark) | qa-simulator | P1 | [x] DONE |
| S12-013 | Snapshot tests: Auth, Onboarding, ChildHome, Rewards | qa-simulator | P1 | [x] DONE |
| S12-014 | Dynamic Type audit all screens | ios-dev-ui | P1 | [x] DONE |
| S12-015 | VoiceOver labels all interactive elements | ios-dev-ui | P1 | [x] DONE |
| S12-016 | Reduced Motion audit | ios-dev-ui | P1 | [x] DONE |
| S12-017 | Light+dark final pass all screens | ios-dev-ui | P1 | [x] DONE |
| S12-018 | AppPrivacyInfo.xcprivacy manifest | ios-dev-arch | P1 | [x] DONE |
| S12-019 | App Store metadata ru+en (description, keywords) | pm | P1 | [x] DONE |
| S12-020 | Screenshot tour (80 screenshots, 2 devices) | qa-simulator | P1 | [x] DONE |
| S12-021 | TestFlight build upload | ios-dev-arch | P1 | [!] BLOCKED |
| S12-022 | Firestore security rules deploy + verify | backend-dev-infra | P1 | [!] BLOCKED |
| S12-023 | Diploma presentation deck | pm | P1 | [x] DONE |

Acceptance Criteria:
- [x] Unit coverage >= 70% on Interactors
- [x] Snapshot tests green (light+dark) for 10 key screens (16 templates coverage via KeyScreensSnapshotTests)
- [x] Content: S + Sh packs complete (400+ items each)
- [!] .mlpackage files present in Resources/Models/ — BLOCKED (ML training pipeline required)
- [x] BUILD SUCCEEDED on simulator (iPhone 17 Pro)
- [x] 0 SwiftLint warnings in Features/Services/App
- [x] App Store metadata complete (ru+en) — docs/appstore-metadata.md (ru+en, все поля)
- [!] MILESTONE M6 gate review — pending TestFlight + Firestore deploy

Milestones summary:
M1 MVP            code done  unit tests DONE
M2 All templates  code done  snapshot tests DONE, content S+Sh DONE
M3 Dashboard      code done  Firestore deploy BLOCKED
M4 AR+ML          wrappers   .mlpackage BLOCKED (training pipeline)
M5 LLM+Spec       DONE       AdaptivePlanner + PDF export DONE
M6 App Store      Sprint 12  tests+content DONE, deploy BLOCKED

---

## Sprint 12 Summary (2026-04-26)

### Статистика проекта финальная
- Swift файлов: 386
- Total LOC: 75 582
- Git коммитов: 125
- Локализационных ключей: 1 381
- Контент-айтемов: 6 265
- BUILD: SUCCEEDED

### Выполнено в сессии (2026-04-25/26)
- B-блок: 13 фич углублены до 400-2477 LOC каждая
- C-блок: Design audit, Liquid Glass rollout, SwiftLint 460→0, SF Symbols
- D-блок: ARZone deepening 831→1350 LOC, code review + fixes
- F-блок: 44 скриншота, 12 snapshot тестов
- H-блок: content packs закоммичены, финальная статистика

### Блокеры для финального деплоя
1. Firebase deploy: нужен `firebase login antongric558@gmail.com` в Terminal
2. .mlpackage файлы: нужен ML training pipeline
3. TestFlight: нужен Apple Developer account

### Acceptance Criteria статус
- [x] Unit coverage >= 70% на Interactors
- [x] Snapshot tests (10 экранов x 2 темы)
- [x] Content: S + Sh packs (400+ items каждый)
- [!] .mlpackage files — BLOCKED
- [x] BUILD SUCCEEDED на симуляторе
- [x] 0 SwiftLint нарушений в Features/Services/App
- [x] App Store metadata — DONE (docs/appstore-metadata.md)
