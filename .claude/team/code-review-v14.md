# Code Review Plan v14 + Post-final
**Reviewer:** BB (independent)  
**Date:** 2026-05-02  
**Scope:** Plan v14 (19 blocks) + post-final blocks T/U/V/X/W/Y/Z/AA  
**Files reviewed:** ~20 Swift source files, project.pbxproj, Localizable.xcstrings

---

## Severity Summary

- **P0 (blocking):** 2 issues
- **P1 (high):** 6 issues
- **P2 (medium):** 7 issues
- **P3 (cosmetic):** 5 issues

---

## P0 Issues

### P0-1: LyalyaMascotView — hardcoded color literals в production View

**File:** `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift`, строки 257–262

```swift
case .warm:
    return Color(red: 1.0, green: 0.95, blue: 0.95)
case .cool:
    return Color(red: 0.95, green: 0.97, blue: 1.0)
case .nature:
    return Color(red: 0.95, green: 1.0, blue: 0.95)
```

Прямые RGB hex-литералы в DesignSystem-компоненте нарушают правило «никаких hex-цветов в фичах — только через ColorTokens». Нарушение архитектурного правила кодовой базы.

**Исправление:** Добавить токены `ColorTokens.Skin.warm`, `ColorTokens.Skin.cool`, `ColorTokens.Skin.nature` в `DesignSystem/Tokens/Colors.swift` и ссылаться на них.

---

### P0-2: SettingsInteractor — type-cast к конкретной реализации (`as? NotificationServiceLive`)

**File:** `HappySpeech/Features/Settings/SettingsInteractor.swift`, строки 337, 354

```swift
if let live = notificationService as? NotificationServiceLive {
    await live.scheduleDailyKidReminder(childName: settings.childName)
}
if let live = notificationService as? NotificationServiceLive {
    await live.scheduleWeeklyParentSummary(achievementsCount: 0, streakDays: 0)
}
```

Interactor напрямую знает о конкретной реализации сервиса, нарушая принцип инверсии зависимостей и DI-правило проекта. При мок-подстановке (тесты, Preview) функционал молча пропускается без ошибки.

**Исправление:** Расширить протокол `NotificationService` методами `scheduleDailyKidReminder(childName:)` и `scheduleWeeklyParentSummary(achievementsCount:streakDays:)`, реализовать их в Live и Mock классах.

---

## P1 Issues

### P1-1: ARZoneInteractor — двойной вызов `presenter?.presentLoadGames` без Task cancellation

**File:** `HappySpeech/Features/ARZone/ARZoneInteractor.swift`, строки 56–77

Interactor вызывает `presenter?.presentLoadGames` немедленно (строка 77), а затем повторно внутри `Task` (строка 67). Второй вызов не проверяет, отменён ли Task или сменился ли экран. При быстрой навигации назад возможен вызов presenter на уже освобождённый (или новый) экран.

**Исправление:** Хранить Task в `private var loadTask: Task<Void, Never>?`, при повторном вызове `loadGames` отменять предыдущий через `loadTask?.cancel()`. Добавить `guard !Task.isCancelled else { return }` после `await`.

---

### P1-2: AppContainer.live() — `HFInferenceClient` создаётся безусловно и передаётся в `LiveLLMDecisionService`

**File:** `HappySpeech/App/DI/AppContainer.swift`, строки 514, 550–554

```swift
let sharedHFClient = HFInferenceClient()
...
LiveLLMDecisionService(
    inferenceActor: sharedInferenceActor,
    hfClient: sharedHFClient,
    ...
)
```

`HFInferenceClient` создаётся для всего приложения, включая детский контур. Согласно правилу COPPA: HFInferenceClient используется ТОЛЬКО в parent/specialist circuit. Проверить, что `LiveLLMDecisionService` внутри действительно блокирует Tier B (HF) для kid circuit, и что `HFInferenceClient` никогда не вызывается из `KidLLMNarrationService`. Если `LiveLLMDecisionService` реализован правильно — угрозы нет, но архитектурный риск остаётся: любой рефакторинг может случайно активировать HF в kid circuit.

**Исправление:** Создавать `HFInferenceClient` только в parent/specialist DI-ветке; в kid DI-ветке передавать `nil` или заглушку.

---

### P1-3: ChildHomeInteractor — `buildSeedResponse` имеет hardcoded строку `"Звук Р"`

**File:** `HappySpeech/Features/ChildHome/ChildHomeInteractor.swift`, строка 581

```swift
let title = response.dailyTargetSound.isEmpty ? "Звук Р" : "Звук \(response.dailyTargetSound)"
```

