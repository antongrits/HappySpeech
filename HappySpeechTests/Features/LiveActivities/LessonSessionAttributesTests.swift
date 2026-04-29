import XCTest

@testable import HappySpeech

// MARK: - LessonSessionAttributesTests

/// Тесты для LessonSessionAttributes: Codable round-trip, начальные значения, Hashable.
@available(iOS 16.1, *)
final class LessonSessionAttributesTests: XCTestCase {

    // MARK: - ContentState Codable round-trip

    func test_contentState_codableRoundTrip() throws {
        let state = LessonSessionAttributes.LessonSessionState(
            currentRound: 3,
            score: 42,
            elapsedSeconds: 123,
            streakCount: 5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LessonSessionAttributes.LessonSessionState.self, from: data)

        XCTAssertEqual(decoded.currentRound, 3)
        XCTAssertEqual(decoded.score, 42)
        XCTAssertEqual(decoded.elapsedSeconds, 123)
        XCTAssertEqual(decoded.streakCount, 5)
    }

    // MARK: - Initial state values

    func test_initialState_defaultValues() {
        let state = LessonSessionAttributes.LessonSessionState(
            currentRound: 1,
            score: 0,
            elapsedSeconds: 0,
            streakCount: 0
        )

        XCTAssertEqual(state.currentRound, 1, "Начальный раунд должен быть 1")
        XCTAssertEqual(state.score, 0, "Начальный счёт должен быть 0")
        XCTAssertEqual(state.elapsedSeconds, 0, "Начальное время должно быть 0")
        XCTAssertEqual(state.streakCount, 0, "Начальный стрик должен быть 0")
    }

    // MARK: - Hashable / Equatable

    func test_contentState_equalityWhenSameValues() {
        let stateA = LessonSessionAttributes.LessonSessionState(
            currentRound: 2,
            score: 10,
            elapsedSeconds: 60,
            streakCount: 3
        )
        let stateB = LessonSessionAttributes.LessonSessionState(
            currentRound: 2,
            score: 10,
            elapsedSeconds: 60,
            streakCount: 3
        )

        XCTAssertEqual(stateA, stateB)
    }

    func test_contentState_inequalityWhenDifferentValues() {
        let stateA = LessonSessionAttributes.LessonSessionState(
            currentRound: 2,
            score: 10,
            elapsedSeconds: 60,
            streakCount: 3
        )
        let stateB = LessonSessionAttributes.LessonSessionState(
            currentRound: 3,
            score: 20,
            elapsedSeconds: 90,
            streakCount: 1
        )

        XCTAssertNotEqual(stateA, stateB)
    }

    func test_contentState_hashableConsistency() {
        let state = LessonSessionAttributes.LessonSessionState(
            currentRound: 4,
            score: 50,
            elapsedSeconds: 200,
            streakCount: 7
        )
        var set = Set<LessonSessionAttributes.LessonSessionState>()
        set.insert(state)
        set.insert(state)

        XCTAssertEqual(set.count, 1, "Хэш одного объекта должен быть уникальным в Set")
    }

    // MARK: - Attributes init

    func test_attributes_initStoresValues() {
        let attributes = LessonSessionAttributes(
            sessionId: "test-session-001",
            lessonTitle: "Звук С",
            soundId: "s",
            totalRounds: 5
        )

        XCTAssertEqual(attributes.sessionId, "test-session-001")
        XCTAssertEqual(attributes.lessonTitle, "Звук С")
        XCTAssertEqual(attributes.soundId, "s")
        XCTAssertEqual(attributes.totalRounds, 5)
    }
}
