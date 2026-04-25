import Foundation
import OSLog
import RealmSwift

// MARK: - ScreeningBusinessLogic

@MainActor
protocol ScreeningBusinessLogic: AnyObject {
    func startScreening(_ request: ScreeningModels.StartScreening.Request) async
    func submitAnswer(_ request: ScreeningModels.SubmitAnswer.Request) async
    func finishScreening(_ request: ScreeningModels.FinishScreening.Request) async
    func completeScreening(_ request: ScreeningModels.CompleteRequest) async
}

// MARK: - ScreeningInteractor

/// Orchestrates the initial diagnostic flow. Holds in-memory state for a single
/// screening pass: the ordered prompt list, the collected per-prompt scores,
/// and the current index. On finish, delegates to `ScreeningScoringEngine` for
/// pure aggregation and emits a presenter-bound outcome.
///
/// `completeScreening(_:)` — финальный шаг: persist `ScreeningOutcomeObject`
/// в Realm и навигация в ParentHome через `router.routeToParentHome()`.
@MainActor
final class ScreeningInteractor: ScreeningBusinessLogic {

    var presenter: (any ScreeningPresentationLogic)?
    var router: ScreeningRouter?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Screening")
    private let realmActor: RealmActor?

    private var prompts: [ScreeningPrompt] = []
    private var scores: [String: Float] = [:]
    private var childAge: Int = 6
    private var childId: String = ""

    // MARK: - Init

    init(realmActor: RealmActor? = nil) {
        self.realmActor = realmActor
    }

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

    /// Финальный шаг: сохраняет `ScreeningOutcomeObject` в Realm и переходит
    /// на ParentHome. Если RealmActor не предоставлен (preview / тесты) —
    /// pers'ит шаг пропускается, навигация всё равно вызывается.
    func completeScreening(_ request: ScreeningModels.CompleteRequest) async {
        let soundsList = request.problematicSounds.joined(separator: ",")
        let cid = request.childId
        let sev = request.severity
        logger.info(
            "screening complete childId=\(cid, privacy: .private) severity=\(sev, privacy: .public) sounds=\(soundsList, privacy: .public)"
        )

        do {
            try await persist(request)
        } catch {
            logger.error("screening persist failed: \(error.localizedDescription, privacy: .public)")
        }

        router?.routeToParentHome()
    }

    // MARK: - Private — Realm persist

    private func persist(_ request: ScreeningModels.CompleteRequest) async throws {
        guard let realmActor else {
            logger.notice("screening persist skipped — realmActor not provided")
            return
        }
        try await Self.persistOutcome(request, realmActor: realmActor)
    }

    /// Nonisolated, чтобы closure для `writeVoid` не пересекал MainActor isolation.
    /// Принимает только Sendable значения (`CompleteRequest`, `RealmActor`).
    nonisolated private static func persistOutcome(
        _ request: ScreeningModels.CompleteRequest,
        realmActor: RealmActor
    ) async throws {
        try await realmActor.writeVoid { realm in
            let outcome = ScreeningOutcomeObject()
            outcome.childId = request.childId
            outcome.completedAt = Date()
            outcome.overallSeverity = request.severity
            outcome.problematicSounds.removeAll()
            outcome.problematicSounds.append(objectsIn: request.problematicSounds)
            outcome.recommendedPacks.removeAll()
            outcome.recommendedPacks.append(objectsIn: request.recommendedPacks)
            outcome.notes = request.notes
            outcome.screeningVersion = 1
            realm.add(outcome, update: .modified)
        }
    }

    // MARK: - Testing helpers

    /// Exposed for unit tests to assert internal state without re-running the
    /// whole flow via presenter callbacks.
    func _testState() -> (prompts: [ScreeningPrompt], scores: [String: Float]) {
        (prompts, scores)
    }
}
