import Foundation
import OSLog

// MARK: - ScreeningBusinessLogic

@MainActor
protocol ScreeningBusinessLogic: AnyObject {
    func startScreening(_ request: ScreeningModels.StartScreening.Request) async
    func submitAnswer(_ request: ScreeningModels.SubmitAnswer.Request) async
    func finishScreening(_ request: ScreeningModels.FinishScreening.Request) async
}

// MARK: - ScreeningInteractor

/// Orchestrates the initial diagnostic flow. Holds in-memory state for a single
/// screening pass: the ordered prompt list, the collected per-prompt scores,
/// and the current index. On finish, delegates to `ScreeningScoringEngine` for
/// pure aggregation and emits a presenter-bound outcome.
@MainActor
final class ScreeningInteractor: ScreeningBusinessLogic {

    var presenter: (any ScreeningPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Screening")

    private var prompts: [ScreeningPrompt] = []
    private var scores: [String: Float] = [:]
    private var childAge: Int = 6
    private var childId: String = ""

    // MARK: - ScreeningBusinessLogic

    func startScreening(_ request: ScreeningModels.StartScreening.Request) async {
        childId = request.childId
        childAge = request.childAge
        prompts = ScreeningPromptFactory.prompts(for: childAge)
        scores.removeAll()

        logger.info("screening start childId=\(request.childId, privacy: .private) prompts=\(self.prompts.count, privacy: .public)")

        let response = ScreeningModels.StartScreening.Response(
            prompts: prompts,
            totalBlocks: ScreeningBlock.allCases.count
        )
        await presenter?.presentStartScreening(response)
    }

    func submitAnswer(_ request: ScreeningModels.SubmitAnswer.Request) async {
        scores[request.promptId] = request.score
        let currentIdx = prompts.firstIndex(where: { $0.id == request.promptId }) ?? -1
        let isLast = currentIdx >= prompts.count - 1
        let nextIdx = currentIdx + 1
        let blockTransition = !isLast
            && currentIdx >= 0
            && prompts[currentIdx].block != prompts[nextIdx].block

        let response = ScreeningModels.SubmitAnswer.Response(
            isBlockComplete: blockTransition,
            isScreeningComplete: isLast,
            currentPromptIndex: currentIdx
        )
        await presenter?.presentSubmitAnswer(response)
    }

    func finishScreening(_ request: ScreeningModels.FinishScreening.Request) async {
        let outcome = ScreeningScoringEngine.evaluate(
            childId: request.childId.isEmpty ? childId : request.childId,
            childAge: childAge,
            scores: scores,
            prompts: prompts
        )
        logger.info("screening finish priorities=\(outcome.priorityTargetSounds.joined(separator: ","), privacy: .public)")

        let response = ScreeningModels.FinishScreening.Response(outcome: outcome)
        await presenter?.presentFinishScreening(response)
    }

    // MARK: - Testing helpers

    /// Exposed for unit tests to assert internal state without re-running the
    /// whole flow via presenter callbacks.
    func _testState() -> (prompts: [ScreeningPrompt], scores: [String: Float]) {
        (prompts, scores)
    }
}
