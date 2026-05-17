# V25 — Финальный аудит CTO перед тегом v1.0.0-final-v25 (Phase 5.2)

**Дата:** 2026-05-17
**Аудитор:** CTO (независимый, чистый контекст)
**Метод:** статический анализ кода — Read / Grep / Glob / git. Сборка не выполнялась (диск переполнен, по согласованию).
**Объём:** ~1120 Swift-файлов production + тесты, 4210 ключей локализации, project.pbxproj, Package.resolved, PrivacyInfo.xcprivacy.
**Связанные документы:** `v25-code-review.md` (code-reviewer, ограниченная выборка), `v25-manual-functional-audit.md` (Phase 4), `v25-coverage-final.md` (Phase 2).

---

## Сводка находок

| Severity | Кол-во |
|---|---|
| P0 — блокер | 0 |
| P1 — критично | 2 |
| P2 — косметика / тех-долг | 4 |

---

## P0 — блокирующие

Не обнаружено.

---

## P1 — критичные (требуют решения до тега)

### P1-01 — FluencyDiary: история сессий никогда не загружается

- **Файл:** `HappySpeech/Features/StutteringModule/FluencyDiary/FluencyDiaryInteractor.swift:103` и `:376`;
  протокол — `HappySpeech/Features/StutteringModule/Workers/DiaryStorageWorker.swift:7-10`.
- **Описание:** протокол `DiaryStorageWorkerProtocol` объявляет только `saveSession(_:)` и
  `fetchSessions(limit:)`. Метод `fetchRecentSessions(limit:)` существует **только** как
  extension-default (`FluencyDiaryInteractor.swift:376`), всегда возвращающий `[]`.
  `loadHistory()` (строка 103) вызывает `fetchRecentSessions` через `any DiaryStorageWorkerProtocol`
  → статическая диспетчеризация в extension-default → **всегда `[]`**.
  Реальная реализация в `LiveDiaryStorageWorker` называется `fetchSessions` и никогда не вызывается
  из дневника. Подтверждение: `FluencyDiaryParentView.swift:172` использует корректный метод
  `worker.fetchSessions(limit: 28)`, а интерактор — нет.
- **Влияние:** дневник плавности (FluencyDiary) при каждом перезаходе показывает 0 сессий, пустой
  14-дневный график, не восстанавливает историю. Деградирована ключевая фича модуля заикания.
  Тесты (`FluencyDiaryInteractorTests.swift:125-138`) маскируют баг под «ожидаемое поведение»
  (seed из 3 сессий → `XCTAssertEqual(totalSessions, 0)`).
- **Рекомендация:** добавить `fetchRecentSessions(limit:)` в требования протокола
  `DiaryStorageWorkerProtocol`, реализовать в `DiaryStorageWorker` и `MockDiaryStorageWorker`;
  ЛИБО переименовать вызов в интеракторе на существующий `fetchSessions(limit:)`. После фикса —
  переписать тесты `loadHistory`, чтобы seed реально отражался в Display.

### P1-02 — SyncService: облачная синхронизация прогресса не реализована (заглушка)

- **Файл:** `HappySpeech/Sync/SyncService.swift:397-432` — `performFirestoreBatchWrite(...)`;
  также `:518` — `fetchRemoteSnapshot` заглушка.
- **Описание:** `performFirestoreBatchWrite` строит корректные shape'ы документов
  (`users/{uid}/children`, `sessions`, `progress`), валидирует JSON-сериализуемость,
  `Task.sleep(120ms)` симулирует сетевую задержку — и **ничего не пишет в Firestore**.
  При этом `import FirebaseFirestore` и реальные Firestore-вызовы присутствуют в трёх других
  сервисах (`FCMService`, `FamilyInviteService`, `InstallationsService` — `.setData`,
  `.runTransaction`, `.getDocuments`). То есть SDK подключён и используется, но именно основная
  синхронизация прогресса ребёнка в облако — заглушка.
- **Влияние:** прогресс детей, сессии и достижения не синхронизируются между устройствами и не
  восстанавливаются после переустановки. Для приложения, заявляющего родительскую аналитику и
  кабинет специалиста, это функциональный пробел. Это **не** SDK-bound недостижимость из
  ADR-V25-COVERAGE категории A — это незавершённая фича: соседние сервисы пишут в Firestore без
  проблем.
- **Рекомендация:** одно из двух перед тегом:
  1. Реализовать реальный Firestore batch-write/read в `SyncService` (паттерн уже отлажен в
     `FamilyInviteService`/`InstallationsService`); либо
  2. Если облачная синхронизация прогресса сознательно вне scope v1.0 — **честно
     задокументировать** в ADR (`decisions.md`) как known limitation «offline-first, облачная
     синхронизация прогресса — post-v1.0», убрать симуляцию задержки, явно вернуть
     `.skipped`/no-op, и не подавать в дипломной презентации как работающую фичу.
