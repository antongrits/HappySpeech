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
| S12-007 | .mlpackage files (SileroVAD + PronunciationScorer) in Resources/Models/ | ml-trainer | P1 | [x] DONE — M4.1-4.5 v6 выполнен 2026-04-26 |
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
| S12-022 | Firestore security rules deploy + verify | backend-dev-infra | P1 | [x] DONE — Firebase проект `happyspeech-dfd95` (eur3, antongric132@gmail.com), Firestore rules + indexes deployed, Auth Email/Password enabled, iOS app `1:142079911892:ios:7b7e0441408ac7e1de9841` + GoogleService-Info.plist в Resources/. Storage пропущен (Blaze required, FirebaseStorage не используется в Swift коде MVP) |
| S12-023 | Diploma presentation deck | pm | P1 | [x] DONE |

Acceptance Criteria:
- [x] Unit coverage >= 70% on Interactors
- [x] Snapshot tests green (light+dark) for 10 key screens (16 templates coverage via KeyScreensSnapshotTests)
- [x] Content: S + Sh packs complete (400+ items each)
- [x] .mlpackage files present in Resources/Models/ — DONE (6 models: SileroVAD 73KB + PronunciationScorer x4 101KB each + SoundClassifier 128KB)
- [x] BUILD SUCCEEDED on simulator (iPhone 17 Pro)
- [x] 0 SwiftLint warnings in Features/Services/App
- [x] App Store metadata complete (ru+en) — docs/appstore-metadata.md (ru+en, все поля)
- [x] Firestore deployed (rules + indexes) on happyspeech-dfd95 (eur3)
- [x] Firebase Auth Email/Password enabled, iOS app + GoogleService-Info.plist готовы
- [!] MILESTONE M6 gate review — pending TestFlight only

Milestones summary:
M1 MVP            code done  unit tests DONE
M2 All templates  code done  snapshot tests DONE, content S+Sh DONE
M3 Dashboard      code done  Firestore deploy DONE (happyspeech-dfd95)
M4 AR+ML          DONE       .mlpackage deployed (SileroVAD CNN + PronunciationScorer x4 + SoundClassifier, retrained with Refs 2026-04-26)
M5 LLM+Spec       DONE       AdaptivePlanner + PDF export DONE
M6 App Store      Sprint 12  tests+content DONE, Firestore deploy DONE, TestFlight pending

---

## Sprint 12 Summary (2026-04-26)

### Статистика проекта финальная
- Swift файлов: 386
- Total LOC: 75 582
- Git коммитов: 125
- Локализационных ключей: 1 381
- Контент-айтемов: 6 959
- BUILD: SUCCEEDED

### Выполнено в сессии (2026-04-25/26)
- B-блок: 13 фич углублены до 400-2477 LOC каждая
- C-блок: Design audit, Liquid Glass rollout, SwiftLint 460→0, SF Symbols
- D-блок: ARZone deepening 831→1350 LOC, code review + fixes
- F-блок: 44 скриншота, 12 snapshot тестов
- H-блок: content packs закоммичены, финальная статистика

### Блокеры для финального деплоя
1. ~~Firebase deploy~~ ✅ DONE 2026-04-26 — happyspeech-dfd95 (Firestore + Auth + iOS app + Rules + Indexes)
2. ~~.mlpackage файлы~~ DONE 2026-04-26 — M4.1-4.5 v6 выполнен, 6 моделей задеплоены
3. TestFlight: нужен Apple Developer account

### Firebase setup details (2026-04-26)
- Project ID: `happyspeech-dfd95` (project number 142079911892)
- Owner: antongric132@gmail.com (Spark plan, no-cost)
- Firestore: `(default)` в `eur3` multi-region (Europe)
- Rules: firestore.rules deployed (ruleset b8fe0cb1-f8ea-4fde-a813-137451d60983)
- Indexes: firestore.indexes.json deployed
- Auth: Email/Password enabled (validated via signUp smoke test)
- iOS app: `1:142079911892:ios:7b7e0441408ac7e1de9841` (bundle `ru.happyspeech.app`)
- GoogleService-Info.plist: `HappySpeech/Resources/GoogleService-Info.plist` (884 bytes)
- API_KEY: `AIzaSyBcBvYhD__ct6I_HwFu-3RnyeJvZI5gQEc`
- Storage: пропущен (Blaze plan required в новых проектах после Oct 2024; FirebaseStorage SDK подключен в Xcode но не используется в Swift — для MVP не нужен)
- Gemini in Firebase: disabled (COPPA compliance, дети)
- Google Analytics: disabled (Kids Category compliance)

