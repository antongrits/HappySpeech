import Foundation

// MARK: - GrammarGamePresentationLogic

@MainActor
protocol GrammarGamePresentationLogic: AnyObject {
    func presentLoadGame(_ response: GrammarGameModels.LoadGame.Response)
    func presentRound(_ response: GrammarGameModels.PresentRound.Response)
    func presentEvaluateAnswer(_ response: GrammarGameModels.EvaluateAnswer.Response)
    func presentDragDrop(_ response: GrammarGameModels.DragDrop.Response)
    func presentSessionComplete(_ response: GrammarGameModels.SessionComplete.Response)
    func presentExitConfirmation()
    func presentError(_ message: String)
}

// MARK: - GrammarGamePresenter

/// Преобразует Response → ViewModel. Вся строковая/визуальная логика здесь.
@MainActor
final class GrammarGamePresenter: GrammarGamePresentationLogic {

    weak var display: (any GrammarGameDisplayLogic)?

    // MARK: - presentLoadGame

    func presentLoadGame(_ response: GrammarGameModels.LoadGame.Response) {
        let vm = GrammarGameModels.LoadGame.ViewModel(
            modeTitle: response.mode.localizedTitle,
            difficultyLabel: response.difficulty.localizedLabel,
            totalRounds: response.totalRounds
        )
        display?.displayLoadGame(vm)
    }

    // MARK: - presentRound

    func presentRound(_ response: GrammarGameModels.PresentRound.Response) {
        let vm = GrammarGameModels.PresentRound.ViewModel(
            questionText: response.round.questionText,
            choices: response.round.choices,
            imageName: response.round.imageName,
            roundIndex: response.roundIndex,
            totalRounds: response.totalRounds,
            extraData: response.round.extraData,
            audioFile: response.round.sourceItem.audioFile
        )
        display?.displayRound(vm)
    }

    // MARK: - presentEvaluateAnswer

    func presentEvaluateAnswer(_ response: GrammarGameModels.EvaluateAnswer.Response) {
        let vm = GrammarGameModels.EvaluateAnswer.ViewModel(
            isCorrect: response.isCorrect,
            correctChoiceId: response.correctChoiceId,
            selectedChoiceId: response.selectedChoiceId,
            feedbackText: response.feedbackText,
            hintText: response.hintText,
            showHint: response.shouldShowHint
        )
        display?.displayEvaluateAnswer(vm)
    }

    // MARK: - presentDragDrop

    func presentDragDrop(_ response: GrammarGameModels.DragDrop.Response) {
        let feedbackPhrase: String
        if response.isCorrect && !response.charDativeName.isEmpty {
            feedbackPhrase = String(
                format: String(localized: "grammar.game.feedback.dative_correct", bundle: .main),
                response.charDativeName,
                response.correctAnswer
            )
        } else if response.isCorrect {
            feedbackPhrase = String(localized: "grammar.game.feedback.correct", bundle: .main)
        } else {
            feedbackPhrase = String(localized: "grammar.game.feedback.try_again", bundle: .main)
        }
        let vm = GrammarGameModels.DragDrop.ViewModel(
            isCorrect: response.isCorrect,
            correctCharacterId: response.correctCharacterId,
            droppedCharacterId: response.droppedCharacterId,
            feedbackPhrase: feedbackPhrase
        )
        display?.displayDragDrop(vm)
    }

    // MARK: - presentSessionComplete

    func presentSessionComplete(_ response: GrammarGameModels.SessionComplete.Response) {
        let pct = Int(response.successRate * 100)
        let resultText: String
        switch pct {
        case 80...100:
            resultText = String(localized: "grammar.game.reward.level_complete", bundle: .main)
        case 50..<80:
            resultText = String(localized: "grammar.game.reward.series", bundle: .main)
        default:
            resultText = String(localized: "grammar.game.feedback.try_again", bundle: .main)
        }
        let vm = GrammarGameModels.SessionComplete.ViewModel(
            resultText: resultText,
            successRate: response.successRate,
            correctCount: response.correctCount,
            totalRounds: response.totalRounds,
            showReward: pct >= 60
        )
        display?.displaySessionComplete(vm)
    }

    // MARK: - presentExitConfirmation

    func presentExitConfirmation() {
        let vm = GrammarGameModels.ExitConfirmation.ViewModel(
            title: String(localized: "grammar.game.exit.title",   bundle: .main),
            body:  String(localized: "grammar.game.exit.body",    bundle: .main),
            confirmLabel: String(localized: "grammar.game.exit.confirm", bundle: .main),
            cancelLabel:  String(localized: "grammar.game.exit.cancel",  bundle: .main)
        )
        display?.displayExitConfirmation(vm)
    }

    // MARK: - presentError

    func presentError(_ message: String) {
        display?.displayError(message)
    }
}
