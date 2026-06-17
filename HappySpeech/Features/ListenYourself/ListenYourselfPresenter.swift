import Foundation

// MARK: - ListenYourselfPresentationLogic

@MainActor
protocol ListenYourselfPresentationLogic: AnyObject {
    func presentLoadWord(response: ListenYourselfModels.LoadWord.Response) async
    func presentRecordingStarted(takeNumber: Int) async
    func presentRecordTake(
        response: ListenYourselfModels.RecordTake.Response,
        suggestedChoice: Int?
    ) async
    func presentRecordingFailed(message: String) async
    func presentChoice(response: ListenYourselfModels.ChooseTake.Response)
    func presentCompare(word: String, chosenTakeNumber: Int)
    func presentJudge(response: ListenYourselfModels.Judge.Response) async
    func presentSecretTip(response: ListenYourselfModels.SecretTip.Response) async
    func presentReset()
}

// MARK: - ListenYourselfPresenter
//
// Формирует ViewModel из Response Interactor'а и пишет в @Observable-стор
// (`ListenYourselfDisplayLogic`). Без бизнес-логики: только маппинг и
// форматирование (длительность дубля → «0:02» и т.п.).

@MainActor
final class ListenYourselfPresenter: ListenYourselfPresentationLogic {

    // MARK: - Output

    weak var display: (any ListenYourselfDisplayLogic)?

    // MARK: - Init

    init(display: (any ListenYourselfDisplayLogic)? = nil) {
        self.display = display
    }

    // MARK: - Load word

    func presentLoadWord(response: ListenYourselfModels.LoadWord.Response) async {
        let viewModel = ListenYourselfModels.LoadWord.ViewModel(
            word: response.word,
            targetSound: response.targetSound,
            illustrationSymbol: response.illustrationSymbol,
            highlightLetter: response.highlightLetter,
            cues: ListenYourselfWordProvider.cues(forSound: response.targetSound)
        )
        await display?.displayWord(viewModel)
    }

    // MARK: - Recording

    func presentRecordingStarted(takeNumber: Int) async {
        await display?.displayRecordingStarted(takeNumber: takeNumber)
    }

    func presentRecordTake(
        response: ListenYourselfModels.RecordTake.Response,
        suggestedChoice: Int?
    ) async {
        await display?.displayTake(
            number: response.takeNumber,
            durationText: Self.durationText(response.take.durationSec),
            bothReady: response.bothTakesReady,
            suggestedChoice: suggestedChoice
        )
    }

    func presentRecordingFailed(message: String) async {
        await display?.displayRecordingFailed(message: message)
    }

    // MARK: - Choice

    func presentChoice(response: ListenYourselfModels.ChooseTake.Response) {
        display?.displayChoice(chosenTakeNumber: response.chosenTakeNumber)
    }

    // MARK: - Compare

    func presentCompare(word: String, chosenTakeNumber: Int) {
        display?.displayCompare(word: word, chosenTakeNumber: chosenTakeNumber)
    }

    // MARK: - Judge

    func presentJudge(response: ListenYourselfModels.Judge.Response) async {
        await display?.displayJudge(
            judgement: response.judgement,
            mascotMessage: response.mascotMessage
        )
    }

    // MARK: - Secret tip

    func presentSecretTip(response: ListenYourselfModels.SecretTip.Response) async {
        await display?.displaySecretTip(tip: response.tip)
    }

    // MARK: - Reset

    func presentReset() {
        display?.displayReset()
    }

    // MARK: - Formatting

    /// «0:02» из длительности в секундах. Минимум «0:01» для очень коротких.
    static func durationText(_ seconds: Double) -> String {
        let total = max(1, Int(seconds.rounded()))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
