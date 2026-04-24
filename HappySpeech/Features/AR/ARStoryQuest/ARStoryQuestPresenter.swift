import Foundation

// MARK: - ARStoryQuestPresenter
//
// Формирует `ARStoryQuestDisplay` из `ARStoryQuestResponse` и публикует его
// во View через closure `onUpdate`. Presenter не знает про Realm, ASR или
// сервисы — только про форматирование текста для детского UI.

@MainActor
final class ARStoryQuestPresenter {

    /// Текущий state, доступный для инкрементальных апдейтов.
    /// Presenter держит собственную копию, чтобы не требовать от View слать её обратно.
    private var display = ARStoryQuestDisplay()

    /// Подписка View: каждый новый снэпшот `ARStoryQuestDisplay` доставляется сюда.
    var onUpdate: ((ARStoryQuestDisplay) -> Void)?

    // MARK: - Entry point

    func present(_ response: ARStoryQuestResponse) {
        switch response {
        case let .questLoaded(script, step):
            presentQuestLoaded(script: script, step: step)

        case .listeningStarted:
            presentListeningStarted()

        case .listeningStopped:
            presentListeningStopped()

        case let .attemptEvaluated(score, passed, feedback, emoji):
            presentAttempt(score: score, passed: passed, feedback: feedback, emoji: emoji)

        case let .stepAdvanced(step, isLast):
            presentStepAdvanced(step: step, isLast: isLast)

        case let .questCompleted(totalScore, stars):
            presentCompleted(totalScore: totalScore, stars: stars)

        case let .error(message):
            presentError(message: message)
        }

        onUpdate?(display)
    }

    // MARK: - Per-case formatting

    private func presentQuestLoaded(script: QuestScript, step: QuestStep) {
        display = ARStoryQuestDisplay(
            questTitle: script.title,
            narration: step.narration,
            targetWord: step.targetWord,
            hint: step.hint,
            stepNumber: step.stepNumber,
            totalSteps: script.steps.count,
            progressFraction: Double(step.stepNumber) / Double(script.steps.count),
            rewardEmoji: step.rewardEmoji,
            isListening: false,
            lastScore: 0,
            feedbackText: "",
            isCompleted: false,
            starsEarned: 0,
            totalScore: 0,
            showFeedback: false,
            canAdvance: false,
            isLoading: false,
            errorMessage: nil
        )
    }

    private func presentListeningStarted() {
        display.isListening = true
        display.showFeedback = false
        display.canAdvance = false
    }

    private func presentListeningStopped() {
        display.isListening = false
    }

    private func presentAttempt(score: Float, passed: Bool, feedback: String, emoji: String) {
        display.isListening = false
        display.lastScore = score
        display.feedbackText = feedback
        display.showFeedback = true
        display.canAdvance = passed
        if passed {
            display.rewardEmoji = emoji
        }
    }

    private func presentStepAdvanced(step: QuestStep, isLast: Bool) {
        display.narration = step.narration
        display.targetWord = step.targetWord
        display.hint = step.hint
        display.stepNumber = step.stepNumber
        display.rewardEmoji = step.rewardEmoji
        display.progressFraction = Double(step.stepNumber) / Double(display.totalSteps)
        display.showFeedback = false
        display.canAdvance = false
        display.lastScore = 0
        display.feedbackText = ""
        display.isListening = false
        if isLast {
            display.hint = String(localized: "ar.quest.final.hint")
        }
    }

    private func presentCompleted(totalScore: Float, stars: Int) {
        display.isCompleted = true
        display.totalScore = totalScore
        display.starsEarned = stars
        display.isListening = false
        display.canAdvance = false
        display.showFeedback = false
        display.feedbackText = String(localized: "ar.quest.completed.title")
    }

    private func presentError(message: String) {
        display.errorMessage = message
        display.isLoading = false
        display.isListening = false
    }
}