Захардкоженная русская строка `"Звук Р"` в Interactor нарушает правило «все user-facing строки через `String(localized:)`». При смене языка интерфейс сломается.

**Исправление:** `String(localized: "widget.mission.default_title")` + добавить ключ в Localizable.xcstrings.

---

### P1-4: LiveSileroVAD — `runInference` определён, но никогда не вызывается (dead code)

**File:** `HappySpeech/ML/SileroVAD.swift`, строки 228–238

```swift
private func runInference(
    chunk: AVAudioPCMBuffer,
    model: MLModel
) async throws -> Float {
    ...
    return try await runChunkInference(samples: samples, model: model)
}
```

Метод `runInference(chunk:model:)` объявлен в actor, принимает `AVAudioPCMBuffer`, но нигде не вызывается — весь основной путь идёт через `runChunkInference(samples:model:)`. Dead code создаёт путаницу и не проходит SwiftLint dead_code правило.

**Исправление:** Удалить метод `runInference(chunk:model:)`.

---

### P1-5: LiveFCMService — Firestore write без явной проверки App Check / auth статуса

**File:** `HappySpeech/Services/FCMService.swift`, строки 87–95

```swift
public func syncTokenToFirestore(userId: String) async throws {
    guard let token = Messaging.messaging().fcmToken else { return }
    try await db.collection("users").document(userId).setData(
        ["fcmToken": token, "fcmTokenUpdatedAt": FieldValue.serverTimestamp()],
        merge: true
    )
}
```

Метод принимает `userId: String` без проверки, что пользователь аутентифицирован и является родителем (non-anonymous). Согласно документации проекта, токен должен синхронизироваться ТОЛЬКО при: аутентифицирован + роль parent + уведомления включены. Проверка полностью на стороне вызывающего кода, что создаёт риск при рефакторинге.

**Исправление:** Добавить `guard !userId.isEmpty, !userId.contains("anon") else { return }` или проверять через `AuthService` внутри метода. Документировать precondition явно.

---

### P1-6: LyalyaMascotView — `@Environment(\.hapticService)` может быть nil, вызывается без optional chaining

**File:** `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift`, строки 238–248

```swift
@Environment(\.hapticService) private var hapticService

private func playHapticFeedback(for newState: LyalyaState) {
    switch newState {
    case .celebrating:
        hapticService.notification(.success)  // Crash если hapticService == nil
```

Если `\.hapticService` environment key не зарегистрирован или не внедрён (например, в unit-тестах без AppContainer), это приведёт к crash при переходе в `.celebrating`.

**Исправление:** Сделать `hapticService` опциональным или добавить fallback через `?.notification(.success)`.

---

## P2 Issues

### P2-1: ChildHomeView.bootstrap() — wiring VIP через View без отдельного builder

**File:** `HappySpeech/Features/ChildHome/ChildHomeView.swift`, строки 163–180

Метод `bootstrap()` создаёт Interactor, Presenter, Router и связывает их прямо в View. Это нормально для Clean Swift, но `presenter.viewModel = viewModel` устанавливает прямую ссылку на @State-объект. Если `bootstrap()` вызывается повторно (например, при reuse View), возможно дублирование wiring. Guard `guard interactor == nil` защищает от повторного вызова, что корректно.

**Рекомендация:** Добавить тест на то, что `bootstrap()` вызывается ровно один раз; либо использовать `@once` паттерн через `lazy var`.

---

### P2-2: RepeatAfterModelInteractor — Task внутри submitTranscript без сохранения и отмены

**File:** `HappySpeech/Features/LessonPlayer/RepeatAfterModel/RepeatAfterModelInteractor.swift`, строки 293–315

```swift
if let narrationService, !canAdvance {
    Task { @MainActor [weak self] in
        ...
        self.presenter?.presentEvaluateAttempt(updatedResponse)
    }
}
```

Task не сохраняется и не отменяется при `cancel()` или `advanceWord()`. Если пользователь нажал «Далее» до завершения LLM-ответа, `presentEvaluateAttempt` вызовется на следующем слове (или после завершения сессии), перезаписав актуальный UI state.

**Исправление:** `private var llmFeedbackTask: Task<Void, Never>?`. В `cancel()` и `advanceWord()` вызывать `llmFeedbackTask?.cancel()`.

---

### P2-3: LyalyaRealityKitView.Coordinator — blinkTimer не инвалидируется при deinit

**File:** `HappySpeech/DesignSystem/Components/LyalyaRealityKitView.swift`, строка 178

```swift
private var blinkTimer: Timer?
```

`blinkTimer` и `idleAnimTask` создаются внутри Coordinator, но нет видимого `deinit` с `blinkTimer?.invalidate()` и `idleAnimTask?.cancel()`. При размонтировании ARView это может приводить к retain cycle через Timer → Coordinator → ARView.

