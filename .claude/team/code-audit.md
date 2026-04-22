# HappySpeech Code Audit Report

**Дата:** 2026-04-23
**Ветка:** main, коммит 62eac8f
**Охват:** App/, Core/, DesignSystem/, Services/, ML/, Data/, Sync/, Content/, Analytics/, Features/

---

## Summary

- **Production-ready:** Core/, DesignSystem/, Services/ protocols+Mocks, ML/ASR, ML/LLM scaffolding, ML/PronunciationScorer, Data/, Content/, Analytics/, Features/Onboarding
- **Shallow:** App/ (coordinator stubs), Services/ (Live implementations mixed), ML/VAD Service layer, Sync/, Features/Specialist, Settings, ARZone, SessionComplete, WorldMap, ProgressDashboard, Rewards, SessionHistory, HomeTasks
- **Stub:** Features/LessonPlayer (16 игр — все заглушки), LiveLocalLLMService, uploadToFirebase
- **Anti-patterns:** 7 критических проблем + 15 важных

---

## Критические проблемы 🔴 (fix в M1)

### [P0-1] OfflineStateView: preview-child-1 в production
**Файл:** `Features/OfflineState/OfflineStateView.swift:~81`
**Проблема:** `coordinator.navigate(to: .childHome(childId: "preview-child-1"))` — preview-строка в production navigation
**Action:** передавать реальный childId через инициализатор или environment

### [P0-2] Sign In with Apple должен быть убран
**Файл:** `Features/Auth/AuthSignInView.swift:106-113`
**Проблема:** по новому ТЗ нужны только Email+Password и Google Sign-in (нет Apple Developer Account у пользователя)
**Action:** удалить Apple Sign-in, заменить на Google Sign-in

### [P0-3] AuthInteractor — полный STUB без Firebase Auth
**Файл:** `Features/Auth/AuthSignInView.swift:162-175`, `AuthInteractor.swift`
**Проблема:** `handleAppleSignIn` просто проставляет `isAuthenticated = true`, `fetch` и `update` создают пустой Response
**Action:** полная реализация через FirebaseAuth SDK (signIn/createUser/sendPasswordReset/signInWithCredential для Google)

### [P0-4] LiveSyncService — data race на nonisolated(unsafe) mutable state
**Файл:** `Sync/SyncService.swift:33-34`
**Проблема:** `_pendingCount` и `_isSyncing` — `nonisolated(unsafe) private var`, конкурентная запись из `enqueue()` и `drainQueue()`
**Action:** сделать LiveSyncService actor или защитить через NSLock/OSAllocatedUnfairLock

### [P0-5] ChildHomeView и ParentHomeView — VIP нарушение
**Файлы:** `ChildHomeView.swift:411-436`, `ParentHomeView.swift`
**Проблема:** `ChildHomeInteractor` и `ChildHomeViewModel` объявлены внутри файла View
**Action:** вынести Interactor в отдельный файл + запретить прямое наблюдение из View (через Presenter только)

### [P0-6] Hex-цвета в Features
**Файлы:** `ChildHomeView.swift:61-64`, `ParentHomeView.swift:233, 237`
**Проблема:** `Color(hex: "#FFF4EC")`, `Color(hex: "#FFF0E8")`, `Color(hex: "#E5A000")` — запрещено правилом проекта
**Action:** заменить на `DesignSystem.Colors.*` токены

### [P0-7] TODO в production коде (запрещено CLAUDE.md)
**Файл:** `AuthSignInView.swift:121`
**Проблема:** `coordinator.present(sheet: .settings) // TODO: replace with email auth sheet`
**Action:** реализовать переход на email auth + убрать TODO

### [P0-8] import Lottie — build error
**Файл:** `Features/Rewards/RewardsView.swift`
**Проблема:** `import Lottie` но Lottie нет в SPM dependencies
**Action:** добавить Lottie в project.yml → SPM, либо заменить на HSLottie wrapper если уже есть

---

## Важные замечания 🟡 (fix в M1 или M8)

### [P1-1] Force unwrap в AppContainer
**Файл:** `App/DI/AppContainer.swift:113-201`
**Проблема:** все 14 lazy-аксессоров заканчиваются на `return _audioService!`
**Action:** заменить pattern на `private lazy var _audioService: any AudioService = audioServiceFactory()`

### [P1-2] Force unwrap в ContentEngine
**Файл:** `Content/ContentEngine.swift:38`
**Проблема:** `let pack = loadedPacks[packId]!`
**Action:** `guard let pack = ... else { throw AppError.entityNotFound(packId) }`

### [P1-3] DispatchQueue.main.async в LiveHapticService
**Файл:** `Services/LiveServices.swift:127-142`
**Проблема:** нарушение Swift 6 strict concurrency
**Action:** добавить `@MainActor` к `LiveHapticService`

