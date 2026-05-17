# v25 Code Review — HappySpeech (Phase 5.2)

**Дата:** 2026-05-17
**Ревьюер:** code-reviewer (независимый, чистый контекст)
**Цель:** финальное ревью перед тегом `v1.0.0-final-v25`

---

## ВАЖНОЕ ОГРАНИЧЕНИЕ ЭТОГО РЕВЬЮ

В рабочей среде ревьюера были доступны **только инструменты Read и Write** — без
`Bash`, `Grep`, `Glob`. Это сделало невозможным:

- полнотекстовый поиск по 177K LOC (`force-unwrap`, `print()`, `TODO/FIXME`,
  хардкод hex/строк, `@unchecked Sendable`, `GigaAM`, `HFInferenceClient` в kid
  circuit);
- получение `git diff v1.0.0-final-v24..HEAD` и списка коммитов v25;
- проверку файлов по имени (ML/Kid LLM circuit, ASRService и пр.).

**Фактически отревьюировано:** все файлы, изменённые в текущем рабочем дереве
(`git status` snapshot) — это самые свежие незакоммиченные правки v25, плюс
несколько ключевых View. Это репрезентативная, но **не исчерпывающая** выборка.
Вердикт ниже распространяется только на отревьюированный объём; полный
grep-аудит антипаттернов по всему репозиторию **не выполнен** и должен быть
проведён отдельно (рекомендация P2 ниже).

**Отревьюированные файлы:**

- `Features/StutteringModule/BreathingExtended/BreathingExtendedInteractor.swift`
- `Features/StutteringModule/FluencyDiary/FluencyDiaryInteractor.swift`
- `Features/SessionShell/SessionShellView.swift`
- `Features/SessionShell/SessionShellViewComponents.swift` (частично)
- `Features/LessonPlayer/RepeatAfterModel/RepeatAfterModelView.swift`
- `HappySpeechTests/Features/BreathingExtendedInteractorTests.swift`
- `HappySpeechTests/Features/FluencyDiaryInteractorTests.swift`
- `HappySpeechTests/Games/RhythmInteractorTests.swift` (частично)
- `HappySpeechTests/StutteringModule/MetronomeInteractorTests.swift` (частично)
- `HappySpeechTests/ParentChild/FamilyVoiceInteractorTests.swift` (частично)

---

## Находки

### P0 — блокирующие

Не обнаружено в отревьюированной выборке.

### P1 — важные

**[P1-1] FluencyDiary: история сессий никогда не загружается (функциональный баг)**

- **Файл:** `Features/StutteringModule/FluencyDiary/FluencyDiaryInteractor.swift:102-110`
  и `:375-377`.
- **Описание:** `loadHistory()` вызывает `storageWorker.fetchRecentSessions(limit:)`.
  Этот метод **не входит** в требования протокола `DiaryStorageWorkerProtocol` —
  он объявлен только как protocol-extension с дефолтной реализацией:

  ```swift
  extension DiaryStorageWorkerProtocol {
      func fetchRecentSessions(limit: Int) async -> [FluencySessionData] { [] }
  }
  ```

  Поскольку `storageWorker` хранится как `any DiaryStorageWorkerProtocol`, вызов
  диспетчеризуется **статически** к extension-default → всегда `[]`. Реальная
  реализация в `LiveDiaryStorageWorker` (если она называется иначе, например
  `fetchSessions`) **никогда не вызывается**. Результат: дневник плавности при
  каждом перезаходе показывает 0 сессий, пустой 14-дневный график и не
  восстанавливает историю. Это деградирует ключевую фичу модуля заикания.
- **Подтверждение:** сам тест-файл `FluencyDiaryInteractorTests.swift:14-23` и
  `:125-138` это документирует и подгоняет ассерты под баг
  (`test_loadHistory_handlesEmptyExtensionResult`: seed из 3 сессий →
  `XCTAssertEqual(sut.display.totalSessions, 0)`). Mock реализует
  `fetchSessions(limit:)`, а не `fetchRecentSessions(limit:)` — то есть mock и
  интерактор расходятся по имени метода.
- **Рекомендация:** добавить `func fetchRecentSessions(limit: Int) async ->
  [FluencySessionData]` в **сам протокол** `DiaryStorageWorkerProtocol`
  (requirement, а не extension), реализовать его в `LiveDiaryStorageWorker` и в
  `MockDiaryStorageWorker`. После этого переписать тесты `loadHistory` так,
  чтобы seed реально отражался в Display (`totalSessions == 3` и т.д.).
  Альтернатива: переименовать вызов в интеракторе на реальный метод протокола.

### P2 — улучшения / технический долг

**[P2-1] Полный grep-аудит антипаттернов не выполнен**

- Из-за отсутствия `Grep/Bash` не проверены по всему репозиторию: `print()`,
  `TODO/FIXME/HACK/XXX`, force-unwrap `!` в production, хардкод hex/русских
  строк, упоминания `GigaAM`, вызовы `HFInferenceClient` из kid circuit,
  все `@unchecked Sendable`.
- **Рекомендация:** перед тегом прогнать в обычной среде:
  `grep -rn "print(" HappySpeech/Features HappySpeech/Services HappySpeech/App`,
  `grep -rni "gigaam\|TODO\|FIXME\|HACK" HappySpeech/`, `swiftlint --strict`.
  По логам sprint.md эти проверки исторически были зелёными (0 print, 0 TODO,
  0 hex), но для финального тега их нужно подтвердить заново.

**[P2-2] Flaky-паттерн в async-тестах FluencyDiary**

