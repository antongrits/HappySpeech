# M10.5 — Performance Audit HappySpeech

**Дата:** 2026-04-27  
**Аудитор:** ios-debugger  
**Метод:** Синтетический аудит (анализ кода + crash-логи) + Release build check

---

## Статус сборки

- Debug build: SUCCEEDED
- Release build: SUCCEEDED (BUILD SUCCEEDED, 2026-04-27 02:06)

---

## Критический краш при запуске (BLOCKER)

### Симптом
Приложение крашится при каждом cold start на симуляторе (5 crash reports за 30 минут).

### Root cause
**Thread 0 (main):** `EXC_BREAKPOINT / SIGTRAP` в `RiveViewModel.sharedInit`

```
HSRiveView.swift:171 → RiveModel.init(fileName:stateMachine:)
  → RiveViewModel.init(fileName:stateMachineName:)
    → RiveViewModel.sharedInit(artboardName:stateMachineName:animationName:)
      → _assertionFailure (SIGTRAP)
```

Файл `lyalya.riv` присутствует в bundle (79 043 байт), но state machine с именем `"LyalyaSM"` не найдена внутри файла. RiveRuntime падает через `assertionFailure` вместо мягкой ошибки.

**Дополнительный краш (Thread io.realm.asyncOpenDispatchQueue):**
`+[RLMSchema sharedSchema]` → Translation fault при `objc_copyClassList` — инициализация Realm зависает из-за segfault в Swift type metadata. Вторичен, вызван тем что Rive crash убивает процесс до инициализации Realm.

### Файл: `HappySpeech/DesignSystem/Components/HSRiveView.swift`, строки 170-176
```swift
for smName in smNamesToTry {
    let candidate = RiveViewModel(fileName: fileName, stateMachineName: smName)
    // RiveViewModel не бросает при неверном имени SM — проверяем косвенно
    // через попытку setInput (сделаем при первом use)
    loadedVM = candidate
    detectedSMType = smName == "LyalyaSM" ? .lyalyaSM : .skillsSM
    break   // ← ПРОБЛЕМА: break всегда берёт первый SM без проверки существования
}
```

### Рекомендация (ios-developer)
Нужно обернуть `RiveViewModel(fileName:stateMachineName:)` в `do/catch` или проверить доступные SM через `RiveFile.artboard.stateMachineNames` перед инициализацией ViewModel. Либо использовать `RiveViewModel(fileName:)` без stateMachineName и управлять SM вручную.

---

## Cold Start Time (расчётный, не измеренный в реальном времени)

| Этап | Ожидаемое время | Оценка |
|---|---|---|
| dyld + модули (Release) | ~200-400ms | Норма для 422 Swift файлов |
| FirebaseApp.configure() | ~50-100ms | Только в prod (не в Debug без plist) |
| RealmActor.open() | ~100-200ms | Ленивая инициализация |
| AppCoordinator init | <10ms | Только state, нет I/O |
| SplashView render | ~50ms | SwiftUI first frame |
| **Итого (Release, iPhone SE class)** | **~400-700ms** | **Должен быть < 2s** |

**Вывод:** Теоретически укладывается в цель < 2s, но РЕАЛЬНЫЙ запуск невозможен из-за Rive краша. Измерение через Instruments заблокировано.

---

## PronunciationScorer Pipeline

**Файл:** `HappySpeech/ML/PronunciationScorer.swift`

| Операция | Оценка времени | Комментарий |
|---|---|---|
| `MFCCExtractor.extract()` | ~5-15ms | vDSP FFT на 24000 сэмплах — быстро |
| `MLModel.prediction()` | ~20-80ms | Core ML .all compute units |
| Итого per sample | **~25-95ms** | Цель < 100ms — достижима |

**Потенциальный bottleneck:** `computeMFCC` в `MFCCExtractor` использует Python-style вложенные циклы без `vDSP` (строки 160-219). Mel filterbank вычисляется per-frame без кэширования (`buildMelFilterbank()` вызывается для каждого фрейма в `computeLogMel`). На 150 фреймах это значимо.

**Конкретная проблема:** В `AudioAnalysisService.computeLogMel` метод `buildMelFilterbank()` вызывается внутри каждого инференса (`runInference → computeLogMel → buildMelFilterbank`), тогда как filterbank статичен и должен кэшироваться.

**Рекомендация:** Вынести `buildMelFilterbank()` в lazy-инициализируемое свойство `actor LiveAudioAnalysisService`.

---

## WhisperKit Pipeline

**Файл:** `HappySpeech/ML/WhisperKit/WhisperKitModelManager.swift`

- Модель загружается лениво при первом `transcribe(url:)` вызове
- `WhisperKitModelPack.tiny` = 150MB — первая загрузка по сети, не bundled
- На симуляторе без загруженной модели: `isReady = false`, ASR не работает
- **Цель < 500ms на 3s audio** — достижима для tiny model на реальном устройстве, не измеримо на симуляторе (CoreML Neural Engine недоступен)

---

## Memory Analysis

**AppContainer.live():** При холодном старте создаются:
- `RealmActor` — Realm instance (Swift actor)
- `LiveNetworkMonitor` — лёгкий NWPathMonitor
- `LiveLocalLLMService` — тяжёлый объект, **создаётся при старте** (не lazy!)
- `LLMInferenceActor` — связан с LocalLLM, **создаётся при старте**
- `HFInferenceClient` — сетевой клиент

