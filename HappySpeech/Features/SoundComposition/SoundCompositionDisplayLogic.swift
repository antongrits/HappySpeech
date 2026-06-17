import Foundation

// MARK: - SoundCompositionDisplayLogic
//
// Контракт между `SoundCompositionPresenter` и SwiftUI-слоем
// (`SoundCompositionDisplay`). Все методы — только на @MainActor.

@MainActor
protocol SoundCompositionDisplayLogic: AnyObject {
    func displayStart(_ viewModel: SoundCompositionModels.Start.ViewModel)
    func displayLoadWord(_ response: SoundCompositionModels.LoadWord.Response)
    func displayPlaying(_ isPlaying: Bool)
    func displayPlaceChip(_ viewModel: SoundCompositionModels.PlaceChip.ViewModel)
    func displaySynthesis(_ viewModel: SoundCompositionModels.Synthesis.ViewModel)
    func displayBonus(_ viewModel: SoundCompositionModels.Bonus.ViewModel)
    func displayComplete(_ viewModel: SoundCompositionModels.Complete.ViewModel)
}

// MARK: - SoundCompositionDisplay conformance

extension SoundCompositionDisplay: SoundCompositionDisplayLogic {

    func displayStart(_ viewModel: SoundCompositionModels.Start.ViewModel) {
        totalWords = viewModel.totalWords
        if let first = viewModel.firstWord {
            wordText = first.text
            imageAsset = first.imageAsset
            soundCount = first.soundCount
            stretchedHint = first.stretchedHint
        }
        wordIndex = 0
        step = 1
        phase = .scheme
    }

    func displayLoadWord(_ response: SoundCompositionModels.LoadWord.Response) {
        let word = response.word
        wordText = word.text.uppercased()
        imageAsset = word.imageAsset
        soundCount = word.soundCount
        stretchedHint = Self.stretchedHint(for: word)
        wordIndex = response.wordIndex
        totalWords = response.totalWords
        placedChips = []
        activeSoundIndex = 0
        activeSoundLetter = word.sounds.first?.letter ?? ""
        activeSoundType = word.sounds.first?.type ?? .vowel
        feedbackCorrect = false
        feedbackText = ""
        showFeedback = false
        bonus = nil
        bonusSelectedIndex = nil
        bonusFeedback = ""
        synthesisTitle = ""
        synthesisSummary = ""
        step = 1
        isPlaying = false
        phase = .scheme
    }

    func displayPlaying(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
    }

    func displayPlaceChip(_ viewModel: SoundCompositionModels.PlaceChip.ViewModel) {
        placedChips = viewModel.placedChips
        activeSoundIndex = viewModel.activeSoundIndex
        activeSoundLetter = viewModel.activeSoundLetter
        activeSoundType = viewModel.activeSoundType
        feedbackCorrect = viewModel.feedbackCorrect
        feedbackText = viewModel.feedbackText
        showFeedback = !viewModel.feedbackText.isEmpty
        step = 2
        if phase != .placing { phase = .placing }
    }

    func displaySynthesis(_ viewModel: SoundCompositionModels.Synthesis.ViewModel) {
        synthesisTitle = viewModel.title
        synthesisSummary = viewModel.summaryLine
        placedChips = viewModel.chips
        imageAsset = viewModel.imageAsset
        bonus = viewModel.bonus
        bonusSelectedIndex = nil
        bonusFeedback = ""
        showFeedback = false
        step = 3
        phase = .synthesis
    }

    func displayBonus(_ viewModel: SoundCompositionModels.Bonus.ViewModel) {
        bonusSelectedIndex = viewModel.selectedIndex
        bonusFeedback = viewModel.feedbackText
    }

    func displayComplete(_ viewModel: SoundCompositionModels.Complete.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.completionMessage
        lastScore = viewModel.finalScore
        isPlaying = false
        phase = .completed
    }

    // MARK: - Helpers

    /// Протяжная подсказка из звуков слова: «м-м-и-и-ш-ш-…».
    nonisolated static func stretchedHint(for word: SoundCompositionWord) -> String {
        word.sounds
            .map { $0.letter.lowercased() + "-" + $0.letter.lowercased() }
            .joined(separator: "-")
    }
}
