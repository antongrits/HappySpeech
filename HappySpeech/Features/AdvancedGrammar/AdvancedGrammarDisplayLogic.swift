import Foundation

// MARK: - AdvancedGrammarDisplayLogic
//
// Контракт между `AdvancedGrammarPresenter` и SwiftUI-слоем
// (`AdvancedGrammarDisplay`). Все методы — только на @MainActor.

@MainActor
protocol AdvancedGrammarDisplayLogic: AnyObject {
    func displayStart(_ viewModel: AdvancedGrammarModels.Start.Response)
    func displayRound(_ viewModel: AdvancedGrammarModels.PresentRound.Response)
    func displayPlaying(_ isPlaying: Bool)
    func displayEvaluate(_ viewModel: AdvancedGrammarModels.Evaluate.Response)
    func displayComplete(_ viewModel: AdvancedGrammarModels.Complete.Response)
}

// MARK: - AdvancedGrammarDisplay (Observable state)

/// Наблюдаемое состояние экрана. View читает свойства напрямую.
@Observable
@MainActor
final class AdvancedGrammarDisplay {

    // MARK: Phase

    var phase: AdvancedGrammarPhase = .loading
    var mode: AdvancedGrammarMode = .complexPreposition

    // MARK: Progress

    var roundIndex: Int = 0
    var totalRounds: Int = 0

    // MARK: Current round

    var title: String = ""
    var subtitle: String = ""
    var promptTemplate: String = ""
    var imageName: String = "questionmark.circle"
    var scene: PrepositionScene?
    var gender: GrammaticalGender?
    var choices: [AdvancedGrammarChoice] = []
    var correctChoiceId: String = ""
    var fullPhrase: String = ""
    var hint: String = ""

    // MARK: Answer state

    var selectedChoiceId: String?
    var isAnswered: Bool = false
    var isCorrect: Bool = false
    var correctionText: String = ""
    var mascotText: String = ""

    // MARK: Playback

    var isPlaying: Bool = false

    // MARK: Completion

    var correctFirstTry: Int = 0
    var finalSuccessRate: Float = 0
    var starsEarned: Int = 0
    var completionTitle: String = ""
    var completionMessage: String = ""

    // MARK: Exit

    var pendingExit: Bool = false
}

// MARK: - AdvancedGrammarDisplayLogic conformance

extension AdvancedGrammarDisplay: AdvancedGrammarDisplayLogic {

    func displayStart(_ viewModel: AdvancedGrammarModels.Start.Response) {
        mode = viewModel.mode
        totalRounds = viewModel.totalRounds
        roundIndex = 0
        if let first = viewModel.firstRound {
            apply(round: first, index: 0)
            phase = .question
        }
    }

    func displayRound(_ viewModel: AdvancedGrammarModels.PresentRound.Response) {
        totalRounds = viewModel.totalRounds
        apply(round: viewModel.round, index: viewModel.roundIndex)
        phase = .question
    }

    func displayPlaying(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
    }

    func displayEvaluate(_ viewModel: AdvancedGrammarModels.Evaluate.Response) {
        selectedChoiceId = viewModel.selectedChoiceId
        correctChoiceId = viewModel.correctChoiceId
        isCorrect = viewModel.isCorrect
        isAnswered = viewModel.isCorrect
        fullPhrase = viewModel.fullPhrase
        correctionText = viewModel.correctionText
        mascotText = viewModel.isCorrect ? viewModel.fullPhrase : viewModel.correctionText
    }

    func displayComplete(_ viewModel: AdvancedGrammarModels.Complete.Response) {
        correctFirstTry = viewModel.correctFirstTry
        finalSuccessRate = viewModel.successRate
        let pct = Int((viewModel.successRate * 100).rounded())
        starsEarned = pct >= 80 ? 3 : (pct >= 50 ? 2 : 1)
        completionTitle = String(
            format: String(localized: "advancedGrammar.complete.title %lld %lld",
                           defaultValue: "Готово! %lld из %lld"),
            viewModel.correctFirstTry, viewModel.totalRounds
        )
        completionMessage = pct >= 80
            ? String(localized: "advancedGrammar.complete.great",
                     defaultValue: "Ты здорово строишь сложные фразы. Молодец!")
            : (pct >= 50
               ? String(localized: "advancedGrammar.complete.good",
                        defaultValue: "Хорошая работа! С каждым разом всё лучше.")
               : String(localized: "advancedGrammar.complete.keep",
                        defaultValue: "Мы потренировались вместе. Скоро получится ещё лучше!"))
        isPlaying = false
        phase = .completed
    }

    // MARK: - Helpers

    private func apply(round: AdvancedGrammarRound, index: Int) {
        roundIndex = index
        title = round.title
        subtitle = round.subtitle
        promptTemplate = round.promptTemplate
        imageName = round.imageName
        scene = round.scene
        gender = round.gender
        choices = round.choices
        correctChoiceId = round.correctChoiceId
        fullPhrase = round.fullPhrase
        hint = round.hint
        // reset answer
        selectedChoiceId = nil
        isAnswered = false
        isCorrect = false
        correctionText = ""
        mascotText = round.hint
        isPlaying = false
    }
}