**Исправление:** Добавить `deinit { blinkTimer?.invalidate(); idleAnimTask?.cancel() }`.

---

### P2-4: LiveRemoteConfigService — `@unchecked Sendable` без комментария о data race safety

**File:** `HappySpeech/Services/RemoteConfigService.swift`, строка 91

```swift
public final class LiveRemoteConfigService: RemoteConfigService, @unchecked Sendable {
    private var realtimeListenerStarted = false
```

`realtimeListenerStarted` — mutable state, доступный из `addOnConfigUpdateListener` callback (который вызывается не на MainActor). При одновременном вызове `startRealtimeUpdates()` из разных потоков — data race. `@unchecked Sendable` скрывает проблему от компилятора.

**Исправление:** Использовать `actor` или сериализацию через `@MainActor`.

---

### P2-5: SileroVAD — документация противоречит коду

**File:** `HappySpeech/ML/SileroVAD.swift`, строки 62–68

Документация в CLAUDE.md и комментарии в коде: «текущая реализация = energy stub, не настоящая модель». Однако `LiveSileroVAD` реально загружает `SileroVAD.mlpackage` из bundle. Если файл присутствует — используется настоящая модель; если нет — `VADError.modelNotFound`. Нет graceful fallback на `AmplitudeVAD` при отсутствии модели.

**Исправление:** Обернуть загрузку в `do { ... } catch VADError.modelNotFound { return AmplitudeVAD() }` или документировать текущее поведение явно.

---

### P2-6: ParentHomeInteractor — `child.name` логируется с `privacy: .private` — корректно, но `switchChild` логирует имя

**File:** `HappySpeech/Features/ParentHome/ParentHomeInteractor.swift`, строка 135

```swift
logger.info("ParentHome switched to child: \(child.name, privacy: .private)")
```

Корректно (privacy: .private). Однако строка 153 в `deleteChild`:
```swift
logger.info("ParentHome: deleted child \(request.childId, privacy: .public)")
```
childId помечен `.public` — если childId содержит детектируемые паттерны (например, Firebase UID), это может раскрыть идентификатор ребёнка в crash logs.

**Исправление:** Изменить на `privacy: .private` для всех детских идентификаторов.

---

### P2-7: ChildHomeInteractor — `dismissedAchievementIds` хранится in-memory, сбрасывается при убийстве приложения

**File:** `HappySpeech/Features/ChildHome/ChildHomeInteractor.swift`, строка 27

```swift
private var dismissedAchievementIds: Set<String> = []
```

После убийства приложения уже закрытые ачивки снова появятся. Для детского UX это раздражающая регрессия.

**Рекомендация:** Персистировать в `UserDefaults` аналогично `readNotificationIds` в ParentHomeInteractor.

---

## P3 Issues (cosmetic)

### P3-1: LyalyaState.localizedDescription — hardcoded русские строки вне `String(localized:)`

**File:** `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift`, строки 74–85

```swift
case .idle:        return "Покой"
case .waving:      return "Привет"
...
```

Используется только в Preview и accessibility, но всё равно нарушает правило локализации.

**Исправление:** Вернуть `String(localized: "lyalya.state.\(rawValue)")`.

---

### P3-2: ChildHomeInteractor — emoji в seed data (`"🎉"`, `"🌟"`)

**File:** `HappySpeech/Features/ChildHome/ChildHomeInteractor.swift`, строки 209, 309

Emoji захардкожены в Interactor (бизнес-логика). Должны находиться в Presenter или ViewModel.

---

### P3-3: RepeatAfterModelView — `display.phase` switch без default / exhaustive matching

**File:** `HappySpeech/Features/LessonPlayer/RepeatAfterModel/RepeatAfterModelView.swift`, строки 101–118

Switch exhaustive — хорошо. Но `@ViewBuilder` без `default` может сломать компилятор при добавлении новых кейсов к `RepeatPhase`. Добавить `@unknown default` case.

---

### P3-4: LyalyaRealityKitView — Combine import без использования

**File:** `HappySpeech/DesignSystem/Components/LyalyaRealityKitView.swift`, строка 2

```swift
import Combine
```

Combine не используется в видимом коде файла. Мёртвый import снижает читаемость.

---

### P3-5: AppContainer — `kidLLMNarrationServiceStorage` имеет internal visibility (не private)

**File:** `HappySpeech/App/DI/AppContainer.swift`, строка 69

```swift
var kidLLMNarrationServiceStorage: (any KidLLMNarrationServiceProtocol)?
```