### [P1-4] Нелокализованные строки в UI (15+ файлов)
**Файлы:**
- `SessionCompleteView.swift:47,53,61,83,84` — «Занятие завершено!», «попыток за», «Результаты по словам», «Продолжить», «Повторить»
- `WorldMapView.swift:35` — «Карта звука \(targetSound)»
- `RewardsView.swift` — «Первый звук», «3 дня подряд», «Идеально!»
- `SessionHistoryView.swift` — «Все», «Сегодня», «Неделя», «История занятий»
- `ProgressDashboardView.swift` — «Прогресс», захардкоженный «87%»
- `ARZoneView.swift` — «AR-упражнения»
- `AuthSignInView.swift:82` — `Text("HappySpeech")` должно быть из Bundle
- `AppCoordinator sheetContent` — 4 заглушки-stub с нелокализованным текстом
- `RuleBasedDecisionService.swift:122-131` — «Отличное начало!», «Новый стикер...»

**Action:** вынести все в `Localizable.xcstrings` через `String(localized:)`

### [P1-5] WorldMapView — hardcoded stage
**Файл:** `WorldMapView.swift:10`
**Проблема:** `@State private var currentStageIndex: Int = 2` не загружается из репозитория
**Action:** получать из `ProgressRepository` через Interactor

### [P1-6] ProgressDashboardView — fake данные в UI
**Проблема:** «87%» захардкожена в StatCard, `Double.random` для прогресса стадий
**Action:** получать реальные данные из ProgressRepository

### [P1-7] ARZoneView — stub AR tracking
**Проблема:** `ARCoordinator.renderer` читает blendShapes и отбрасывает результат `_ = faceAnchor.blendShapes`
**Action:** реализовать полный pipeline в M5 (ARKit + Vision + MediaPipe + TonguePostureClassifier)

### [P1-8] LLMDecisionService: 12 из 25+ decision points
**Отсутствуют:** дифференциация звуков, AR-данные в decision loop, calendar-aware планирование, regression detection, sound promotion/demotion, specialist session planner, cross-session pattern analysis, story generation с target sound, minimal pairs generation, word set selection, phrase generation, fun fact, playful transition
**Action:** реализовать в M4.8

### [P1-9] LiveLocalLLMService — STUB
**Проблема:** все методы бросают `AppError.llmNotDownloaded`
**Action:** полная интеграция MLX Swift + Qwen2.5-1.5B-Instruct-4bit MLX в M4

### [P1-10] uploadToFirebase — STUB
**Проблема:** `try await Task.sleep(nanoseconds: 100_000_000)` вместо реального Firestore
**Action:** полная Firebase integration в M1.3

### [P1-11] LiveAdaptivePlannerService — SHALLOW
**Проблема:** hardcoded `childId="С"`, `recordCompletion` только логирует
**Action:** полная SM-2 реализация в M1.2

### [P1-12] ThemeApplier создаёт изолированный ThemeManager
**Проблема:** `.applyHSTheme()` создаёт новый `@State ThemeManager()` вместо использования контейнерного
**Action:** использовать environment ThemeManager, получать из AppContainer

### [P1-13] LLMInferenceActor — polling вместо continuation
**Файл:** `LLMInferenceActor.swift:58-63`
**Проблема:** `while isBusy { try await Task.sleep(...) }` — busy-wait pattern
**Action:** заменить на CheckedContinuation queue (не критично, но неэлегантно)

### [P1-14] ParentHomeView — 524 строки
**Action:** декомпозировать на ParentSessionCard, ParentHomeTaskCard, ParentStatsRow

### [P1-15] Все 16 LessonPlayer игр — Interactor-заглушки
**Action:** полная реализация в M6 (по одной игре, начать с `ListenAndChoose`)

---

## Предложения 🟢 (nice-to-have)

- `LLMModelDownloadManager` — fake progress-bar +0.02 каждые 500ms → заменить на реальный URLSession progress callback
- `AnalyticsEvent.sessionCompleted` логирует child_id в OSLog — добавить lint-правило запрещающее логировать childId/audioPath/name/age
- `ProgressPoint.sample` — force unwrap `Calendar.current.date(...)!` → добавить `#if DEBUG` guard
- VADService.swift (LiveVADService) — energy-stub, заменить на интеграцию с LiveSileroVAD
- Snapshot-тесты отсутствуют для всех новых экранов — добавить в M10

---

## Статус по слоям