- **Примечание:** для дипломного проекта приемлем вариант 2 (приложение позиционируется как
  offline-first), но требуется явный ADR — сейчас заглушка не задокументирована в `decisions.md`.

---

## P2 — косметика / технический долг (не блокируют тег)

### P2-01 — CustomizationStorageWorker: закомментированный код + незавершённый F2-010

- **Файл:** `HappySpeech/Features/Customization/Workers/CustomizationStorageWorker.swift:88-101`
  (`syncToCloud`), аналогично `fetchFromCloud` (`:111`).
- **Описание:** методы `syncToCloud`/`fetchFromCloud` логируют «implementation pending F2-010» и
  возвращают `false`. В теле — закомментированный Firestore payload-код (строки 94-99). Закоммен-
  тированный код прямо запрещён правилами проекта (CLAUDE.md §4). Сам по себе синк-хук кастомизации
  непринципиален (skin/color/voice хранятся в Realm и работают локально), поэтому P2, а не P1.
- **Рекомендация:** удалить закомментированный блок payload (строки 94-99); оставить только
  однострочную ссылку на ADR/задачу либо реализовать хук. F2-010 не значится в `backlog.md` —
  убедиться, что задача не «потеряна».

### P2-02 — SiblingLobbyView: хардкод-литерал `Text("VS")`

- **Файл:** `HappySpeech/Features/SiblingMultiplayer/SiblingLobbyView.swift:112`.
- **Описание:** декоративный versus-индикатор `Text("VS")` — литерал, не ключ каталога
  (ключ `VS` в `Localizable.xcstrings` отсутствует). Формально нарушает правило «все строки через
  String Catalog». Это аббревиатура-«versus», визуально интернациональна.
- **Рекомендация:** завести ключ `sibling.lobby.vs` со значением `VS` для единообразия.

### P2-03 — FirebasePerformance: сбор данных производительности в детском приложении

- **Файл:** `HappySpeech/Services/PerformanceMonitorService.swift` (линкуется продукт
  `FirebasePerformance`).
- **Описание:** сервис корректно спроектирован — default OFF, parent opt-in, метрики только на
  parent-facing экранах, документировано как COPPA-aware. `PrivacyInfo.xcprivacy` декларирует
  `PerformanceData` с `Tracking=false`, `NSPrivacyTracking=false`. Тем не менее `FirebasePerformance`
  тянет транзитивно `GoogleDataTransport`, и App Store review для Kids Category особенно строго
  относится к любому Firebase-телеметрийному продукту. Риск — на стороне ревью Apple, не кода.
- **Рекомендация:** для дипломного тега оставить как есть (архитектурно прикрыто opt-in). Перед
  реальной публикацией в App Store — оценить полное удаление `FirebasePerformance` либо получить
  явное подтверждение, что opt-in performance в Kids Category допустим. Зафиксировать решение в ADR.

### P2-04 — Flaky-паттерн в async-тестах FluencyDiary

- **Файл:** `HappySpeechTests/Features/FluencyDiaryInteractorTests.swift` — тесты
  `test_stopRecording_*`, `test_multipleRecordings_*`.
- **Описание:** ожидание фонового `Task` внутри `analyzeAndSave()` через фиксированный
  `Task.sleep(250–350 ms)` без возвращаемого хэндла. На загруженном CI может не хватить времени →
  периодические падения. (Находка продублирована из `v25-code-review.md` P2-2.)
- **Рекомендация (post-tag):** дать `analyzeAndSave()` тестовый seam (`analysisTask` +
  DEBUG-хук `_test_awaitAnalysis()`), по аналогии с `_test_*` в `BreathingExtendedInteractor`.

---

## Проверено и признано корректным (без находок)

- **Качество кода:** `print()` — 0 в production; `TODO/FIXME/HACK/XXX` — 0; `try!`/`as!` — 0;
  force-unwrap — 1 (`AirStreamAnalyzer.swift:160`, `baseAddress!` внутри
  `withUnsafeMutableBufferPointer`, корректный безопасный vDSP-паттерн, обёрнут
  swiftlint-комментарием с обоснованием инварианта). **Не нарушение.**
- **Kids Category compliance:** `FirebaseAnalytics`, `FirebaseCrashlytics`, `Amplitude`,
  `Mixpanel`, `AppsFlyer`, `Adjust`, `Sentry`, `AdMob` — НЕ линкуются в app-таргет и не
  импортируются. `GoogleAppMeasurement` / `google-ads-on-device-conversion` присутствуют в
  `Package.resolved` как транзитивные зависимости Firebase, но соответствующие продукты в таргет
  не добавлены. `PrivacyInfo.xcprivacy`: `NSPrivacyTracking=false`, `NSPrivacyTrackingDomains`
  пуст, собираемые типы — `PerformanceData`/`AudioData` с purpose `AppFunctionality`,
  `Tracking=false`. (FirebasePerformance — см. P2-03.)