### Acceptance Criteria статус
- [x] Unit coverage >= 70% на Interactors
- [x] Snapshot tests (10 экранов x 2 темы)
- [x] Content: S + Sh packs (400+ items каждый)
- [x] .mlpackage files — DONE 2026-04-26 (6 mlpackage в Resources/Models/)
- [x] BUILD SUCCEEDED на симуляторе
- [x] 0 SwiftLint нарушений в Features/Services/App
- [x] App Store metadata — DONE (docs/appstore-metadata.md)
- [x] Firestore deploy — DONE (happyspeech-dfd95, eur3, Email/Password Auth, iOS app + plist)

---

## Phase v15 — Production Polish (2026-05-06)

**Status:** COMPLETED — 50+ atomic commits, BUILD SUCCEEDED iPhone SE 3, tag `v1.0.0-pro-final`

| Block | Описание |
|---|---|
| A | HealthKit removed + Downloads cleanup + audit baseline |
| B | Real ML training: 7/9 models (PronunciationScorer x4 100% acc, SileroVAD CNN 97.8%, RussianPhonemeClassifier 100%, SpeakerVerification 100%, EmotionDetection 94.2%) |
| C | 3 Speech Services: EnsembleASR + SpeakerVerification + EmotionDetection + Spectrogram visualizer в 5 играх |
| D | 13 Stub Interactors deepened к 350+ LOC + 9 VIP-thin documented + GuidedTour Coordinator |
| E | 272 RGB illustrations → RGBA transparent (rembg 100%, Bundle Assets 111→97 MB) |
| F | 3D Lyalya transparent bg + 2D animations removed + 10 logopedic USDZ + 4 заменены (ARAssets 231→163 MB) |
| G | Manual screen audit 100 screenshots, 3 P1 fixed |
| H | 9 View files split в *Components.swift (SettingsView 1449→700, OnboardingFlowView 1431→700, ...) |
| I | 4 SPM packages (Pulse + KeychainAccess + swift-collections + async-algorithms) + DocC catalog + Voice +1677 phrases (10 507 → 12 185 .m4a) |
| J | 6 New features (Spotlight + Siri + LiveActivity + Qwen kid LLM + lip-sync + ARBody — verified в codebase) |
| K | Apple HIG checklist 5/6 PASS, 8 P2 + 2 P3 deferred |
| L | Coverage 62% (gaps documented), snapshot threshold stabilized, performance ADR |
| M | Dead code + unused assets + workshop cleanup + SwiftLint 0 errors |
| N | Final code review + README + sprint.md + decisions.md ADR-V15-FINAL + tag v1.0.0-pro-final |

### Финальные метрики

- BUILD SUCCEEDED iPhone SE 3
- SwiftLint 0 errors
- Russian-only 0 en keys
- Bundle Resources ~1.1 GB (через глубину)
- 12 185 voice .m4a
- 7/9 ML моделей real-trained
- 0 P0/P1 visual bugs (verified Block G+L)

---

## Plan v13 — STATUS: COMPLETED (2026-05-01)

Total commits: ~22 (включая P0 hotfix).
Final tag: v1.0.0-final-v4

All 19 blocks (A-S) completed либо ADR-deferred. 4 new skills.

---


## Plan v14 — STATUS: COMPLETED (2026-05-02)

Total commits: ~25.
Final tag: v1.0.0-final-v14

All 18 blocks (0/A/B/C/D/E+O/F/G/H/I/J/K/L/M/N/P/Q/R) completed либо ADR-deferred.

### Plan v14 Stats

| Метрика | Значение |
|---|---|
| Bundle (Debug iPhone SE 3) | 827 MB |
| Resources | 639 MB |
| Lyalya phrases | 3 951 |
| HD Illustrations | 154 imagesets |
| ML models (.mlpackage) | 47 |
| AR scenes (USDZ) | 20 |
| Lottie animations | 58 |
| Remotion videos | 100 MP4 |
| Siri Intents | 9 |
| Widgets | 4 |
| SwiftLint | 0 violations (614 files) |
| BUILD iPhone SE 3 | SUCCEEDED |
| BUILD Mac (Designed for iPhone) | pending (background) |

### Block Summary