| Слой | Статус |
|---|---|
| App/ | SHALLOW (coordinator stubs) |
| Core/ | PRODUCTION-READY |
| DesignSystem/ | PRODUCTION-READY |
| Services/ (протоколы + Mocks) | PRODUCTION-READY |
| Services/ (Live реализации) | MIXED (HapticService ANTI-PATTERN, LocalLLM STUB, AdaptivePlanner SHALLOW) |
| ML/ASR | PRODUCTION-READY |
| ML/LLM (routing) | PRODUCTION-READY (12 из 25+ decision points) |
| ML/PronunciationScorer | PRODUCTION-READY (scaffolding, но модели — energy stubs) |
| ML/SileroVAD | PRODUCTION-READY (scaffolding, но модель — energy stub) |
| ML/VAD (Service) | SHALLOW (energy stub) |
| Data/ | PRODUCTION-READY |
| Sync/ | SHALLOW + ANTI-PATTERN (race, stub Firebase upload) |
| Content/ | PRODUCTION-READY (engine готов, паки пустые) |
| Analytics/ | PRODUCTION-READY |
| Features/Auth | ANTI-PATTERN (stub + Apple Sign-in) |
| Features/ChildHome, ParentHome | ANTI-PATTERN (VIP violation + hex colors) |
| Features/Specialist, Settings, ARZone | SHALLOW |
| Features/Onboarding | PRODUCTION-READY |
| Features/SessionComplete, WorldMap, ProgressDashboard | SHALLOW + localization issues |
| Features/Rewards, SessionHistory, HomeTasks | SHALLOW + build error (Lottie import) |
| Features/LessonPlayer (16 игр) | STUB |
| Features/OfflineState | ANTI-PATTERN (preview-child-1 в production) |
| Features/Demo | SHALLOW |

---

## Kids Category compliance

- Нет Firebase Analytics, Crashlytics, Amplitude, Mixpanel: ✅ PASS
- HFInferenceClient не вызывается из kid circuit: ✅ PASS
- Нет внешних ссылок: ✅ PASS
- Персональные данные детей не логируются в текущем коде: ✅ PASS

---

## Priority Backlog для M1

### P0 (BLOCKING — исправить в M1):
1. Убрать Apple Sign-in, добавить Email+Password + Google Sign-in (Firebase Auth)
2. Исправить OfflineStateView `preview-child-1` bug
3. Рефакторить ChildHomeView и ParentHomeView (VIP violation)
4. Убрать hex-цвета из Features, использовать DesignSystem
5. Исправить data race в LiveSyncService (actor или lock)
6. Убрать все TODO/FIXME/HACK из production кода
7. Добавить Lottie в SPM (или убрать import)

### P1 (HIGH — M1 или M8):
8. Убрать force-unwrap из AppContainer, ContentEngine
9. @MainActor для LiveHapticService
10. Реальная Firebase integration (uploadToFirebase)
11. ThemeApplier — использовать environment ThemeManager
12. Полная реализация AdaptivePlannerService (SM-2)
13. Локализация всех UI строк в String Catalog
14. Декомпозировать ParentHomeView

### P2 (M4+):
15. Расширить LLMDecisionService до 25+ decision points (M4.8)
16. Интеграция MLX LocalLLMService (M4)
17. Замена energy-stub моделей на реальные нейросети (M4.3)
18. Реализация 16 LessonPlayer игр (M6)
19. Полный AR pipeline (M5)

---

## Файлы для немедленного исправления (M1)

- `/HappySpeech/Features/OfflineState/OfflineStateView.swift`
- `/HappySpeech/Features/Auth/AuthSignInView.swift`
- `/HappySpeech/Features/Auth/AuthInteractor.swift`
- `/HappySpeech/Features/ChildHome/ChildHomeView.swift` + вынос Interactor
- `/HappySpeech/Features/ParentHome/ParentHomeView.swift` + вынос Interactor + декомпозиция
- `/HappySpeech/Sync/SyncService.swift`
- `/HappySpeech/Services/LiveServices.swift` (LiveHapticService)
- `/HappySpeech/App/DI/AppContainer.swift`
- `/HappySpeech/Features/SessionComplete/SessionCompleteView.swift`
- `/HappySpeech/Features/Rewards/RewardsView.swift` (import Lottie — build error)
- `/HappySpeech/Features/WorldMap/WorldMapView.swift`
- `/HappySpeech/Features/ProgressDashboard/ProgressDashboardView.swift`
- `/HappySpeech/Features/SessionHistory/SessionHistoryView.swift`
- `/HappySpeech/Features/ARZone/ARZoneView.swift`
- `/HappySpeech/Content/ContentEngine.swift`
- `/HappySpeech/ML/LLM/RuleBasedDecisionService.swift`
- `/HappySpeech/App/Navigation/AppCoordinator.swift`
- `/HappySpeech/DesignSystem/Theme/ThemeApplier.swift` (или где сейчас)

---

## Итог

**NEEDS CHANGES — масштабная работа в M1.** Фундамент архитектуры (ML слой, Data слой, DI, Kids Category routing) сделан качественно, но Features layer содержит систематические нарушения. Приоритет немедленного исправления — P0 pункты. После M1 можно приступать к Content/ML/AR (M2–M5).

**Критический путь:**
- M1.1 ✅ audit done (этот файл)
- M1.2–M1.4 в работе → fix P0 + внедрение Core Services + Firebase Auth
- M1.5 AppContainer rewire + final `swiftlint --strict` clean

---

*Report by code-reviewer agent, 2026-04-23*
