import Foundation
import Observation

// MARK: - ListenYourselfDisplayLogic

/// Контракт обновления UI-стора из Presenter (Clean Swift: View ← store ← Presenter).
@MainActor
protocol ListenYourselfDisplayLogic: AnyObject {
    func displayWord(_ viewModel: ListenYourselfModels.LoadWord.ViewModel) async
    func displayRecordingStarted(takeNumber: Int) async
    func displayTake(
        number: Int,
        durationText: String,
        bothReady: Bool,
        suggestedChoice: Int?
    ) async
    func displayRecordingFailed(message: String) async
    func displayChoice(chosenTakeNumber: Int)
    func displayCompare(word: String, chosenTakeNumber: Int)
    func displayJudge(
        judgement: ListenYourselfModels.SelfJudgement,
        mascotMessage: String
    ) async
    func displaySecretTip(tip: String?) async
    func displayReset()
}

// MARK: - ListenYourselfStore
//
// @Observable источник правды для `ListenYourselfView`. Хранит лёгкое UI-состояние
// (фаза, слово, метаданные дублей, выбор, самооценка, совет). Аудио-файлы держит
// Interactor — стор оперирует номерами/подписями, не URL.

@MainActor
@Observable
final class ListenYourselfStore: ListenYourselfDisplayLogic {

    /// Внутренняя UI-фаза экрана.
    enum Screen: Equatable {
        case loading
        /// Экран 1 «Два дубля» (запись + выбор).
        case takes
        /// Экран 2 «Сравни с Лялей» (A/B + самооценка).
        case compare
    }

    // MARK: - Published UI state

    var screen: Screen = .loading

    var word: String = ""
    var targetSound: String = ""
    var illustrationSymbol: String = ""
    var highlightLetter: String = ""
    var cues: [ListenYourselfModels.ArticulationCue] = []

    /// Номер дубля, который сейчас записывается (nil — не пишем).
    var recordingTakeNumber: Int?
    /// Метаданные записанных дублей: номер → подпись длительности «0:02».
    var takeDurations: [Int: String] = [:]
    /// Оба дубля записаны.
    var bothTakesReady: Bool = false
    /// Выбранный ребёнком лучший дубль (nil — ещё не выбран).
    var chosenTakeNumber: Int?
    /// Сообщение об ошибке записи (тёплое, на русском) — авто-скрывается.
    var recordingErrorMessage: String?

    /// Самооценка ребёнка (экран 2).
    var judgement: ListenYourselfModels.SelfJudgement?
    /// Сообщение Ляли после самооценки.
    var mascotMessage: String = ""
    /// «Секретный совет» (ASR) — показывается только после запроса ребёнка.
    var secretTip: String?
    /// Совет уже запрашивался (чтобы не дёргать ASR повторно).
    var secretTipRequested: Bool = false

    init() {}

    /// Число записанных дублей.
    var recordedTakesCount: Int { takeDurations.count }

    // MARK: - DisplayLogic

    func displayWord(_ viewModel: ListenYourselfModels.LoadWord.ViewModel) async {
        word = viewModel.word
        targetSound = viewModel.targetSound
        illustrationSymbol = viewModel.illustrationSymbol
        highlightLetter = viewModel.highlightLetter
        cues = viewModel.cues
        screen = .takes
    }

    func displayRecordingStarted(takeNumber: Int) async {
        recordingTakeNumber = takeNumber
        recordingErrorMessage = nil
    }

    func displayTake(
        number: Int,
        durationText: String,
        bothReady: Bool,
        suggestedChoice: Int?
    ) async {
        recordingTakeNumber = nil
        takeDurations[number] = durationText
        bothTakesReady = bothReady
        if bothReady, chosenTakeNumber == nil {
            chosenTakeNumber = suggestedChoice
        }
    }

    func displayRecordingFailed(message: String) async {
        recordingTakeNumber = nil
        recordingErrorMessage = message
    }

    func displayChoice(chosenTakeNumber: Int) {
        self.chosenTakeNumber = chosenTakeNumber
    }

    func displayCompare(word: String, chosenTakeNumber: Int) {
        self.word = word
        self.chosenTakeNumber = chosenTakeNumber
        screen = .compare
    }

    func displayJudge(
        judgement: ListenYourselfModels.SelfJudgement,
        mascotMessage: String
    ) async {
        self.judgement = judgement
        self.mascotMessage = mascotMessage
    }

    func displaySecretTip(tip: String?) async {
        secretTip = tip
        secretTipRequested = true
    }

    func displayReset() {
        recordingTakeNumber = nil
        takeDurations = [:]
        bothTakesReady = false
        chosenTakeNumber = nil
        recordingErrorMessage = nil
        judgement = nil
        mascotMessage = ""
        secretTip = nil
        secretTipRequested = false
        screen = .takes
    }
}
