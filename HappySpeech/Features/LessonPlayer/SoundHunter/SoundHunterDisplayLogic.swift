import Foundation

// MARK: - SoundHunterDisplayLogic
//
// Контракт между `SoundHunterPresenter` и SwiftUI-представлением.
// `SoundHunterDisplay` реализует этот протокол и служит наблюдаемым хранилищем
// состояния UI.

@MainActor
protocol SoundHunterDisplayLogic: AnyObject {
    func displayLoadScene(_ viewModel: SoundHunterModels.LoadScene.ViewModel)
    func displayTapItem(_ viewModel: SoundHunterModels.TapItem.ViewModel)
    func displayCompleteScene(_ viewModel: SoundHunterModels.CompleteScene.ViewModel)
    func displayNextScene(_ viewModel: SoundHunterModels.NextScene.ViewModel)
}

// MARK: - SoundHunterDisplay + SoundHunterDisplayLogic

extension SoundHunterDisplay: SoundHunterDisplayLogic {

    func displayLoadScene(_ viewModel: SoundHunterModels.LoadScene.ViewModel) {
        self.items = viewModel.items
        self.targetSound = viewModel.targetSound
        self.targetSoundGroup = viewModel.targetSoundGroup
        self.sceneIndex = viewModel.sceneIndex
        self.totalScenes = viewModel.totalScenes
        self.totalCorrectNeeded = viewModel.totalCorrectNeeded
        self.correctCount = 0
        self.progressFraction = viewModel.progressFraction
        self.hintText = viewModel.hintText
        self.shakeItemId = nil
        self.phase = .hunting
    }

    func displayTapItem(_ viewModel: SoundHunterModels.TapItem.ViewModel) {
        if let index = items.firstIndex(where: { $0.id == viewModel.itemId }) {
            items[index].tapState = viewModel.newState
        }
        self.correctCount = viewModel.correctCount
        self.totalCorrectNeeded = viewModel.totalCorrectNeeded
        self.progressFraction = viewModel.progressFraction
        self.shakeItemId = viewModel.shakeItemId
        if viewModel.isSceneComplete {
            self.phase = .sceneComplete
        }
    }

    func displayCompleteScene(_ viewModel: SoundHunterModels.CompleteScene.ViewModel) {
        self.lastScore = viewModel.totalScore
        self.starsEarned = viewModel.starsEarned
        self.scoreLabel = viewModel.scoreLabel
        self.completionMessage = viewModel.completionMessage
        self.phase = .completed
    }

    func displayNextScene(_ viewModel: SoundHunterModels.NextScene.ViewModel) {
        self.items = viewModel.items
        self.targetSound = viewModel.targetSound
        self.sceneIndex = viewModel.nextSceneIndex
        self.totalCorrectNeeded = viewModel.totalCorrectNeeded
        self.correctCount = 0
        self.progressFraction = viewModel.progressFraction
        self.hintText = viewModel.hintText
        self.shakeItemId = nil
        self.phase = .hunting
    }
}
