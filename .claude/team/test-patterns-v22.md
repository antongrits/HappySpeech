# Test Patterns v22 — Plan v22 Phase 0 Block 0.4

## Обзор

Block 0.4 добавляет `TestDataBuilder` и spy-реализации сервисов в `HappySpeechTests/Support/`.
Эти файлы используются в Block 4.1–4.5 для закрытия 14 `XCTSkip`.

Ключевое решение: вместо параллельных DTO-обёрток (`ChildProfileDTO` внутри теста)
используются **реальные domain-типы** (`ChildProfileDTO`, `SessionDTO`, `AuthUser`, `UnlockedAchievementData`).
Spy-классы дополняют, а не дублируют `MockAuthService` из production `MockServices.swift`.

---

## TestDataBuilder — примеры использования

### ChildProfile

```swift
let child = TestDataBuilder.childProfile(age: 7, targetSounds: ["Ш", "Ж"])
let anotherChild = TestDataBuilder.childProfile(
    id: "specific-id",
    name: "Коля",
    progressSummary: ["Р": 0.65]
)
```

### Session

```swift
let session = TestDataBuilder.session(childId: child.id, correctAttempts: 10, totalAttempts: 10)
let failedSession = TestDataBuilder.session(correctAttempts: 2, totalAttempts: 10)
XCTAssertEqual(failedSession.successRate, 0.2, accuracy: 0.001)
```

### Attempt

```swift
let correctAttempt = TestDataBuilder.attempt(word: "рыба", isCorrect: true, asrScore: 0.95)
let wrongAttempt = TestDataBuilder.attempt(word: "лыба", asrTranscript: "лыба", isCorrect: false)
```

### AuthUser

```swift
let verifiedUser = TestDataBuilder.authUser(isEmailVerified: true)
let anonUser = TestDataBuilder.authUser(uid: "anon-1", email: nil, isAnonymous: true)
```

### UnlockedAchievement

```swift
let achievement = TestDataBuilder.unlockedAchievement(
    achievementKey: Achievement.streak7Days.rawValue
)
```

### WAV data (ML-тесты)

```swift
// Реальный файл из test-bundle:
let audioData = TestDataBuilder.loadTestWAV("test_sound_r.wav")

// Fallback — 1 секунда тишины, если файл не найден:
let silence = TestDataBuilder.loadTestWAV("nonexistent.wav") // returns 32000 bytes
```

---

## MockServices — паттерны

### Auth тесты (Block 4.1)

```swift
func testSignIn_success() async throws {
    let spy = SpyAuthService()
    spy.stubbedUser = TestDataBuilder.authUser(email: "user@test.com")
    let interactor = AuthInteractor(authService: spy, ...)

    await interactor.signIn(request: .init(email: "user@test.com", password: "pass"))

    XCTAssertEqual(spy.signInCallCount, 1)
    XCTAssertEqual(spy.lastSignInEmail, "user@test.com")
}

func testSignIn_failure() async throws {
    let spy = SpyAuthService()
    spy.shouldFail = true

    // expect presenter to receive error response
    await interactor.signIn(request: .init(email: "x@x.com", password: "wrong"))
    XCTAssertTrue(mockPresenter.presentErrorCalled)
}
```

### Repository тесты (Block 4.2)

```swift
func testFetchChildren_returnsAll() async throws {
    let spy = SpyChildRepository(children: [
        TestDataBuilder.childProfile(name: "Маша"),
        TestDataBuilder.childProfile(name: "Вася")
    ])
    let result = try await spy.fetchAll()
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(spy.fetchAllCallCount, 1)
}

func testSaveChild_updatesStorage() async throws {
    let spy = SpyChildRepository(children: [])
    let child = TestDataBuilder.childProfile(name: "Петя")
    try await spy.save(child)
    XCTAssertEqual(spy.saveCallCount, 1)
    XCTAssertEqual(spy.lastSaved?.name, "Петя")
}
```

### Session тесты (Block 4.3)

```swift
func testFetchRecent_limitsResults() async throws {
    let sessions = (0..<10).map { i in
        TestDataBuilder.session(id: "s-\(i)", childId: "child-1")
    }
    let spy = SpySessionRepository(sessions: sessions)
    let recent = try await spy.fetchRecent(childId: "child-1", limit: 3)
    XCTAssertEqual(recent.count, 3)
}
```

### Sync тесты (Block 4.4)

```swift
func testDrainQueue_clearsCount() async {
    let spy = SpySyncService()
    await spy.enqueue(operation: .upsertSession(id: "s-1"))
    let before = await spy.pendingCount()
    try await spy.drainQueue()
    let after = await spy.pendingCount()
    XCTAssertEqual(before, 1)
    XCTAssertEqual(after, 0)
    XCTAssertEqual(await spy.drainCallCount, 1)
}
```

### AdaptivePlanner тесты (Block 4.5)

```swift
func testBuildRoute_returnsStubbedRoute() async throws {
    let route = AdaptiveRoute(steps: [
        RouteStepItem(templateType: .memory, targetSound: "Ш", stage: .syllable,
                      difficulty: 1, wordCount: 6, durationTargetSec: 120)
    ], maxDurationSec: 600, fatigueLevel: .tired)
    let spy = SpyAdaptivePlannerService(route: route, fatigue: .tired)

    let result = try await spy.buildDailyRoute(for: "child-1")

    XCTAssertEqual(result.steps.count, 1)
    XCTAssertEqual(result.steps[0].templateType, .memory)
    XCTAssertEqual(spy.buildRouteCallCount, 1)
}
```

---

## Соглашения по именованию spy-объектов

| Тип | Класс | Где |
|-----|-------|-----|
| Шпион (подсчёт вызовов + stubbing) | `Spy<Name>` | `HappySpeechTests/Support/MockServices.swift` |
| Простой мок без счётчиков | `Mock<Name>` | Production `MockServices.swift` |
| Test fixtures | `TestDataBuilder.<method>()` | `HappySpeechTests/Support/TestDataBuilder.swift` |

## Важно: конфликт имён с production MockServices

В `HappySpeech/Services/MockServices.swift` уже есть:
- `MockAuthService`, `MockNetworkMonitor`, `MockSyncService`, `MockAdaptivePlannerService`

В тестовом таргете эти классы доступны через `@testable import HappySpeech`.
Тестовый `MockServices.swift` содержит **только** `Spy`-классы с дополнительными spy-counters.
Не создавать новый `MockAuthService` в тестовом файле — использовать `SpyAuthService` или
существующий `MockAuthService` из production-кода в зависимости от нужд теста.
