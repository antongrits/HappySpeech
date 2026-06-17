import Foundation

// MARK: - LiveSoundsDisplayLogic
//
// Контракт между `LiveSoundsPresenter` и SwiftUI-слоем (`LiveSoundsDisplay`).
// Все методы — только на @MainActor.

@MainActor
protocol LiveSoundsDisplayLogic: AnyObject {
    func displayStart(_ viewModel: LiveSoundsModels.Start.ViewModel)
    func displayLoadRound(_ response: LiveSoundsModels.LoadRound.Response)
    func displayPlaying(_ isPlaying: Bool)
    func displayNowSound(_ index: Int?)
    func displayPace(_ pace: LiveSoundsPace)
    func displayChoosePicture(_ viewModel: LiveSoundsModels.ChoosePicture.ViewModel)
    func displayPlaceCharacter(_ viewModel: LiveSoundsModels.PlaceCharacter.ViewModel)
    func displayComplete(_ viewModel: LiveSoundsModels.Complete.ViewModel)
}

// MARK: - LiveSoundsDisplay conformance

extension LiveSoundsDisplay: LiveSoundsDisplayLogic {

    func displayStart(_ viewModel: LiveSoundsModels.Start.ViewModel) {
        totalRounds = viewModel.totalRounds
        if let first = viewModel.firstRound {
            applyRound(first)
        }
        roundIndex = 0
    }

    func displayLoadRound(_ response: LiveSoundsModels.LoadRound.Response) {
        let round = response.round
        word = round.word.uppercased()
        imageAsset = round.imageAsset
        sounds = round.sounds
        options = round.options
        benchLetters = round.benchLetters
        mode = round.mode
        roundIndex = response.roundIndex
        totalRounds = response.totalRounds
        resetRoundState()
    }

    func displayPlaying(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
        if !isPlaying { nowSoundIndex = nil }
    }

    func displayNowSound(_ index: Int?) {
        nowSoundIndex = index
    }

    func displayPace(_ pace: LiveSoundsPace) {
        self.pace = pace
    }

    func displayChoosePicture(_ viewModel: LiveSoundsModels.ChoosePicture.ViewModel) {
        selectedOptionIndex = viewModel.selectedIndex
        correctOptionIndex = viewModel.correctIndex
        feedbackCorrect = viewModel.isCorrect
        feedbackText = viewModel.feedbackText
        showFeedback = !viewModel.feedbackText.isEmpty
        solved = viewModel.solved
    }

    func displayPlaceCharacter(_ viewModel: LiveSoundsModels.PlaceCharacter.ViewModel) {
        placedLetters = viewModel.placedLetters
        usedBenchIndices = viewModel.usedBenchIndices
        activeSlotIndex = viewModel.activeSlotIndex
        feedbackCorrect = viewModel.feedbackCorrect
        feedbackText = viewModel.feedbackText
        showFeedback = !viewModel.feedbackText.isEmpty
        rowComplete = viewModel.rowComplete
        if viewModel.rowComplete { solved = true }
    }

    func displayComplete(_ viewModel: LiveSoundsModels.Complete.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.completionMessage
        lastScore = viewModel.finalScore
        isPlaying = false
        nowSoundIndex = nil
        phase = .completed
    }

    // MARK: - Helpers

    private func applyRound(_ vm: LiveSoundsModels.RoundViewModel) {
        word = vm.word
        imageAsset = vm.imageAsset
        sounds = vm.sounds
        options = vm.options
        benchLetters = vm.benchLetters
        mode = vm.mode
        resetRoundState()
    }

    private func resetRoundState() {
        nowSoundIndex = nil
        isPlaying = false
        selectedOptionIndex = nil
        correctOptionIndex = nil
        solved = false
        placedLetters = []
        usedBenchIndices = []
        activeSlotIndex = mode == .bench ? 0 : nil
        rowComplete = false
        feedbackCorrect = false
        feedbackText = ""
        showFeedback = false
        phase = mode == .bench ? .bench : .collect
    }
}