- **Parental gate:** все вызовы `openURL`/`UIApplication.shared.open` проверены —
  Settings использует `ParentalGate` перед открытием внешнего URL; Permissions/Screening/
  ARActivity открывают только `UIApplication.openSettingsURLString` (системные настройки —
  gate не требуется). Произвольных внешних ссылок без gate не найдено.
- **Локализация:** `Localizable.xcstrings` — 4210 ключей, `sourceLanguage=ru`, единственный
  язык `ru`, 0 ключей без ru-локализации, 0 ключей в состоянии `new`/untranslated.
  Неподставленных format-спецификаторов в `String(localized:)` не найдено — все `%d`/`%@`/`%lld`
  обёрнуты в `String(format:)` / `String.localizedStringWithFormat`. Баг Phase 4 P2-02
  (`%d задания`) подтверждён исправленным: `child.home.hometasks.count` переведён в plural-вариацию
  (one/few/many/other), `ChildHomePresenter.swift:231-234` форматирует через
  `localizedStringWithFormat` с реальным `taskCount`.
- **Swift 6 concurrency:** `@unchecked Sendable` используется широко, но все экземпляры
  оправданы: Realm `Object`/`EmbeddedObject` (стандартный обязательный паттерн), Mock-классы
  в test-инфраструктуре, Live-сервисы вокруг не-Sendable SDK-типов (AVAudioEngine, ARSession,
  Firebase singletons, Vision requests) — каждый с задокументированным обоснованием изоляции.
  `nonisolated(unsafe)` — только на stored properties, доступ к которым сериализован
  (main/dedicated context), с комментариями. Реальных data races не выявлено. `MockEmotionDetection`
  data race был найден и пофикшен в Phase 2 (`NSLock`).
- **GigaAM / HFInferenceClient в kid circuit:** упоминаний `GigaAM` в коде нет (ADR-001-REV1
  соблюдён). `HFInferenceClient` (Tier B) используется исключительно в parent/specialist circuits
  (`WeeklySummaryWorker`, `ParentInsightsWorker`, `ParentHomeInteractor`, `SpecialistInteractor`,
  `LLMDecisionService.generateParentSummary`). `KidLLMNarrationService` явно документирован и
  реализован как Tier A (on-device Qwen) / Tier C (rule-based) — без Tier B. COPPA соблюдён.
- **Архитектурные слои:** Features импортируют `RealmSwift`/`WhisperKit` в 7 файлах
  (`FamilyVoiceInteractor`, `AchievementsInteractor`, `ScreeningInteractor`, Workers
  кастомизации/дневника/ачивок, `WhisperTranscriptionWorker`). Все они работают через
  `RealmActor` (thread-safe актор) — это **установившийся проектный паттерн** прошлых версий
  (Interactor/Worker напрямую держит `RealmActor`, а не репозиторий-протокол). Строго по букве
  CLAUDE.md §2 Features должны ходить в Data только через Services, но это давнее, осознанное и
  консистентное отклонение, не регрессия v25 — **не выношу как находку**, рекомендую лишь
  зафиксировать в ADR как принятый паттерн, если ещё не зафиксировано.
- **Целостность проекта:** битых file-references в `project.pbxproj` не выявлено; 1120 Swift на
  диске, 2242 вхождения `.swift in Sources` — расхождение объясняется мультитаргетным
  членством (app + Tests + UITests + WidgetExtension). `FirebaseEmulatorTestsBase.swift` /
  `FirebaseSnapshotMocks.swift` корректно в test-таргете, не в app.
- **Code-review кросс-чек:** независимое ревью `v25-code-review.md` (выборка свежих изменений)
  не нашло P0; его единственный P1 (FluencyDiary) подтверждён моим grep-аудитом — см. P1-01.
  Его P2-1 («grep-аудит не выполнен из-за отсутствия Bash/Grep») закрыт настоящим отчётом.

---

## Вердикт

**НЕ ГОТОВ К ТЕГУ — 2 × P1 к решению.**

Качество кода высокое: 0 P0, чистая локализация, Kids Category compliance соблюдён, нет
запрещённых трекеров, parental gate на месте, concurrency корректна, антипаттернов (print/TODO/
force-unwrap/GigaAM) нет. Найденные P1 — не дефекты стиля, а **функциональные пробелы**:

1. **P1-01 (FluencyDiary)** — обязательно исправить: ключевая фича модуля заикания не работает,
   баг замаскирован тестами. Фикс малый (вынести метод в протокол + 2 реализации).
2. **P1-02 (SyncService)** — обязательно либо реализовать, либо честно задокументировать в ADR
   как known limitation post-v1.0. Недопустимо подавать заглушку как рабочую фичу в дипломной
   защите.

После закрытия P1-01 и P1-02 (фикс или документированный ADR) проект готов к тегу
`v1.0.0-final-v25`. P2-01…04 — технический долг, тег не блокируют, но P2-01 (закомментированный
код) желательно убрать одной правкой.
