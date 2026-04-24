import Foundation

// MARK: - StoryCompletionDisplayLogic
//
// Контракт между `StoryCompletionPresenter` и SwiftUI-слоем
// (`StoryCompletionDisplay`). Все методы вызываются только на @MainActor.

@MainActor
protocol StoryCompletionDisplayLogic: AnyObject {
    func displayLoadStory(_ viewModel: StoryCompletionModels.LoadStory.ViewModel)
    func displayChooseWord(_ viewModel: StoryCompletionModels.ChooseWord.ViewModel)
    func displayNextScene(_ viewModel: StoryCompletionModels.NextScene.ViewModel)
    func displayComplete(_ viewModel: StoryCompletionModels.Complete.ViewModel)
}

// MARK: - StoryCompletionDisplay conformance

extension StoryCompletionDisplay: StoryCompletionDisplayLogic {

    func displayLoadStory(_ viewModel: StoryCompletionModels.LoadStory.ViewModel) {
        storyText = viewModel.storyText
        displayText = viewModel.displayText
        choices = viewModel.choices
        choiceStates = Array(repeating: .idle, count: viewModel.choices.count)
        emoji = viewModel.emoji
        sceneIndex = viewModel.sceneIndex
        totalScenes = viewModel.totalScenes
        progressFraction = viewModel.progressFraction
        isReading = viewModel.isReading
        feedbackCorrect = false
        feedbackMessage = ""
        phase = .reading
    }

    func displayChooseWord(_ viewModel: StoryCompletionModels.ChooseWord.ViewModel) {
        choiceStates = viewModel.choiceStates
        displayText = viewModel.filledStoryText
        feedbackCorrect = viewModel.feedbackCorrect
        feedbackMessage = viewModel.feedbackMessage
        isReading = false
        phase = .feedback
    }

    func displayNextScene(_ viewModel: StoryCompletionModels.NextScene.ViewModel) {
        // Сцены переключаются через последующий `displayLoadStory`;
        // здесь только обновляем progressFraction-намёк, если сцена последняя.
        if !viewModel.hasNextScene {
            // finalise handled by displayComplete
            return
        }
    }

    func displayComplete(_ viewModel: StoryCompletionModels.Complete.ViewModel) {
        scoreLabel = viewModel.scoreLabel
        starsEarned = viewModel.starsEarned
        completionMessage = viewModel.completionMessage
        lastScore = viewModel.finalScore
        progressFraction = 1.0
        isReading = false
        phase = .completed
    }
}
