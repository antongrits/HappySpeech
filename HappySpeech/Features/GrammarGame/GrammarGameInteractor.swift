import Foundation
import OSLog

// MARK: - GrammarGameBusinessLogic

@MainActor
protocol GrammarGameBusinessLogic: AnyObject {
    func loadGame(_ request: GrammarGameModels.LoadGame.Request) async
    func presentCurrentRound(_ request: GrammarGameModels.PresentRound.Request)
    func evaluateAnswer(_ request: GrammarGameModels.EvaluateAnswer.Request) async
    func evaluateDragDrop(_ request: GrammarGameModels.DragDrop.Request) async
    func advanceToNextRound() async
    func requestExit()
}

// MARK: - GrammarGameInteractor

/// State machine: idle → loading → presenting → awaitingAnswer →
/// evaluating → feedbackCorrect/Incorrect → hintShown → nextRound → completed
@MainActor
final class GrammarGameInteractor: GrammarGameBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any GrammarGamePresentationLogic)?

    private let contentLoader: GrammarContentLoaderWorker
    private let scoring: GrammarScoringWorker
    private let feedback: GrammarFeedbackWorker

    private let logger = Logger(subsystem: "ru.happyspeech", category: "GrammarGameInteractor")

    // MARK: - Session state

    private(set) var phase: GrammarGamePhase = .idle
    private var mode: GrammarGameMode = .oneMany
    private var difficulty: GrammarDifficulty = .medium
    private var rounds: [GrammarRound] = []
    private var currentRoundIndex: Int = 0
    private var pendingAdvance: Bool = false

    // MARK: - Init

    init(
        contentLoader: GrammarContentLoaderWorker,
        scoring: GrammarScoringWorker,
        feedback: GrammarFeedbackWorker
    ) {
        self.contentLoader = contentLoader
        self.scoring = scoring
        self.feedback = feedback
    }

    // MARK: - loadGame

    func loadGame(_ request: GrammarGameModels.LoadGame.Request) async {
        phase = .loading
        mode = request.mode
        difficulty = request.difficulty
        currentRoundIndex = 0

        logger.info("LoadGame mode=\(request.mode.rawValue) difficulty=\(request.difficulty.rawValue)")

        let loaded = await contentLoader.loadRounds(mode: request.mode, difficulty: request.difficulty)
        rounds = loaded
        let total = rounds.count
        scoring.reset(totalRounds: total)

        let response = GrammarGameModels.LoadGame.Response(
            mode: request.mode,
            difficulty: request.difficulty,
            rounds: loaded,
            totalRounds: total
        )
        presenter?.presentLoadGame(response)

        // Автоматически подать первый раунд
        if !rounds.isEmpty {
            phase = .presenting
            presentCurrentRound(.init(roundIndex: 0))
        } else {
            presenter?.presentError(String(localized: "grammar.game.error.load", bundle: .main))
        }
    }

    // MARK: - presentCurrentRound

    func presentCurrentRound(_ request: GrammarGameModels.PresentRound.Request) {
        guard request.roundIndex < rounds.count else {
            logger.warning("presentCurrentRound: index \(request.roundIndex) out of bounds")
            return
        }
        let round = rounds[request.roundIndex]
        phase = .awaitingAnswer
        feedback.speakQuestion(round.questionText)

        let response = GrammarGameModels.PresentRound.Response(
            round: round,
            roundIndex: request.roundIndex,
            totalRounds: rounds.count,
            mode: mode,
            difficulty: difficulty
        )
        presenter?.presentRound(response)
    }

    // MARK: - evaluateAnswer (multiple choice)

    func evaluateAnswer(_ request: GrammarGameModels.EvaluateAnswer.Request) async {
        guard phase == .awaitingAnswer else { return }
        guard request.roundIndex < rounds.count else { return }

        phase = .evaluating
        let round = rounds[request.roundIndex]
        let isCorrect = request.selectedChoiceId == round.choices[safe: round.correctIndex]?.id

        feedback.playSelectionHaptic()

        let result = scoring.recordAttempt(
            roundId: round.id,
            isCorrect: isCorrect,
            difficulty: difficulty
        )

        let errorsCount = result.errorsOnThisRound
        let shouldShowHint = errorsCount >= difficulty.hintAfterErrors && !isCorrect

        // Формируем feedback text
        let feedbackText: String
        if isCorrect {
            if result.shouldShowReward {
                feedbackText = String(localized: "grammar.game.reward.series", bundle: .main)
            } else {
                feedbackText = String(localized: "grammar.game.feedback.correct", bundle: .main)
            }
            feedback.playSuccessHaptic()
            feedback.playSuccessSound()
            feedback.speakCorrectFeedback("\(round.correctAnswer)!")
        } else {
            feedbackText = String(localized: "grammar.game.feedback.try_again", bundle: .main)
            feedback.playErrorHaptic()
            feedback.playErrorSound()
        }

        let hintText: String? = shouldShowHint ? round.sourceItem.hint : nil

        let response = GrammarGameModels.EvaluateAnswer.Response(
            isCorrect: isCorrect,
            correctChoiceId: round.choices[safe: round.correctIndex]?.id ?? "",
            selectedChoiceId: request.selectedChoiceId,
            errorsOnThisRound: errorsCount,
            feedbackText: feedbackText,
            hintText: hintText,
            shouldShowHint: shouldShowHint,
            score: result.scorePoints
        )
        presenter?.presentEvaluateAnswer(response)

        // State transition
        if isCorrect {
            phase = .feedbackCorrect(roundIndex: request.roundIndex)
            pendingAdvance = result.shouldShowReward ? false : true
        } else {
            phase = .feedbackIncorrect(
                roundIndex: request.roundIndex,
                errorsCount: errorsCount
            )
            if shouldShowHint {
                phase = .hintShown(roundIndex: request.roundIndex)
                feedback.speakHint(hintText ?? "")
            } else {
                // Вернуть к ожиданию (можно попробовать ещё)
                phase = .awaitingAnswer
            }
        }

        logger.debug("EvaluateAnswer correct=\(isCorrect) errors=\(errorsCount) hint=\(shouldShowHint)")
    }

    // MARK: - evaluateDragDrop (Dative игра)

    func evaluateDragDrop(_ request: GrammarGameModels.DragDrop.Request) async {
        guard phase == .awaitingAnswer else { return }
        guard request.roundIndex < rounds.count else { return }

        phase = .evaluating
        let round = rounds[request.roundIndex]

        guard case .dative(let characters, let targetIndex) = round.extraData else {
            phase = .awaitingAnswer
            return
        }

        let correctChar = characters[safe: targetIndex]
        let isCorrect = request.droppedOnCharacterId == correctChar?.id

        let result = scoring.recordAttempt(
            roundId: round.id,
            isCorrect: isCorrect,
            difficulty: difficulty
        )

        if isCorrect {
            let correctPhrase = correctChar.map { "\($0.dativeName) нужен \(round.correctAnswer)!" }
                ?? String(localized: "grammar.game.feedback.correct", bundle: .main)
            feedback.playSuccessHaptic()
            feedback.playSuccessSound()
            feedback.speakCorrectFeedback(correctPhrase)
        } else {
            feedback.playErrorHaptic()
            feedback.playErrorSound()
        }

        let response = GrammarGameModels.DragDrop.Response(
            isCorrect: isCorrect,
            correctCharacterId: correctChar?.id ?? "",
            droppedCharacterId: request.droppedOnCharacterId,
            charDativeName: correctChar?.dativeName ?? "",
            correctAnswer: round.correctAnswer
        )
        presenter?.presentDragDrop(response)

        if isCorrect {
            phase = .feedbackCorrect(roundIndex: request.roundIndex)
        } else {
            phase = .awaitingAnswer
        }

        logger.debug("DragDrop correct=\(isCorrect) reward=\(result.shouldShowReward)")
    }

    // MARK: - advanceToNextRound

    func advanceToNextRound() async {
        let next = currentRoundIndex + 1
        if next >= rounds.count {
            // Сессия завершена
            phase = .completed
            let response = GrammarGameModels.SessionComplete.Response(
                mode: mode,
                difficulty: difficulty,
                totalRounds: rounds.count,
                correctCount: scoring.correctCount,
                successRate: scoring.sessionSuccessRate(),
                sessionDurationSeconds: scoring.sessionDurationSeconds()
            )
            presenter?.presentSessionComplete(response)
            logger.info(
                "Session complete mode=\(self.mode.rawValue) rate=\(self.scoring.sessionSuccessRate())"
            )
        } else {
            currentRoundIndex = next
            phase = .presenting
            presentCurrentRound(.init(roundIndex: next))
        }
    }

    // MARK: - requestExit

    func requestExit() {
        presenter?.presentExitConfirmation()
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
