import XCTest
@testable import HappySpeech

// MARK: - PronunciationLeaderboardWorkerTests
//
// Block AA v21 — Smoke tests для доменного слоя PronunciationLeaderboard.
// Тестируем Scope.localizedTitle, Trend enum, LeaderboardRow construction.

final class PronunciationLeaderboardWorkerTests: XCTestCase {

    // MARK: - Tests

    func test_scope_allCases_haveUniqueRawValues() {
        let rawValues = PronunciationLeaderboard.Scope.allCases.map { $0.rawValue }
        let unique = Set(rawValues)
        XCTAssertEqual(rawValues.count, unique.count, "Все Scope.rawValue должны быть уникальны")
    }

    func test_trend_improving_notEqualDecline() {
        XCTAssertNotEqual(PronunciationLeaderboard.Trend.improving, .declining)
        XCTAssertEqual(PronunciationLeaderboard.Trend.stable, .stable)
    }

    func test_leaderboardRow_isYouFlag_setCorrectly() {
        let row = PronunciationLeaderboard.LeaderboardRow(
            id: "child-abc",
            position: 1,
            childName: "Маша",
            accuracyText: "90%",
            accuracy: 0.9,
            sessionsCountText: "5 занятий",
            trendLabel: "+10%",
            trendIcon: "arrow.up.right.circle.fill",
            trendColorToken: "success",
            medalSymbol: "trophy.fill",
            isYou: true
        )
        XCTAssertTrue(row.isYou)
        XCTAssertEqual(row.position, 1)
        XCTAssertEqual(row.medalSymbol, "trophy.fill")
    }

    func test_screenState_equatable() {
        XCTAssertEqual(PronunciationLeaderboard.ScreenState.loading, .loading)
        XCTAssertEqual(PronunciationLeaderboard.ScreenState.empty, .empty)
        XCTAssertEqual(PronunciationLeaderboard.ScreenState.error("msg"), .error("msg"))
        XCTAssertNotEqual(PronunciationLeaderboard.ScreenState.ready, .empty)
    }
}
