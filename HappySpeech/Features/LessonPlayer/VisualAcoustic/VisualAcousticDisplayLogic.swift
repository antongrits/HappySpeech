import Foundation

// MARK: - VisualAcousticDisplayLogic
//
// Контракт между `VisualAcousticPresenter` и SwiftUI-слоем
// (`VisualAcousticDisplay`). Все методы вызываются только на @MainActor.

@MainActor
protocol VisualAcousticDisplayLogic: AnyObject {
    func displayLoadRound(_ viewModel: VisualAcousticModels.LoadRound.ViewModel)
    func displayPlayAudio(_ viewModel: VisualAcousticModels.PlayAudio.ViewModel)
    func displayChoiceWord(_ viewModel: VisualAcousticModels.ChoiceWord.ViewModel)
    func displayNextRound(_ viewModel: VisualAcousticModels.NextRound.ViewModel)
    func displayComplete(_ viewModel: VisualAcousticModels.Complete.ViewModel)
}

// MARK: - VisualAcousticDisplay conformance

extension VisualAcousticDisplay: VisualAcousticDisplayLogic {

    func displayLoadRound(_ viewModel: VisualAcousticModels.LoadRound.ViewModel) {
        imageEmoji = viewModel.imageEmoji
        imageLabel = viewModel.imageLabel
        question = viewModel.question
        questionWithSound = viewModel.questionWithSound
        choices = viewModel.choices
        choiceResults = Array(repeating: .none, count: viewModel.choices.count)
        roundIndex = viewModel.roundIndex
        totalRounds = viewModel.totalRounds
        progressFraction = viewModel.progressFraction
        isPlaying = false
        feedbackCorrect = false
        feedbackText = ""
        phase = .presenting
    }

    func displayPlayAudio(_ viewModel: VisualAcousticModels.PlayAudio.ViewModel) {
        isPlaying = viewModel.isPlaying
        // Пока TTS активен — ребёнок слушает; выбор откроется в displayChoiceWord
        // после окончания речи (переход инициирует Interactor через PlayAudio(false)).
        if viewModel.isPlaying {
            phase = .presenting
        } else if phase == .presenting {
            phase = .choosing
        }
    }

    func displayChoiceWord(_ viewModel: VisualAcousticModels.ChoiceWord.ViewModel) {
        choiceResults = viewModel.choiceResults
        feedbackCorrect = viewModel.feedbackCorrect
        feedbackText = viewModel.feedbackText
        isPlaying = false
        phase = .feedback
    }

    func displayNextRound(_ viewModel: VisualAcousticModels.NextRound.ViewModel) {
        // Следующий раунд подгружается через displayLoadRound; здесь — пусто,
        // чтобы сохранить симметрию протокола VIP.
        if !viewModel.hasNextRound {
            // финал обрабатывает displayComplete
            return
        }
    }

    func displayComplete(_ viewModel: VisualAcousticModels.Complete.ViewModel) {
        scoreLabel = viewModel.scoreLabel
        starsEarned = viewModel.starsEarned
        completionMessage = viewModel.completionMessage
        lastScore = viewModel.finalScore
        progressFraction = 1.0
        isPlaying = false
        phase = .completed
    }
}
