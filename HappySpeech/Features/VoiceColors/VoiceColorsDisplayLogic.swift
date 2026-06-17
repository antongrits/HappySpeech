import Foundation

// MARK: - VoiceColorsDisplayLogic
//
// Контракт между `VoiceColorsPresenter` и SwiftUI-слоем (`VoiceColorsDisplay`).
// Все методы — только на @MainActor.

@MainActor
protocol VoiceColorsDisplayLogic: AnyObject {
    func displayStart(_ viewModel: VoiceColorsStartViewModel)
    func displaySelectIntonation(_ viewModel: VoiceColorsModels.SelectIntonation.Response)
    func displaySelectStressWord(_ viewModel: VoiceColorsModels.SelectStressWord.Response)
    func displaySelectEmotion(_ viewModel: VoiceColorsModels.SelectEmotion.Response)
    func displayRecording(_ isRecording: Bool)
    func displayPlaying(_ isPlaying: Bool)
    func displayLiveSample(_ viewModel: VoiceColorsModels.LiveSample.ViewModel)
    func displayScore(_ viewModel: VoiceColorsModels.Score.ViewModel)
    func displayComplete(_ viewModel: VoiceColorsModels.Complete.ViewModel)
    /// Микрофон не разрешён: показать понятное сообщение, снять состояние записи.
    func displayMicrophoneDenied(message: String)
}

// MARK: - VoiceColorsStartViewModel
//
// Старт текущего задания: режим, заголовок/подсказка, начальные данные подвью.

struct VoiceColorsStartViewModel: Sendable, Equatable {
    let mode: VoiceColorsMode
    let phase: VoiceColorsPhase
    let title: String
    let subtitle: String
    let mascotText: String
    let taskIndex: Int
    let totalTasks: Int
    // Интонация
    let phraseText: String
    let firstIntonationMode: IntonationMode
    let firstMark: String
    let firstContour: [PitchPoint]
    /// Уже успешно пройденные «домики» текущего задания (зелёные галочки).
    let doneIntonationModes: Set<IntonationMode>
    // Ударение
    let stressWords: [String]
    let stressEmojis: [String]
    let targetWordIndex: Int
    let stressQuestion: String
    let stressQuestionEmoji: String
    // Эмоция
    let emotionPhrase: String
    let firstEmotion: VoiceEmotion
}

// MARK: - VoiceColorsDisplay conformance
//
// Маппинг ViewModel → @Observable display state. View подписан на display.

extension VoiceColorsDisplay: VoiceColorsDisplayLogic {

    func displayStart(_ vm: VoiceColorsStartViewModel) {
        mode = vm.mode
        phase = vm.phase
        title = vm.title
        subtitle = vm.subtitle
        mascotText = vm.mascotText
        mascotState = .explaining
        taskIndex = vm.taskIndex
        totalTasks = vm.totalTasks

        phraseText = vm.phraseText
        intonationMode = vm.firstIntonationMode
        intonationMark = vm.firstMark
        modelContour = vm.firstContour
        liveContour = []
        doneIntonationModes = vm.doneIntonationModes

        stressWords = vm.stressWords
        stressEmojis = vm.stressEmojis
        targetWordIndex = vm.targetWordIndex
        chosenWordIndex = vm.targetWordIndex
        stressQuestion = vm.stressQuestion
        stressQuestionEmoji = vm.stressQuestionEmoji
        perWordHeights = []
        loudestWordIndex = -1

        emotionPhrase = vm.emotionPhrase
        chosenEmotion = vm.firstEmotion
        reflectedEmotion = nil

        showResult = false
        resultMatch = false
        resultMessage = ""
        isRecording = false
        isPlaying = false
        micDenied = false
        micDeniedMessage = ""
    }

    func displaySelectIntonation(_ response: VoiceColorsModels.SelectIntonation.Response) {
        intonationMode = response.mode
        intonationMark = response.mark
        modelContour = response.targetContour
        mascotText = response.hint
        liveContour = []
        showResult = false
    }

    func displaySelectStressWord(_ response: VoiceColorsModels.SelectStressWord.Response) {
        chosenWordIndex = response.chosenIndex
        targetWordIndex = response.targetIndex
        stressQuestion = response.question
        showResult = false
    }

    func displaySelectEmotion(_ response: VoiceColorsModels.SelectEmotion.Response) {
        chosenEmotion = response.emotion
        emotionPhrase = response.phrase
        mascotText = response.hint
        reflectedEmotion = nil
        showResult = false
    }

    func displayRecording(_ recording: Bool) {
        isRecording = recording
        if recording {
            showResult = false
            liveContour = []
            liveAmplitude = 0
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

    func displayLiveSample(_ vm: VoiceColorsModels.LiveSample.ViewModel) {
        guard isRecording else { return }
        liveContour = vm.liveContour
        liveAmplitude = vm.amplitudeNormalised
    }

    func displayScore(_ vm: VoiceColorsModels.Score.ViewModel) {
        resultMatch = vm.isMatch
        resultMessage = vm.feedbackMessage
        subtitle = vm.title
        showResult = true
        isRecording = false
        liveAmplitude = 0

        switch vm.mode {
        case .intonation:
            modelContour = vm.modelContour
            liveContour = vm.liveContour
            if vm.isMatch { doneIntonationModes.insert(intonationMode) }
            mascotState = vm.isMatch ? .celebrating : .encouraging
        case .stress:
            perWordHeights = vm.perWordHeights
            loudestWordIndex = vm.loudestWordIndex
            mascotState = vm.isMatch ? .happy : .encouraging
        case .emotion:
            reflectedEmotion = vm.reflectedEmotion
            mascotState = vm.reflectedEmotion.lyalyaState
        }
    }

    func displayComplete(_ vm: VoiceColorsModels.Complete.ViewModel) {
        phase = .completed
        starsEarned = vm.starsEarned
        completionMessage = vm.completionMessage
        matchRate = vm.matchRate
        mascotState = .celebrating
        isRecording = false
        isPlaying = false
    }
}