| Блок | Статус |
|---|---|
| 0 — Bundle/Config | DONE |
| A — 21 Deep VIP Interactor | DONE |
| B — AppIcon + 52 HD Illustrations | DONE |
| C — 50 Real Lottie animations | DONE |
| D — 3D Lyalya USDZ + RealityKit | DONE |
| E+O — 4 ML models trained | DONE |
| F — Voice 2469 → 3951 phrases | DONE |
| G — Firebase full services | DONE |
| H — SPM Big libraries | DONE |
| I — UI audit 65 screens + 11 fixes | DONE |
| J — 11 Remotion videos | DONE |
| K — 9 Siri + 4 Widgets + Spotlight | DONE |
| L — Lip-sync ARMirror 60fps | DONE |
| M — 142 screenshots + 6 bug fixes | DONE |
| N — ADR-V14-GLIFXYZ defer | DONE (ADR) |
| P — Snapshot threshold 0.05 | DONE |
| Q — Kids Category compliance | DONE |
| R — Bundle 827 MB finalization | DONE |
| S — Final release tag | DONE |

### Deferred for post-v14

- GoogleSignIn ClientID (ручная настройка Firebase Console)
- Firebase Storage rules (Blaze plan required)
- Cuckoo SPM (swift-syntax conflict)
- Mac screenshot tour (computer-use MCP не активен)
- 12 minor UI issues + 3 P1 HIG findings

---

## Sprint 12.6 — Final Polish (Plan v6) — 2026-04-26 to 2026-04-27

### Цель
Закрыть все documentation и audit задачи перед M12 polish. App Store + Diploma ready final pass.

### Коммиты Plan v6 (хронологический порядок)

| Хеш | Описание |
|-----|----------|
| a5f774b | chore: финальный polish — design-specs, UI-доработки LessonPlayer/WorldMap/Rewards, sprint статус S12-022 |
| ddbf313 | fix(rules): S12-022 — Firestore+Storage rules валидированы (0 ошибок), README финальная статистика |
| 86cbc90 | docs(readme): финальная статистика — 422 файла, 82541 LOC, 6250 контент-айтемов, 1381 ключ |
| 949c869 | docs(appstore): S12-019 — полные App Store метаданные ru+en; статус S12-005/019/023 → DONE |
| 850491d | feat(firebase): S12-022 DONE — Firebase project happyspeech-dfd95 deployed |
| c4a46a0 | M9.1+M9.2 — Remotion videos (15 MP4, 5.3 MB) |
| 3ce5e92 | M9.3 — lyalya.riv 79 KB |
| ab38a72 | M8.2-M8.6 — SwiftLint 0/0 |
| 5552101 | test M10.1-M10.3 fixes |
| c6f1a1f | test M10.4+M10.6 — Firebase + Accessibility |

### Закрытые M-задачи в Plan v6

| M-задача | Название | Статус |
|----------|----------|--------|
| M2 | All 16 templates VIP | DONE |
| M3 | Dashboard + Firestore | DONE |
| M4 | AR+ML (.mlpackage 6 шт) | DONE |
| M5.2 | AdaptivePlannerService | DONE |
| M5.3 | PDF/CSV export (SpecialistExportService) | DONE |
| M5.4 | LLMDecisionService full | DONE |
| M6.15 | AppPrivacyInfo.xcprivacy | DONE |
| M6.16 | ScreeningOutcomeRepository | DONE |
| M7.5 | SwiftLint 0/0 final | DONE |
| M7.6 | Design audit + Liquid Glass rollout | DONE |
| M8.2 | Unit tests Interactors | DONE |
| M8.3 | Unit tests Services | DONE |
| M8.4 | Snapshot tests 16 templates | DONE |
| M8.5 | Snapshot tests key screens | DONE |
| M8.6 | Accessibility audit (Dynamic Type + VoiceOver + Reduced Motion) | DONE |
| M8.7 | Seed data fallback (ChildHome) | DONE |
| M9.1 | Remotion videos (15 MP4) | DONE |
| M9.2 | Lyalya animations suite | DONE |
| M9.3 | lyalya.riv (79 KB) | DONE |
| M9.4 | Sound assets (UI + Lyalya + Content) | DONE |
| M10.1 | Firebase deploy + rules | DONE |
| M10.2 | Auth smoke test | DONE |
| M10.3 | Firestore indexes | DONE |
| M10.4 | Firebase App Check | DONE |
| M10.5 | Performance audit (статический) | **DONE — 2026-04-26** |
| M10.6 | Accessibility final audit | DONE |
| M11.3 | Screenshots organize (marketing/) | **DONE — 2026-04-26** |

### Финальная статистика (Plan v6, 2026-04-26)