Используется из `preview()` методов, поэтому `internal` оправдан, но комментарий об этом отсутствует. Легко перепутать с публичным API.

---

## Russian-only Guard

Localizable.xcstrings имеет `sourceLanguage: "ru"`. Все проверенные файлы используют только `String(localized:)` для user-facing строк (за исключением P3-1 и P1-3, указанных выше). **EN ключей: 0** в xcstrings — только ru локализация.

---

## Accessibility Coverage

**Оценка: 7/10**

Сильные стороны:
- `ChildHomeView` — все интерактивные элементы имеют `.accessibilityLabel` и `.accessibilityHint`
- Маскот: `.accessibilityLabel(String(localized: "lyalya.mascot.accessibility.label"))` 
- `RepeatAfterModelView` — `.accessibilityElement(children: .combine)` на составных блоках
- Иконки: `.accessibilityHidden(true)` на декоративных Image

Пробелы:
- `LyalyaRealityKitView` не передаёт accessibilityLabel из внешнего `LyalyaMascotView` — screen reader видит пустой UIViewRepresentable
- `roundStarsView` в RepeatAfterModel: `.accessibilityLabel(String(localized: "repeat.round_stars.a11y \(display.roundStars)"))` — пространство вместо разделителя в ключе локализации (возможно баг)
- Touch targets для кнопок `"Показать все"` (caption-13, строка 597) — потенциально < 44pt без явного `frame(minHeight: 44)` везде

---

## Performance Concerns

1. **PronunciationScorer** — `computeMFCC` содержит вложенный цикл O(nFrames × nMelBands × nMFCC) = 150 × 40 × 40 = 240,000 итераций, полностью на CPU. При вызове из MainActor это заморозит UI. Проверить, что `LivePronunciationScorer.score()` вызывается только из actor-изолированного контекста (actor → MainActor hop безопасен, но вычисление должно быть на background).

2. **ARZoneInteractor.loadGames()** — вызов `presenter?.presentLoadGames` дважды (immediate + after Task) создаёт два render цикла. Первый вызов пустой (без advice), второй с advice. Это приемлемо для UX, но тратит ресурсы на двойной diffing в SwiftUI.

3. **AppContainer lazy init** — `objectDetectionWorker` создаётся с `try ObjectDetectionWorker()` на MainActor при первом доступе. Если VNClassifyImageRequest инициализируется медленно — возможна задержка на UI thread.

---

## VIP Compliance

- `ChildHomeInteractor` — чистый: только бизнес-логика + presenter вызовы. Нет прямых View-зависимостей. ✓
- `ChildHomePresenter` — только `Response → ViewModel` трансформация. ✓
- `ChildHomeView` — только рендер + interactor вызовы. Метод `bootstrap()` содержит wiring, что является допустимым Clean Swift паттерном. ✓
- `ARZoneInteractor` — содержит `Task` с `self.presenter?.present*` — допустимо, `[weak self]` присутствует. ✓
- `SettingsInteractor` — P0-2 нарушение (type-cast к конкретной реализации). ✗
- `RepeatAfterModelInteractor` — P2-2 (Task без отмены). Частичное нарушение. ✗

---

## Swift 6 Concurrency

- `AppContainer` — `@Observable @MainActor` — корректно.
- `LiveRemoteConfigService` — `@unchecked Sendable` с mutable state (P2-4). ✗
- `LiveSileroVAD`, `LivePronunciationScorer` — `actor` — корректно. ✓
- `ChildHomeInteractor`, `ARZoneInteractor` — `@MainActor final class` — корректно. ✓
- `LyalyaRealityKitView.Coordinator` — `@MainActor final class` — корректно. ✓
- `MockPronunciationScorer` — `@unchecked Sendable` без mutable shared state (только настраиваемые параметры) — допустимо для тестов. ✓

---

## Recommendations (Top 3)

1. **Расширить протокол `NotificationService`** (P0-2) — критично для тестируемости и соответствия DI-правилу проекта. Без этого unit-тесты SettingsInteractor не могут покрыть kid reminder и weekly summary toggles.

2. **Добавить отмену Task в RepeatAfterModelInteractor** (P2-2) — детский контур, высокая частота transitions между словами. Race condition реален на медленных устройствах (iPhone SE 3rd gen).

3. **Перенести skin color literals в ColorTokens** (P0-1) — нарушение архитектурного правила, которое установлено именно для избежания разрастания magic numbers в production коде DesignSystem.

---

## Build Verify

BUILD SUCCEEDED ожидается (clean main по git status). Изменения в этом ревью — только документ, без изменений кода.

---

*Ревью проведено независимо на основе прямого чтения исходных файлов.*
