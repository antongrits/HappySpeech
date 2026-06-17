import Foundation

// MARK: - TongueTwistersDisplayLogic
//
// Контракт между `TongueTwistersPresenter` и SwiftUI-слоем
// (`TongueTwistersDisplay`). Все методы — только на @MainActor.

@MainActor
protocol TongueTwistersDisplayLogic: AnyObject {
    func displayStart(_ viewModel: TongueTwistersModels.Start.ViewModel)
    func displayLoadPhrase(_ response: TongueTwistersModels.LoadPhrase.Response)
    func displayPlaying(_ isPlaying: Bool)
    func displayRecording(_ isRecording: Bool)
    func displayBeat(_ beat: Int)
    func displayMetronome(on: Bool, bpm: Int)
    func displayChooseRhyme(_ viewModel: TongueTwistersModels.ChooseRhyme.ViewModel)
    func displayCheckRecording(_ viewModel: TongueTwistersModels.CheckRecording.ViewModel)
    func displayEnterSay()
    func displayEnterTrain(states: [WagonState], currentIndex: Int?)
    func displaySpeakWagon(_ viewModel: TongueTwistersModels.SpeakWagon.ViewModel)
    func displayComplete(_ viewModel: TongueTwistersModels.Complete.ViewModel)
}

// MARK: - TongueTwistersDisplay conformance

extension TongueTwistersDisplay: TongueTwistersDisplayLogic {

    func displayStart(_ viewModel: TongueTwistersModels.Start.ViewModel) {
        totalPhrases = viewModel.totalPhrases
        phraseIndex = 0
        phase = .rhyme
    }

    func displayLoadPhrase(_ response: TongueTwistersModels.LoadPhrase.Response) {
        let p = response.phrase
        targetSound = p.targetSound
        warmupSyllable = p.warmupSyllable
        warmupBeats = p.warmupBeats
        linePrefix = p.linePrefix
        lineSuffix = p.lineSuffix
        answerWord = p.answerWord
        answers = p.answers
        wagons = p.wagons
        wagonStates = Array(repeating: .locked, count: p.wagons.count)
        currentWagonIndex = nil
        phraseIndex = response.phraseIndex
        totalPhrases = response.totalPhrases

        selectedAnswerId = nil
        filledWord = nil
        rhymeCorrect = false
        statusText = ""
        showStatus = false
        soundHeard = false
        feedbackText = ""
        isRecording = false
        isPlaying = false
        activeBeat = 0
        phase = .rhyme
    }

    func displayPlaying(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
    }

    func displayRecording(_ isRecording: Bool) {
        self.isRecording = isRecording
    }

    func displayBeat(_ beat: Int) {
        activeBeat = beat
    }

    func displayMetronome(on: Bool, bpm: Int) {
        metronomeOn = on
        metronomeBPM = bpm
    }

    func displayChooseRhyme(_ viewModel: TongueTwistersModels.ChooseRhyme.ViewModel) {
        selectedAnswerId = viewModel.selectedAnswerId
        rhymeCorrect = viewModel.isCorrect
        feedbackText = viewModel.feedbackText
        if let filled = viewModel.filledWord {
            filledWord = filled
        }
    }

    func displayCheckRecording(_ viewModel: TongueTwistersModels.CheckRecording.ViewModel) {
        statusText = viewModel.statusText
        soundHeard = viewModel.soundHeard
        showStatus = viewModel.showStatus
    }

    func displayEnterSay() {
        phase = .say
        statusText = ""
        showStatus = false
        feedbackText = ""
    }

    func displayEnterTrain(states: [WagonState], currentIndex: Int?) {
        wagonStates = states
        currentWagonIndex = currentIndex
        phase = .train
    }

    func displaySpeakWagon(_ viewModel: TongueTwistersModels.SpeakWagon.ViewModel) {
        wagonStates = viewModel.wagonStates
        currentWagonIndex = viewModel.currentIndex
    }

    func displayComplete(_ viewModel: TongueTwistersModels.Complete.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.completionMessage
        lastScore = viewModel.finalScore
        isPlaying = false
        isRecording = false
        phase = .completed
    }
}
