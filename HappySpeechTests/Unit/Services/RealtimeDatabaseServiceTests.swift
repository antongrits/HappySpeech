@testable import HappySpeech
import XCTest

// MARK: - RealtimeDatabaseServiceTests
//
// Phase 6 plan v29 — покрытие RealtimeDatabaseService (ранее без выделенных тестов).
//
// LiveRealtimeDatabaseService использует Firebase Realtime Database (europe-west1) —
// требует FirebaseApp.configure() и сети. Unit-тесты покрывают контракт протокола
// через MockRealtimeDatabaseService (in-memory store): создание сессии, live-обновления
// для observer'ов, инкремент version, завершение сессии и error-пути.

final class RealtimeDatabaseServiceTests: XCTestCase {

    private func makeSUT() -> MockRealtimeDatabaseService {
        MockRealtimeDatabaseService()
    }

    // MARK: - createSession

    func test_createSession_returnsInitialStateWithVersionOne() async throws {
        let sut = makeSUT()
        let state = try await sut.createSession(sessionId: "s-1", hostUid: "host-1")
        XCTAssertEqual(state.sessionId, "s-1")
        XCTAssertEqual(state.hostUid, "host-1")
        XCTAssertEqual(state.currentStep, 0)
        XCTAssertNil(state.currentExerciseId)
        XCTAssertEqual(state.version, 1, "Новая сессия должна иметь version=1")
    }

    func test_createSession_throwsWhenErrorInjected() async {
        let sut = makeSUT()
        sut.shouldThrowError = .writeFailed("инъекция")
        do {
            _ = try await sut.createSession(sessionId: "s-1", hostUid: "host-1")
            XCTFail("Ожидалась ошибка")
        } catch is RealtimeDatabaseError {
            // ok
        } catch {
            XCTFail("Ожидался RealtimeDatabaseError")
        }
    }

    // MARK: - observeSession

    func test_observeSession_deliversCurrentSnapshotImmediately() async throws {
        let sut = makeSUT()
        _ = try await sut.createSession(sessionId: "s-2", hostUid: "host-2")

        let received = SendableBox<SharePlaySessionState?>(nil)
        _ = try await sut.observeSession(sessionId: "s-2") { state in
            received.value = state
        }
        XCTAssertEqual(received.value?.sessionId, "s-2",
                       "Observer должен сразу получить текущее состояние сессии")
    }

    func test_observeSession_receivesUpdatesOnSessionChange() async throws {
        let sut = makeSUT()
        _ = try await sut.createSession(sessionId: "s-3", hostUid: "host-3")

        let lastStep = SendableBox<Int>(-1)
        _ = try await sut.observeSession(sessionId: "s-3") { state in
            lastStep.value = state.currentStep
        }
        try await sut.updateSession(sessionId: "s-3", currentStep: 4, currentExerciseId: "ex-9")
        XCTAssertEqual(lastStep.value, 4, "Observer должен получить обновлённый currentStep")
    }

    // MARK: - updateSession

    func test_updateSession_incrementsVersion() async throws {
        let sut = makeSUT()
        let initial = try await sut.createSession(sessionId: "s-4", hostUid: "host-4")
        XCTAssertEqual(initial.version, 1)

        let captured = SendableBox<SharePlaySessionState?>(nil)
        _ = try await sut.observeSession(sessionId: "s-4") { captured.value = $0 }
        try await sut.updateSession(sessionId: "s-4", currentStep: 2, currentExerciseId: nil)
        XCTAssertEqual(captured.value?.version, 2, "updateSession должен инкрементировать version")
        XCTAssertEqual(captured.value?.currentStep, 2)
    }

    func test_updateSession_throwsSessionNotFoundForUnknownSession() async {
        let sut = makeSUT()
        do {
            try await sut.updateSession(sessionId: "missing", currentStep: 1, currentExerciseId: nil)
            XCTFail("Ожидалась ошибка sessionNotFound")
        } catch let error as RealtimeDatabaseError {
            guard case .sessionNotFound = error else {
                return XCTFail("Ожидалась .sessionNotFound, получено \(error)")
            }
        } catch {
            XCTFail("Ожидался RealtimeDatabaseError")
        }
    }

    // MARK: - endSession

    func test_endSession_removesSession() async throws {
        let sut = makeSUT()
        _ = try await sut.createSession(sessionId: "s-5", hostUid: "host-5")
        try await sut.endSession(sessionId: "s-5")
        // После удаления updateSession должен бросить sessionNotFound.
        do {
            try await sut.updateSession(sessionId: "s-5", currentStep: 1, currentExerciseId: nil)
            XCTFail("Сессия должна быть удалена")
        } catch let error as RealtimeDatabaseError {
            guard case .sessionNotFound = error else {
                return XCTFail("Ожидалась .sessionNotFound")
            }
        } catch {
            XCTFail("Ожидался RealtimeDatabaseError")
        }
    }

    // MARK: - SharePlaySessionState value type

    func test_sessionState_equatable() {
        let date = Date()
        let a = SharePlaySessionState(
            sessionId: "x", hostUid: "h", currentStep: 1,
            currentExerciseId: "e", version: 2, updatedAt: date
        )
        let b = SharePlaySessionState(
            sessionId: "x", hostUid: "h", currentStep: 1,
            currentExerciseId: "e", version: 2, updatedAt: date
        )
        XCTAssertEqual(a, b)
    }

    // MARK: - RealtimeDatabaseError descriptions

    func test_realtimeDatabaseError_hasRussianDescriptions() {
        XCTAssertEqual(
            RealtimeDatabaseError.sessionNotFound.errorDescription,
            "Сессия не найдена."
        )
        XCTAssertEqual(
            RealtimeDatabaseError.writeFailed("деталь").errorDescription,
            "Не удалось обновить данные сессии: деталь"
        )
    }
}

// MARK: - Test helper

/// Минимальный sendable-контейнер для захвата значений из @Sendable-замыканий
/// observer'а в синхронных тестах (mock доставляет колбэки синхронно).
private final class SendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
