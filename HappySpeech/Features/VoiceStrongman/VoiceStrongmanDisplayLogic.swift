import Foundation

// MARK: - VoiceStrongmanDisplayLogic
//
// Контракт между `VoiceStrongmanPresenter` и SwiftUI-слоем
// (`VoiceStrongmanDisplay`). Все методы — только на @MainActor.

@MainActor
protocol VoiceStrongmanDisplayLogic: AnyObject {
    func displayStart(_ viewModel: VoiceStrongmanStartViewModel)
    func displayRecording(_ isRecording: Bool)
    func displayPlaying(_ isPlaying: Bool)
    func displayLiveSample(_ viewModel: VoiceStrongmanModels.LiveSample.ViewModel)
    func displayScore(_ viewModel: VoiceStrongmanModels.Score.ViewModel)
    func displayComplete(_ viewModel: VoiceStrongmanModels.Complete.ViewModel)
    /// Микрофон не разрешён: показать понятное сообщение, снять состояние записи.
    func displayMicrophoneDenied(message: String)
}

// MARK: - VoiceStrongmanStartViewModel
//
// Старт текущего задания: режим, заголовок/подсказка, начальные данные подвью.

struct VoiceStrongmanStartViewModel: Sendable, Equatable {
    let mode: VoiceStrongmanMode
    let phase: VoiceStrongmanPhase
    let title: String
    let subtitle: String
    let mascotText: String
    let taskIndex: Int
    let totalTasks: Int
    let vowel: String
    let prompt: String
    // Громкость
    let loudnessLevel: LoudnessLevel
    let animal: String
    let bandLower: CGFloat
    let bandUpper: CGFloat
    // Высота
    let pitchDirection: PitchDirection
    let ladderSteps: Int
}

// MARK: - VoiceStrongmanDisplay conformance
//
// Маппинг ViewModel → @Observable display state. View подписан на display.

extension VoiceStrongmanDisplay: VoiceStrongmanDisplayLogic {

    func displayStart(_ vm: VoiceStrongmanStartViewModel) {
        mode = vm.mode
        phase = vm.phase
        title = vm.title
        subtitle = vm.subtitle
        mascotText = vm.mascotText
        mascotState = .explaining
        taskIndex = vm.taskIndex
        totalTasks = vm.totalTasks
        vowel = vm.vowel

        loudnessLevel = vm.loudnessLevel
        animal = vm.animal
        bandLower = vm.bandLower
        bandUpper = vm.bandUpper
        liveLoudness = 0
        loudnessInBand = false

        pitchDirection = vm.pitchDirection
        ladderSteps = vm.ladderSteps
        livePitch = 0
        ladderReached = 0
        liveContour = []
        directionMatched = false

        showResult = false
        resultMatch = false
        resultMessage = ""
        isRecording = false
        isPlaying = false
        micDenied = false
        micDeniedMessage = ""
    }

    func displayRecording(_ recording: Bool) {
        isRecording = recording
        if recording {
            showResult = false
            liveLoudness = 0
            livePitch = 0
            liveContour = []
            loudnessInBand = false
            micDenied = false
            micDeniedMessage = ""
        }
    }

    func displayMicrophoneDenied(message: String) {
        isRecording = false
        showResult = false
        micDenied = true
        micDeniedMessage = message
        mascotState = .encouraging
    }

    func displayPlaying(_ playing: Bool) {
        isPlaying = playing
    }

    func displayLiveSample(_ vm: VoiceStrongmanModels.LiveSample.ViewModel) {
        guard isRecording else { return }
        liveLoudness = vm.loudnessNormalised
        livePitch = vm.pitchNormalised
        loudnessInBand = vm.inTarget
        liveContour = vm.liveContour
    }

    func displayScore(_ vm: VoiceStrongmanModels.Score.ViewModel) {
        resultMatch = vm.isMatch
        resultMessage = vm.feedbackMessage
        subtitle = vm.title
        showResult = true
        isRecording = false

        switch vm.mode {
        case .loudness:
            liveLoudness = vm.loudnessNormalised
            loudnessInBand = vm.loudnessInBand
            mascotState = vm.isMatch ? .celebrating : .encouraging
        case .pitch:
            ladderReached = vm.ladderReached
            livePitch = vm.ladderReached
            liveContour = vm.liveContour
            directionMatched = vm.directionMatched
            mascotState = vm.isMatch ? .celebrating : .encouraging
        }
    }

    func displayComplete(_ vm: VoiceStrongmanModels.Complete.ViewModel) {
        phase = .completed
        starsEarned = vm.starsEarned
        completionMessage = vm.completionMessage
        matchRate = vm.matchRate
        mascotState = .celebrating
        isRecording = false
        isPlaying = false
    }
}
