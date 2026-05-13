import XCTest
@testable import HappySpeech

// MARK: - PronunciationLeaderboardPresenterTests
//
// Block AA v21 — Smoke tests для PronunciationLeaderboardPresenter.
// Presenter — final, spy через PronunciationLeaderboardViewModel (@Observable).
// 3 теста: presentLoad (medal symbols), presentLoad (trend labels), presentError.

@MainActor
final class PronunciationLeaderboardPresenterTests: XCTestCase {

    private var sut: PronunciationLeaderboardPresenter!
    private var viewModel: PronunciationLeaderboardViewModel!

    override func setUp() {
        super.setUp()
        viewModel = PronunciationLeaderboardViewModel()
        sut = PronunciationLeaderboardPresenter()
        sut.viewModel = viewModel
    }

    override func tearDown() {
        sut = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_presentLoad_topEntries_assignMedalSymbols() {
        // Arrange: 3 entries с разным accuracy
        let entries = [
            makeEntry(childId: "child-1", accuracy: 0.9, sessions: 5),
            makeEntry(childId: "child-2", accuracy: 0.7, sessions: 3),
            makeEntry(childId: "child-3", accuracy: 0.5, sessions: 2)
        ]
        let response = PronunciationLeaderboard.LoadResponse(
            entries: entries,
            comparison: [],
            scope: .thisWeek
        )
        // Act
        sut.presentLoad(response)
        // Assert
        XCTAssertEqual(viewModel.rows.count, 3)
        XCTAssertEqual(viewModel.rows[0].medalSymbol, "trophy.fill", "1 место — trophy")
        XCTAssertEqual(viewModel.rows[1].medalSymbol, "medal.fill", "2 место — medal")
        XCTAssertNotNil(viewModel.rows[2].medalSymbol, "3 место — rosette")
    }

    func test_presentLoad_withImprovingComparison_setsTrendLabel() {
        // Arrange
        let entry = makeEntry(childId: "child-1", accuracy: 0.85, sessions: 4)
        let comparison = PronunciationLeaderboard.WeeklyComparison(
            childId: "child-1",
            childName: "Маша",
            currentAccuracy: 0.85,
            previousAccuracy: 0.75,
            trend: .improving
        )
        let response = PronunciationLeaderboard.LoadResponse(
            entries: [entry],
            comparison: [comparison],
            scope: .thisWeek
        )
        // Act
        sut.presentLoad(response)
        // Assert
        XCTAssertTrue(
            viewModel.rows[0].trendLabel.contains("+"),
            "Improving trend должен содержать '+' знак"
        )
        XCTAssertEqual(viewModel.rows[0].trendColorToken, "success")
    }

    func test_presentError_setsStateError() {
        // Act
        sut.presentError("Ошибка загрузки")
        // Assert
        XCTAssertEqual(viewModel.state, .error("Ошибка загрузки"))
        XCTAssertEqual(viewModel.errorMessage, "Ошибка загрузки")
    }

    // MARK: - Helpers

    private func makeEntry(childId: String, accuracy: Double, sessions: Int) -> LeaderboardEntryData {
        LeaderboardEntryData(
            id: "\(childId)_2026-W19",
            childId: childId,
            parentId: "parent-1",
            weekKey: "2026-W19",
            weeklyAccuracy: accuracy,
            sessionsCount: sessions,
            totalAttempts: 100,
            correctAttempts: Int(accuracy * 100),
            updatedAt: Date()
        )
    }
}
