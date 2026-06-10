@testable import HappySpeech
import XCTest

// MARK: - SessionShellFSRSFeedTests
//
// F1-016 — единый планировщик интервальных повторов (FSRS-лестница 1→3→7→14→30).
// Проверяет, что центральный хук `SessionShellInteractor.completeActivity` кормит
// `AdaptivePlannerService.recordItemOutcome` РЕАЛЬНЫМ исходом попытки для ЛЮБОГО
// шаблона, без дублирования в каждом per-template Interactor'е.
//
// Покрытие:
//   - верный ответ (score ≥ 0.5) → recordItemOutcome(correct: true)
//   - ошибка (score < 0.5)       → recordItemOutcome(correct: false)
//   - itemId == lessonId шага, sound == soundTarget шага (реальные данные)
//   - каждый завершённый шаг даёт ровно один вызов планировщика
//   - вызов происходит для разных шаблонов (minimal-pairs, articulation, …)
// ==================================================================================

@MainActor
final class SessionShellFSRSFeedTests: XCTestCase {

    @MainActor
    private final class StubPresenter: SessionShellPresentationLogic {
        var startResponses: [SessionShellModels.StartSession.Response] = []
        func presentStartSession(_ response: SessionShellModels.StartSession.Response) async {
            startResponses.append(response)
        }
        func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async {}
        func presentPauseSession(_ response: SessionShellModels.PauseSession.Response) {}
    }

    private func makeSUT(
        planner: MockAdaptivePlannerService
    ) -> (SessionShellInteractor, StubPresenter) {
        let interactor = SessionShellInteractor(
            contentService: MockContentService(),
            adaptivePlannerService: planner,
            sessionRepository: MockSessionRepository(),
            hapticService: MockHapticService()
        )
        let presenter = StubPresenter()
        interactor.presenter = presenter
        return (interactor, presenter)
    }

    // MARK: - correct outcome

    func test_correctAnswer_feedsScheduler_withCorrectTrue() async {
        let planner = MockAdaptivePlannerService()
        let (sut, spy) = makeSUT(planner: planner)
        await sut.startSession(.init(
            childId: "c-1", targetSoundId: "Ш",
            sessionType: .adaptive, forcedGameType: .minimalPairs
        ))
        let activity = spy.startResponses.first!.activities.first!

        await sut.completeActivity(.init(
            activityId: activity.id, score: 0.9,
            durationSeconds: 30, errorCount: 0
        ))

        XCTAssertEqual(planner.recordedItemOutcomes.count, 1)
        let recorded = planner.recordedItemOutcomes.first
        XCTAssertEqual(recorded?.childId, "c-1")
        XCTAssertEqual(recorded?.itemId, activity.lessonId)
        XCTAssertEqual(recorded?.sound, activity.soundTarget)
        XCTAssertEqual(recorded?.correct, true)
    }

    // MARK: - incorrect outcome

    func test_wrongAnswer_feedsScheduler_withCorrectFalse() async {
        let planner = MockAdaptivePlannerService()
        let (sut, spy) = makeSUT(planner: planner)
        await sut.startSession(.init(
            childId: "c-2", targetSoundId: "Р",
            sessionType: .adaptive, forcedGameType: .articulationImitation
        ))
        let activity = spy.startResponses.first!.activities.first!

        await sut.completeActivity(.init(
            activityId: activity.id, score: 0.2,
            durationSeconds: 10, errorCount: 2
        ))

        XCTAssertEqual(planner.recordedItemOutcomes.count, 1)
        XCTAssertEqual(planner.recordedItemOutcomes.first?.correct, false)
        XCTAssertEqual(planner.recordedItemOutcomes.first?.itemId, activity.lessonId)
        XCTAssertEqual(planner.recordedItemOutcomes.first?.sound, activity.soundTarget)
    }

    // MARK: - boundary at the pass threshold (score == 0.5 → correct)

    func test_borderlineScore_isTreatedAsCorrect() async {
        let planner = MockAdaptivePlannerService()
        let (sut, spy) = makeSUT(planner: planner)
        await sut.startSession(.init(
            childId: "c-3", targetSoundId: "С",
            sessionType: .adaptive, forcedGameType: .listenAndChoose
        ))
        let activity = spy.startResponses.first!.activities.first!

        await sut.completeActivity(.init(
            activityId: activity.id, score: 0.5,
            durationSeconds: 12, errorCount: 0
        ))

        XCTAssertEqual(planner.recordedItemOutcomes.first?.correct, true)
    }

    // MARK: - one feed per completed step

    func test_eachCompletedStep_feedsSchedulerOnce_acrossTemplates() async {
        let planner = MockAdaptivePlannerService()
        let (sut, spy) = makeSUT(planner: planner)
        // Дефолтная сессия проходит несколько РАЗНЫХ шаблонов
        // (listenAndChoose / repeatAfterModel / minimalPairs / sorting / memory).
        await sut.startSession(.init(
            childId: "c-4", targetSoundId: "Ж", sessionType: .quickPractice
        ))
        let activities = spy.startResponses.first!.activities
        XCTAssertGreaterThan(activities.count, 1)

        var completedSteps = 0
        for _ in activities {
            await sut.completeActivity(.init(
                activityId: "any", score: 0.8,
                durationSeconds: 20, errorCount: 0
            ))
            completedSteps += 1
            // Усталость может завершить сессию раньше; учитываем только пройденные шаги.
            if planner.recordedItemOutcomes.count < completedSteps { break }
        }

        // Один вызов планировщика на каждый завершённый шаг (нет дублей/пропусков).
        XCTAssertEqual(planner.recordedItemOutcomes.count, completedSteps)
        XCTAssertTrue(planner.recordedItemOutcomes.allSatisfy { $0.correct })
        // Реальные данные шага, не пустышки.
        XCTAssertTrue(planner.recordedItemOutcomes.allSatisfy { !$0.itemId.isEmpty && !$0.sound.isEmpty })
    }

    // MARK: - skip is a real (failed) attempt and still feeds the scheduler

    func test_skip_feedsScheduler_withCorrectFalse() async {
        let planner = MockAdaptivePlannerService()
        let (sut, _) = makeSUT(planner: planner)
        await sut.startSession(.init(
            childId: "c-5", targetSoundId: "Л",
            sessionType: .adaptive, forcedGameType: .soundHunter
        ))

        await sut.skipCurrentActivity()

        XCTAssertEqual(planner.recordedItemOutcomes.count, 1)
        XCTAssertEqual(planner.recordedItemOutcomes.first?.correct, false)
    }
}