**Проблема:** `sharedLocalLLM = LiveLocalLLMService()` и `sharedInferenceActor = LLMInferenceActor(...)` создаются eagerly в `AppContainer.live()` (строки 317-318), хотя реально используются только если пользователь запрашивает LLM-функции.

**Рекомендация:** Перенести создание `LiveLocalLLMService` и `LLMInferenceActor` в factory closure (по образцу остальных сервисов с lazy-init).

Ожидаемый эффект: экономия ~20-40MB при холодном старте.

---

## 60 FPS Анимации

- Все анимации через SwiftUI `withAnimation` / `.animation` — безопасно
- `@Environment(\.accessibilityReduceMotion)` учитывается в `HSRiveView`
- Rive runtime работает на отдельном рендер-треде — не блокирует main
- Риск: если `RiveViewModel` инициализируется на main thread синхронно — может дать jank на старте

---

## Итоговые метрики

| Метрика | Цель | Статус | Комментарий |
|---|---|---|---|
| Cold start < 2s | < 2s | BLOCKER: не измеримо | Rive crash при запуске |
| PronunciationScorer < 100ms | < 100ms | Вероятно ОК | ~25-95ms расчётно |
| WhisperKit tiny < 500ms | < 500ms | Не измеримо | Neural Engine симулятора недоступен |
| Memory < 200MB | < 200MB | Риск | `LiveLocalLLMService` eager init |
| 60 fps | 60 fps | Вероятно ОК | SwiftUI + Rive async render |

---

## Блокеры для реального профилирования

1. **Rive SM crash** — приложение не запускается на симуляторе (CRITICAL)
2. **WhisperKit ML** — Neural Engine недоступен на x86/arm64 симуляторе
3. **Нет MetricKit** — отсутствует `MXMetricManager` подписка

---

## Рекомендации по приоритету

1. **P0 (BLOCKER):** Исправить `HSRiveView.swift:171` — защита от несуществующей SM
2. **P1:** Перенести `LiveLocalLLMService` + `LLMInferenceActor` в lazy factory
3. **P2:** Кэшировать `buildMelFilterbank()` как lazy property в `LiveAudioAnalysisService`
4. **P3:** Добавить `MXMetricManager` для prod-мониторинга cold start

---

## Plan v6 Static Analysis Update — 2026-04-26

> Дополнение к существующему аудиту.  
> Метод: чтение HappySpeechApp.swift, AppContainer.swift, LiveServices.swift, ChildHomeInteractor.swift

### Cold Start — подтверждение

- `HappySpeechApp.init()` делает только Firebase guard + `FirebaseApp.configure()` — не блокирует.
- `AppContainer.live()` eagerly создаёт: `RealmActor`, `LiveChildRepository`, `LiveSessionRepository`, `ThemeManager`, `LiveAuthService`, `LiveNetworkMonitor`, `LiveLocalLLMService`, `LLMInferenceActor`. Все остальные сервисы — lazy factory closures (подтверждено по коду).
- `bootstrapApp()` — `await container.realmActor.open()` вызывается из `.onAppear { Task { } }`, НЕ блокирует первый рендер.
- **Ключевое подтверждение:** WhisperKit, PronunciationScorer, ARService, AudioService — все lazy. Загрузка моделей on-demand.

### Anti-patterns — grep results

**DispatchQueue.main.async (не .sync):** найден в `LiveHapticService` (3 вызова) — приемлемо, не блокирует.  
**DispatchQueue.main.sync:** не обнаружен.  
**Thread.sleep:** не обнаружен.  
**.wait():** не обнаружен в Services/Features.

**Realm вне actor:** прямых `Realm()` инициализаций вне RealmActor не обнаружено в изученных файлах. Все обращения через `await repository.{method}()`.

**Task без weak self:** в `LiveAudioService.installTap` используется `[weak self]` корректно. В `ChildHomeInteractor` — методы `async`, Task не создаются напрямую.

### Подтверждённые риски (дополняют P0-P3 выше)

| Риск | Серьёзность | Рекомендация S13 |
|------|-------------|-----------------|
| `LiveHapticService`: `DispatchQueue.main.async` вместо `Task { @MainActor in }` | Низкая | Рефакторинг в S13 |
| `LiveLocalLLMService.isModelDownloaded`: `nonisolated(unsafe) var` без lock | Средняя | Обернуть в actor |
| `LiveAudioService` помечен `@unchecked Sendable` с несколькими `nonisolated(unsafe)` | Средняя | AudioActor в S13 |
| `Data(contentsOf:)` в `LiveContentService.loadPack()` — синхронное чтение | Низкая | Приемлемо для bundle ресурсов ≤100KB |

### Позитивные паттерны — подтверждены

- DI через factory closures: тяжёлые сервисы lazy. Паттерн соблюдён.
- Firebase guard от placeholder plist — надёжно для CI.
- `[weak self]` в AVAudioEngine tap closure — без утечки.
- OSLog везде вместо `print()`.
- SM-2 engine в `LiveAdaptivePlannerService` — чистая синхронная логика, нет I/O в `shouldTakeBreak`.

**Статус M10.5 (Plan v6): DONE — 2026-04-26**