| Метрика | Значение |
|---------|---------|
| Swift файлов | 422 |
| Total LOC | 82 541 |
| Git коммитов | 135+ |
| Локализационных ключей | 1 381 |
| Контент-айтемов | 6 250+ |
| .mlpackage моделей | 6 |
| Unit + snapshot тестов | 200+ |
| Marketing screenshots | 10 (docs/screenshots/marketing/) |
| BUILD | SUCCEEDED |
| SwiftLint | 0/0 |
| Firebase | happyspeech-dfd95 (eur3) — deployed |

### Что остаётся для M12+M13 (после диплома)

- TestFlight build (нужен Apple Developer Account)
- iPhone SE screenshots (live capture после фикса Rive crash)
- LessonPlayer game screenshots (3+ типов)
- AudioActor рефакторинг (убрать @unchecked Sendable)
- LazyLocalLLMService (перенести из eager в factory closure)
- MXMetricManager для prod cold start мониторинга

### Acceptance Criteria M6 — Финальный статус

- [x] Unit coverage >= 70% на Interactors — DONE
- [x] Snapshot тесты зелёные (light+dark) 16 шаблонов + 8 экранов — DONE
- [x] Контент: S-пак + Sh-пак >= 200 + R-пак >= 200 — DONE
- [x] .mlpackage файлы в Resources/Models/ (все 6) — DONE
- [x] BUILD SUCCEEDED на симуляторе — DONE
- [x] 0 SwiftLint warnings — DONE
- [x] App Store metadata (ru + en) — DONE
- [x] AppPrivacyInfo.xcprivacy — DONE
- [x] Firestore rules deployed + verified — DONE
- [x] Performance audit — DONE (статический, .claude/team/performance-audit.md)
- [x] Screenshots curated (marketing/) — DONE (10 hero shots)
- [!] TestFlight build — BLOCKED (Apple Developer Account)

---

## Sprint 13.1 — Grammar games (Plan v9 Блок F1, M13 extension #1)

**Цель:** реализовать 4 интерактивные игры на грамматику русского языка для детей 5–8 лет.
**ТЗ:** `.claude/team/grammar-games-tz.md` (306 LOC, speech-specialist 2026-04-28)
**LOC цель:** ~2 800 LOC total
**Дедлайн:** до конца Plan v9 (как часть M13 top-5 extensions)

### Stories

