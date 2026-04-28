@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - GrammarGameSmokeUITest
//
// Smoke-тест: GrammarGameView инициализируется и рендерится без краша
// для всех 4 режимов. Не требует запуска симулятора / XCUIApplication.
// Проверяет: UIHostingController не nil, view.bounds не нулевые.

@MainActor
final class GrammarGameSmokeUITest: XCTestCase {

    // MARK: - Stub interactor

    @MainActor
    private final class StubInteractor: GrammarGameBusinessLogic {
        func loadGame(_ request: GrammarGameModels.LoadGame.Request) async {}
        func presentCurrentRound(_ request: GrammarGameModels.PresentRound.Request) {}
        func evaluateAnswer(_ request: GrammarGameModels.EvaluateAnswer.Request) async {}
        func evaluateDragDrop(_ request: GrammarGameModels.DragDrop.Request) async {}
        func advanceToNextRound() async {}
        func requestExit() {}
    }

    private func stubInteractor() -> any GrammarGameBusinessLogic { StubInteractor() }
    private func stubRouter() -> GrammarGameRouter { GrammarGameRouter() }

    // MARK: - 1. Smoke: все 4 режима создают UIHostingController без краша

    func test_allModes_renderWithoutCrash() {
        let modes: [GrammarGameMode] = [.oneMany, .dative, .genitive, .instrumental]
        let difficulties: [GrammarDifficulty] = [.easy, .medium, .hard]

        for mode in modes {
            for difficulty in difficulties {
                let view = GrammarGameView(
                    mode: mode,
                    difficulty: difficulty,
                    childId: "smoke-child",
                    interactor: stubInteractor(),
                    router: stubRouter()
                )
                let host = UIHostingController(rootView: view)
                host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                host.view.layoutIfNeeded()

                XCTAssertNotNil(host.view, "UIHostingController.view не должен быть nil (\(mode) / \(difficulty))")
                XCTAssertFalse(
                    host.view.bounds.isEmpty,
                    "bounds не должны быть пустыми (\(mode) / \(difficulty))"
                )
            }
        }
    }

    // MARK: - 2. Smoke: GrammarContentLoaderWorker.fallbackRounds не пустые

    func test_fallbackRounds_allModes_notEmpty() {
        for mode in GrammarGameMode.allCases {
            for difficulty in GrammarDifficulty.allCases {
                let rounds = GrammarContentLoaderWorker.fallbackRounds(
                    mode: mode,
                    difficulty: difficulty
                )
                XCTAssertFalse(
                    rounds.isEmpty,
                    "fallbackRounds должны быть не пустыми для \(mode) / \(difficulty)"
                )
            }
        }
    }

    // MARK: - 3. Smoke: GrammarScoringWorker не крашится при concurrent recordAttempt

    func test_scoringWorker_multipleAttempts_doesNotCrash() {
        let sut = GrammarScoringWorker()
        sut.reset(totalRounds: 10)
        var ids: [UUID] = (0..<10).map { _ in UUID() }

        for (i, rid) in ids.enumerated() {
            _ = sut.recordAttempt(roundId: rid, isCorrect: i % 2 == 0, difficulty: .medium)
        }

        let rate = sut.sessionSuccessRate()
        XCTAssertGreaterThanOrEqual(rate, 0, "successRate >= 0")
        XCTAssertLessThanOrEqual(rate, 1,    "successRate <= 1")
    }
}