- **Файл:** `HappySpeechTests/Features/FluencyDiaryInteractorTests.swift` —
  тесты `test_stopRecording_*`, `test_multipleRecordings_*` используют
  фиксированные `Task.sleep(for: .milliseconds(250...350))` для ожидания
  завершения фонового `Task` внутри `analyzeAndSave()`.
- **Описание:** `analyzeAndSave()` запускает detached-подобный `Task` без
  возвращаемого хэндла, поэтому тест не может его дождаться детерминированно и
  полагается на таймаут. На загруженном CI 250–300 мс может не хватить →
  периодические падения.
- **Рекомендация (post-tag, не блокирует):** дать `analyzeAndSave()` тестовый
  seam — например, `private var analysisTask: Task<Void, Never>?` и DEBUG-хук
  `_test_awaitAnalysis()` по аналогии с `_test_*` в `BreathingExtendedInteractor`.

**[P2-3] RepeatAfterModelView: парсинг числа из локализованной строки**

- **Файл:** `Features/LessonPlayer/RepeatAfterModel/RepeatAfterModelView.swift:695-701`.
- **Описание:** `currentAttemptsLeft` вытаскивает количество попыток, выдёргивая
  цифры из локализованной строки `display.attemptsLabel` (формат «Попыток
  осталось: %lld»). Это хрупко: при изменении формата строки в каталоге или при
  локали, где число содержит разделители разрядов, парсинг сломается молча.
- **Рекомендация (post-tag):** Presenter должен класть в Display числовое поле
  `attemptsLeft: Int` отдельно от форматированной строки. View не должен
  реверс-инжинирить ViewModel-строки.

**[P2-4] `MockMetronomeHapticService` — `@unchecked Sendable` с mutable-состоянием**

- **Файл:** `HappySpeechTests/StutteringModule/MetronomeInteractorTests.swift:6-16`.
- **Описание:** mock помечен `@unchecked Sendable`, но имеет незащищённый
  mutable `var playedPatterns`. В рамках `@MainActor`-теста это безопасно (все
  обращения на main), но `@unchecked` глушит проверку компилятора. Не дефект,
  но потенциальный источник скрытой гонки, если mock переиспользуют вне main.
- **Рекомендация: ** оставить как есть для тега (приемлемо в test-таргете),
  при желании — `final class ... : @unchecked Sendable` заменить на actor или
  `@MainActor`-mock.

---

## Что отревьюировано и признано корректным

- **Clean Swift VIP:** `SessionShellView` — образцовый разрез
  View/Host/Binder/State, VIP-стек живёт в Host, Binder — чистый рендер.
  `RepeatAfterModelView` — вся логика в Interactor, View только рендер +
  dispatch. Бизнес-логики во View не найдено.
- **Swift 6 concurrency:** `BreathingExtendedInteractor` и
  `FluencyDiaryInteractor` корректно `@MainActor`, все замыкания используют
  `[weak self]`, переходы через actor — `await MainActor.run` / `Task { @MainActor }`.
  `BreathingExtendedPresenterAdapter` — `@MainActor`, callback типизирован
  `@MainActor`. Реальных data race не обнаружено.
- **Cancellation:** `phaseTask`, `asrTask`, `letterHighlightTask`,
  `modelPlaybackTask` — все корректно `.cancel()` в `onDisappear` / `cancel()`,
  с проверками `Task.isCancelled`.
- **Локализация:** все user-facing строки через `String(localized:)`;
  плейсхолдеры `%@`/`%lld` подставляются (`session.placeholder.target_sound %@`,
  `repeat.attempts.dot.a11y \(used) \(totalAttempts)` и др.). Неподставленных
  плейсхолдеров не найдено.
- **Дизайн-токены:** только `ColorTokens.*`, `TypographyTokens.*`,
  `SpacingTokens.*`, `RadiusTokens.*`. Хардкод hex / `.font(.system(size:))`
  отсутствует (один `Image.font(.system(size: 64...))` в `rewardOverlay` — это
  размер SF Symbol, не цвет, легально).
- **Accessibility:** `.accessibilityLabel` / `.accessibilityHint` /
  `.accessibilityIdentifier` присутствуют на интерактивных элементах; Reduce
  Motion учтён (`reduceMotion ? nil : .animation(...)`).
- **Тесты:** не «пустышки» — реальные spy/mock-presenter, проверка состояния
  Display, граничные случаи (пустой массив, clamp, идемпотентность).
  UNTESTABLE-границы (AVAudioEngine / WhisperKit / TTS-синглтоны) честно
  документированы, а синхронная бизнес-логика покрыта через DEBUG `_test_*`
  хуки без изменения прод-поведения. Логгирование персональных данных детей не
  обнаружено — везде `privacy: .public` только на технических значениях.
- **OSLog:** используется `HSLogger`, `print()` в отревьюированных файлах нет.

---

## Вердикт

**УСЛОВНО APPROVED — с одним P1, требующим решения.**

В отревьюированной выборке свежих изменений v25 регрессий и плохих паттернов в
новых тестах/фиксах **не обнаружено**; качество кода высокое, VIP и concurrency
соблюдены.

Перед тегом `v1.0.0-final-v25` необходимо:

1. **[P1-1]** Принять решение по багу `FluencyDiary.loadHistory()`. Либо
   исправить (вынести `fetchRecentSessions` в требования протокола), либо —
   если фича сознательно отложена — задокументировать в ADR как known
   limitation. В текущем виде дневник плавности не восстанавливает историю, а
   тесты это маскируют под «ожидаемое поведение».
2. **[P2-1]** Подтвердить нулевые результаты grep-аудита (`print`, `TODO`,
   `GigaAM`, hex, force-unwrap) и `swiftlint --strict` в полноценной среде —
   данное ревью этого технически выполнить не смогло.

P2-2/3/4 — технический долг, не блокируют тег.