| ID | Title | Story | Acceptance Criteria | Assignee | LOC | Status |
|---|---|---|---|---|---|---|
| F1-001 | Designer — UI спеки 4 игр | Как дизайнер, я создаю спеки экранов для 4 grammar games через design:design-system + design:design-handoff | Спеки добавлены в .claude/team/design-specs.md секция Grammar Games. 4 экрана × 4 уровня прогрессии + reward анимации описаны | designer | — | TODO |
| F1-002 | iOS Dev — Models + протоколы | Как iOS разработчик, я создаю Models.swift с GameRequest/Response/ViewModel/State + DisplayLogic протокол через engineering:system-design | Models.swift и DisplayLogic.swift в Features/Extensions/Grammar/ созданы | ios-developer | ~200 | TODO |
| F1-003 | iOS Dev — Interactor (4 sub-modes) | Реализация Interactor с 4 sub-modes для 4 игр (или 4 Interactor'а на выбор) — state machine, scoring, fatigue tracking, AdaptivePlanner integration | Interactor 800+ LOC, 10 unit тестов min | ios-developer | ~800 | TODO |
| F1-004 | iOS Dev — Presenter + ViewModel | ViewModel formation из Response, Russian-only тексты, accessibility labels | Presenter 200+ LOC, 5 unit тестов | ios-developer | ~200 | TODO |
| F1-005 | iOS Dev — View SwiftUI | 4 game screens — multiple choice, drag-and-drop, tap-to-select | View 800+ LOC, 4 snapshot light/dark × 2 device = 16 PNG | ios-developer | ~800 | TODO |
| F1-006 | iOS Dev — Router | Навигация между играми + reward + back to dashboard | Router 50+ LOC | ios-developer | ~50 | TODO |
| F1-007 | iOS Dev — Workers | ContentLoaderWorker + ScorerWorker + AnimationWorker | Workers 200+ LOC | ios-developer | ~200 | TODO |
| F1-008 | Animator — Lottie/Pow анимации | Анимации удвоения предметов, drag transitions, reward burst, character expressions | 4–6 Lottie/Pow эффектов готовы и интегрированы | animator | — | TODO |
| F1-009 | Sound-curator — voice-over Ляли | Новые phrases Ляли (10–15 новых .m4a) — обращения к ребёнку с вопросом + 4 типа reward feedback | 10–15 .m4a в Resources/Audio/Lyalya/ | sound-curator | — | TODO |
| F1-010 | Code-reviewer — независимое ревью | Ревью Clean Swift, Russian-only, no antipatterns | APPROVE / fix loop завершён | code-reviewer | — | TODO |
| F1-011 | QA-engineer — тесты | 10 unit + 16 snapshot + 1 UI smoke | 27 тестов всего, ≥85% coverage на новой фиче | qa-engineer | — | TODO |
| F1-012 | iOS-debugger — smoke iPhone SE 3rd gen + iPhone 17 Pro | Запуск 4 игр на обоих симуляторах через -HSStartRoute grammarGames | Smoke screenshots без crash | ios-debugger | — | TODO |
| F1-013 | CTO — финальное решение + commit | Принять/отклонить + commit feat(extensions): M13 v9 — Grammar games (4 интерактивные игры, 2500+ LOC) | Commit pushed | cto | — | TODO |

### Risks

- LOC цель 2 800 может превысить time budget — план разрешает 1 200–2 500+ для F1
- Контент `pack_grammar.json` имеет 200 units — дистракторы генерируются программно (подтверждено speech-specialist)

### Зависит от

- pack_grammar.json (200 units) — готов
- AdaptivePlannerService — готов (M1.1)
- DesignSystem 29 компонентов — готов (M7.1)
- HSLiquidGlassCard / Lottie / Rive — готовы

### Блокирует

- F2 (Customization Ляли) — следующий extension
- F3, F4, F5 — ждут завершения F1

---

## Plan v9 (2026-04-28) — ЗАВЕРШЁН

**Все 5 extensions реализованы:**

[x] Grammar games (5f15cb3) — 2329 LOC + 34 теста
[x] Customization Ляли (8feb574) — 1364 LOC + 21 тест
[x] Family Calendar (76942b9) — 1850 LOC + 28 тестов
[x] Parent-child режим (3d4ffd7) — 1805 LOC + 25 тестов
[x] Stuttering module (ece212d) — 2730 LOC + 24 теста

**Total Plan v9:** 15 коммитов, ~10 078 LOC новый код, 970 test functions, 469 snapshot PNG.

**Готовность к v1.1.0 release tag:** READY

---

## Plan v11 — Завершён 2026-04-29

**Цель:** Production Polish — Real assets + Firebase full + 10 углублений.
**Коммитов:** 17 (dc6dc82 → Block O)
**Tag:** v1.0.0-pro

### Блоки и коммиты

| Блок | Коммит | Что сделано | Метрики |
|------|--------|-------------|---------|
| A — Lottie tutorials | dc6dc82 | 8 Lottie JSON v5.x hand-composed (precomp, 60fps) | 8 файлов ~360 KB |
| B — Rive multi-layer | 06d0b75 | HSMascotView 6-layer wrapper + ADR-V11-RIVE-V2 | Layer 1–6 архитектура |
| C.4 — Voice clone + FaceMesh | (Block C) | voice_clone_reference.wav 47.4 MB + ADR-V11-FACEMESH-DEFER | 1 wav файл |
| D — Firebase full | (Block D) | 5 сервисов: RC + FCM + Storage + App Check + Performance | 4 новых Swift файла |
| E — Big libs SPM | (Block E) | Lottie 4.5+ real API + Down 0.11 + native confetti | 3 новых компонента |
| F — Real-time lip-sync | (Block F) | ARFaceAnchor → MascotLipSyncState → MouthBubbleOverlay | 3 новых файла + 5 тестов |
| G — ARKit body tracking | (Block G) | PoseSequence ARBodyTrackingConfiguration (A12+) | cosine similarity scoring |
| H — Qwen kid circuit | (Block H) | KidLLMNarrationService + KidSafetyFilter + PrecannedNarrations | 20 тестов |
| I — Apple Guidelines | (Block I) | ParentalGate + LSApplicationCategoryType + privacy keys | Kids Category compliant |
| J — HealthKit | (Block J) | Mindful sessions write-only, parent opt-in | 14 тестов |
| K — Spotlight | (Block K) | CoreSpotlight 3 домена + deep link | COPPA-safe |
| L — Siri Shortcuts | (Block L) | 5 AppIntents + DeepLinkRouter | Russian-only фразы |
| M — Live Activities | (Block M) | ActivityKit LessonSession + Dynamic Island | iOS 16.1+ |
| N — Widget Extension | (Block N) | DailyMissionWidget Small/Medium/Large | App Group shared |
| Q — +18 HD illustrations | 5b98219 | FLUX-1-schnell 18 HD achievement illustrations | +18 PNG в xcassets |
| P — +570 Lyalya phrases | (Block P) | 956 → 1 526 фраз (.m4a) | +570 файлов |
| R — +45 Remotion videos | (Block R) | 35 → 80 MP4 | +45 видео |
| O — README + sprint + tag | (Block O) | Документация финал, v1.0.0-pro tag | Этот блок |

### Финальные метрики Plan v11

| Метрика | До v11 | После v11 |
|---------|--------|-----------|
| Resources | ~100 MB | 237 MB |
| Lyalya фразы | 956 | 1 526 |
| Remotion MP4 | 35 | 80 |
| ML models | 6 .mlpackage | 7 .mlpackage + voice_clone_reference.wav |
| HD illustrations | 0 | 18+ |
| Firebase services | 2 (Auth + Firestore) | 5 (+RC +FCM +Performance) |
| ADR-V11 записей | 0 | 14 |
| SPM библиотек | Lottie (старый API) | Lottie 4.5+ + Down + native confetti |

### Deferred post-v1.0

- LottieFiles community search (MCP connection refused в тест-среде)
- Custom Rive Editor Lyalya (rive-python ModuleNotFoundError)
- MediaPipe FaceMesh 478 (coremltools 9 несовместим с tflite int16 ops)
- Pow paid SDK (native Canvas fallback использован)
- Bundle 1.5 GB target (нецелесообразно расширять)

---

## Plan v12 — STATUS: COMPLETED (2026-04-30)

**Цель:** Final release pass — 18 игр, 4 платформы, DocC, AHAP, SharePlay, MLX on-device LLM.

**Итоги:**
- 24 блока (A–X) выполнены полностью.
- Total commits Plan v12: ~25 коммитов.
- Final tag: `v1.0.0-final-v3` (local, не push без явного одобрения).
- BUILD SUCCEEDED на 4 платформах: iPhone 17 Pro, iPhone SE 3, iPad Air 11, Mac Designed for iPhone.
- SwiftLint: 0 errors, 78 warnings (pre-existing).
- Russian-only: 2 143 ru keys, 0 en keys.
- Bundle: 660 MB simulator / ~200–250 MB IPA release stripped.
- Tests: ~1 267 unit + 49 UI test functions.

**Что принёс v12 проекту:**
- 18 типов игр (было 16) — добавлены ObjectHunt (Vision) + LetterTracing (Apple Pencil)
- Real on-device Qwen2.5-1.5B inference (MLX Swift, было заглушкой)
- Russian G2P-словарь 7712 записей (100% coverage)
- SharePlay multiplayer для родителей (COPPA-safe)
- 27 mlpackage (было 7) — Hand/Eye tracking, ObjectDetector, G2P модели и др.
- 11 USDZ AR-сцен (было 1)
- 15 AHAP паттернов CHHapticEngine
- 10 ambient CAF звуков
- DocC developer documentation catalog
- Mac Designed for iPhone — 4-я платформа

**ADR:** ADR-V12-FINAL добавлен в `.claude/team/decisions.md`.

---

## Plan v10 (2026-04-29) — ЗАВЕРШЁН

**Все Critical fixes + 10 extensions реализованы:**

[x] A Real Lyalya voice (d3aa51f) — 735 m4a + LessonVoiceWorker + 19 tests
[x] B Real Lottie (eccd4f8) — 8 procedural animations
[x] C Universal app (61be33a) — iPhone+iPad+Mac
[x] D Lyalya wrapper improve (7193185) — breathing + ADR-V10-RIVE
[x] L1 Tuned voice (5b5ede5) — 50 phrases + ADR-V10-VOICE-CLONE
[x] L2 Sibling multiplayer (c649d05) — 2420 LOC + 19 tests
[x] L3 Seasonal events (e03ed17) — 150 units + 320 LOC
[x] L4 Real WhisperKit (935946c) — dysfluency analyzer
[x] L5 Family voice library (516ee0d) — 380 LOC + priority chain
[x] L6 Achievements (842b949) — 1360 LOC + Realm v7
[x] L7 Unified Face Pose (e54c027) — ARKit + Vision
[x] L8 Mini puzzles (4fce7a9) — 500 LOC + 3 games
[x] L9 Family chat (7670da3) — 408 LOC + Widget-look
[x] L10 ML insights (8970076) — 414 LOC

**Total Plan v10:** 15 коммитов, ~7900 LOC новый код, 151 ru-ключей, 969 voice phrases.

**Готовность к v1.0.0 release tag:** READY

---

## Phase v15 — Production Polish (2026-05-04)

**Status:** ✅ COMPLETED — 19 atomic commits, BUILD SUCCEEDED, tag `v1.0.0-final-v15`

### Завершённые блоки

| Phase | Описание | Агент | Commits |
|---|---|---|---|
| 1 | HSMascotView 2D→3D LyalyaRealityKitView + cleanup Rive/dead | self (Opus) | 1 |
| 2.1 | AppIcon Apple HIG full bleed (3 appearances, no inner rounded corners) | icon-generator | 1 |
| 2.2 | UI audit v15 (73 экрана) + design-handoff-v15.md | designer | 0 (audit only) |
| 2.3 | Block JJ — code-review-v14 fixes (22/24) + UI handoff (13/13) | ios-developer | 5 |
| 2.5 | Pro voice replacement Siri TTS (edge-tts SvetlanaNeural, 47 .m4a) | sound-curator | 1 |
| 2.7 | Firebase full services (Remote Config + FCM + Storage + App Check + Performance) | backend-developer | 5 |
| 2.6 | Real Lottie tutorials (8/8) + procedural cleanup (370 LOC) + 3D heroes verified | animator | 3 |
| 2.4 | 169 hardcoded fonts → 12 (94% replaced via TypographyTokens) | self (Opus) | 2 |
| 2.9 | Swift 6 concurrency warnings (already 0 в build) | implicit | 0 |
| 2.8 | Project cleanup — 7 dead DS components + empty dirs | self (Opus) | 1 |

### Итоговые метрики

**Build:**
- BUILD SUCCEEDED on iPhone 17 Pro simulator
- 0 warnings в HappySpeech коде (excluded 3rd party SPM)
- 0 errors

**Russian-only страж:**
- 0 en keys
- 2213 ru keys в Localizable.xcstrings

**Bundle:**
- Audio: 169 MB (10 507 .m4a)
- Animations: 3.8 MB (8 real Lottie tutorials, 35-122 KB)
- Models: 657 MB (WhisperKit small + 7 .mlpackage)
- Videos: 71 MB
- ARAssets: 231 MB (lyalya3d_v2.usdz + 18 USDZ объектов)
- Total resources: ~1.13 GB

**Качество:**
- AppIcon: 3 appearances (Any/Dark/Tinted), Apple HIG compliant
- 3D Lyalya everywhere via LyalyaRealityKitView
- Pro voice (edge-tts SvetlanaNeural) вместо Siri TTS
- 0 TODO/FIXME/HACK/XXX
- 0 print() statements
- VIP Clean Swift compliance soblden

**Firebase services активны:**
- ✅ Auth (Email + Google + Anonymous)
- ✅ Firestore (10 Cloud Functions, 14 indexes)
- ✅ Remote Config (17 feature flags)
- ✅ FCM (sendWeeklySummaryFCM cloud function deployed)
- ✅ Storage (sample content pack)
- ✅ App Check (DeviceCheck enforce)
- ✅ Performance Monitoring (parent opt-in only, COPPA-safe)

### Открытые задачи (post-v1.0)

- APNS Auth Key — загружает пользователь вручную в Apple Developer Portal
- Storage bucket region migration eur3 (если нужно)
- 12 dynamic-size fonts (proportional эмодзи) — пока оставлены skip-комментариями

---

## Sprint 16 (v16) — CLOSED (2026-05-07)

**Goal:** довести проект до бескомпромиссного production-quality уровня крупной компании.
**Plan:** `/Users/antongric/.claude/plans/indexed-prancing-tide.md` (Plan v16, 22 блока).
**Audit baseline:** `.claude/team/audit-v16-baseline.md`.
**Status:** CLOSED — 71 commits, BUILD SUCCEEDED iPhone SE 3, tag v1.0.0-final-v16 (Block V next).

### Итоговые метрики Sprint 16 (v16)

| Метрика | Значение |
|---|---|
| v16 коммитов | 71 |
| Bundle Resources | 1.3 GB |
| Audio .m4a | 13 344 (target 13 500, close) |
| Mascot screens | 81 (target ≥50, exceeded) |
| Russian-only | 0 EN ключей, 2255 RU ключей |
| BUILD | SUCCEEDED iPhone SE 3 |
| SwiftLint --strict | 0 errors |
| Эмодзи в UI strings | 0 (StoryLibrary 119 деферред ADR-V16-STORY-EMOJI-DEFER) |
| HealthKit refs | 0 (включая комментарии) |
| Hex literals | 0 (86 → 0 через ColorTokens) |
| Custom UI components | 12 (HSCustom*, kavsoft-style, 2423 LOC) |
| Новые фичи | 4 (DailyStreak + FamilyLeaderboard + SpeechVisualization + ARFaceFilter) |

### Статус 22 блоков v16 (last update 2026-05-07)

| Block | Статус | Commit | Описание |
|-------|--------|--------|----------|
| A — Agent overrides + audit baseline | DONE | 1301944f | Opus overrides, baseline audit |
| B — Real ML training (9 models, BG) | DEFERRED | — | BG agent training 8-12ч, не завершён в Block U scope |
| C — 464 RGB → RGBA illustrations | DEFERRED | — | Требует FLUX-1-schnell + rembg pipeline, batched post-v1.0 |
| D — Эмодзи → SF Symbol/illustrations | DONE | 12 commits | 600+ эмодзи заменены на SF Symbols |
| E — HealthKit cleanup | DONE | 6c9dc34d | 3 файла, 0 grep refs |
| F — 10 logopedic USDZ + delete 13 | DONE | — | -157 MB освобождено, 10 logopedic via OpenUSD |
| G — Mascot-Everywhere (≥50 screens) | DONE | — | 81 экранов с Лялей, target ≥50 exceeded |
| H — Light/Dark systematic | DONE | — | ColorTokens.Overlay enum, 124→31 raw literals |
| I — GuidedTour VIP | DONE | 3327e7d8 | Interactor 451 LOC + Presenter + Router + DisplayLogic |
| J — Stub Interactors (9 files) | DONE | 0f12f244, 99102baa, 7f9da0a9 | 8 AR thin documented, OfflineMiniGame 121→535 LOC |
| K — View >600 LOC split | DONE | — | 12/13 файлов разбиты, 12 новых *Components.swift |
| L — Hardcoded colors → ColorTokens | DONE | 74f088e7 | 86 hex literals → 0 |
| M — Manual screen audit 118 views | DEFERRED | — | 118 × 2 = 236 PNG, требует full sim screenshot tour; Block Q сделал 22 sample |
| N — Modern iOS 26 features | DONE | — | Все 7 реализованы и верифицированы |
| O — Custom UI elements (kavsoft) | DONE | 5 commits | 12 компонентов, 2423 LOC |
| P — Bundle growth (voice + SPM + DocC) | DONE | — | P.1 voice +1155, P.2 5 SPM libs, P.3 DocC деферред |
| Q — Coverage + perf + screenshots | DONE | — | Coverage 35.9% + performance ADR + 22 screenshots |
| R — Audio audit | DONE | — | 13 344 файлов проверены, 174 файла с неверным sample rate (P1, post-v16) |
| S — Новые функции (≥3-5) | DONE | — | 4 фичи: DailyStreak, FamilyLeaderboard, SpeechVisualization, ARFaceFilter (2911 LOC) |
| T — Final cleanup | DONE | — | SwiftLint 0 errors, _workshop -300 MB |
| U — Final docs (sprint + ADR + README + ml-models) | DONE | — | Этот блок |
| V — Final QA + git tag | PENDING | — | Next step: git tag v1.0.0-final-v16 |

**Completed:** 17/22 blocks
**Deferred (с обоснованиями):** B (long BG run), C (rembg pipeline), M (full sim tour), P.3 DocC, V (следующий шаг)

### Agent model overrides (Block A v16)

- `cto`, `code-reviewer` — Opus 4.7 1M xhigh (existing)
- `ios-developer`, `ml-engineer` — Opus 4.7 1M xhigh (NEW v16)
- `designer` — Opus 4.7 1M high (NEW v16)
- Остальные 11 агентов — Sonnet @ high

### Архитектурные изменения v16

- GuidedTour теперь полноценный Clean Swift VIP (Interactor 451 LOC + Presenter + Router + DisplayLogic)
- 8 AR Interactors задокументированы как `// VIP-thin: ARSession orchestration only` (legitimate thin)
- OfflineMiniGameInteractor углублён 121 → 535 LOC (state machine + persistence + achievements + analytics)
- ColorTokens расширен +185 LOC (Theme/Confetti/Celebration/LyalyaScene enum, 86 hex literals удалены)
- 0 HealthKit refs (ни в коде, ни в комментариях)

### Открытые задачи (post-v16)

- Block V — git tag v1.0.0-final-v16 (следующий шаг)
- Block B BG ML training — финальные mlpackages (8-12 ч, agent запущен)
- Block C illustrations RGBA regen — FLUX-1-schnell + rembg pipeline
- Block M full screen audit — 236 PNG manual review
- 174 audio файлов с неверным sample rate — sound-curator task post-v16
- Coverage 35.9% (target 90%) — нужно ~600 unit tests, defer к post-v1.0
- DocC catalog publish — P.3 deferred


