import Foundation
import OSLog

// MARK: - SoundDictionaryBusinessLogic

@MainActor
protocol SoundDictionaryBusinessLogic: AnyObject {
    func load(request: SoundDictionaryModels.Load.Request) async
    func selectPhoneme(request: SoundDictionaryModels.SelectPhoneme.Request) async
    func playAudio(request: SoundDictionaryModels.PlayAudio.Request) async
    func practicePhoneme(request: SoundDictionaryModels.PracticePhoneme.Request) async
}

// MARK: - SoundDictionaryDataStore

@MainActor
protocol SoundDictionaryDataStore: AnyObject {
    var selectedPhoneme: PhonemeEntry? { get set }
}

// MARK: - SoundDictionaryInteractor (Clean Swift: Interactor)
//
// Block AE v21 — интерактивная фонетическая энциклопедия.
//
// Ответственность:
//   • Загрузить статический корпус 42 фонем (`PhonemeCorpus.all`).
//   • Выбрать конкретную фонему — собрать Response для детального sheet.
//   • Воспроизвести образец произношения (через ``PhonemeAudioWorker``).
//   • Передать запрос на практику в Router (через презентер → display layer).
//
// COPPA: всё on-device; no networking; PhonemeCorpus статический.

@MainActor
final class SoundDictionaryInteractor: SoundDictionaryBusinessLogic, SoundDictionaryDataStore {

    // MARK: - DataStore

    var selectedPhoneme: PhonemeEntry?

    // MARK: - VIP

    var presenter: (any SoundDictionaryPresentationLogic)?

    // MARK: - Workers

    private let audioWorker: any PhonemeAudioWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDictionary.Interactor"
    )

    // MARK: - Init

    init(
        audioWorker: any PhonemeAudioWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.audioWorker = audioWorker
        self.hapticService = hapticService
    }

    // MARK: - Load

    func load(request: SoundDictionaryModels.Load.Request) async {
        _ = request
        let response = SoundDictionaryModels.Load.Response(
            entries: PhonemeCorpus.all
        )
        Self.logger.debug("Loaded \(response.entries.count) phonemes")
        await presenter?.presentLoad(response: response)
    }

    // MARK: - SelectPhoneme

    func selectPhoneme(request: SoundDictionaryModels.SelectPhoneme.Request) async {
        guard let entry = PhonemeCorpus.entry(forId: request.phonemeId) else {
            Self.logger.error("Unknown phoneme id: \(request.phonemeId, privacy: .public)")
            return
        }
        self.selectedPhoneme = entry

        let response = SoundDictionaryModels.SelectPhoneme.Response(
            entry: entry,
            hasAudio: entry.audioResourceName != nil
        )
        hapticService.selection()
        await presenter?.presentSelectPhoneme(response: response)
    }

    // MARK: - PlayAudio

    func playAudio(request: SoundDictionaryModels.PlayAudio.Request) async {
        guard let entry = PhonemeCorpus.entry(forId: request.phonemeId) else {
            Self.logger.error("playAudio: unknown phoneme \(request.phonemeId, privacy: .public)")
            return
        }
        let (ok, usedTTS) = await audioWorker.playSample(for: entry)
        Self.logger.debug("playAudio \(entry.id, privacy: .public) ok=\(ok) tts=\(usedTTS)")
        let response = SoundDictionaryModels.PlayAudio.Response(
            success: ok,
            usedFallbackTTS: usedTTS
        )
        await presenter?.presentPlayAudio(response: response)
    }

    // MARK: - PracticePhoneme

    func practicePhoneme(request: SoundDictionaryModels.PracticePhoneme.Request) async {
        Self.logger.info("Practice requested: \(request.phonemeId, privacy: .public)")
        let response = SoundDictionaryModels.PracticePhoneme.Response(
            phonemeId: request.phonemeId
        )
        hapticService.impact(.light)
        await presenter?.presentPracticePhoneme(response: response)
    }
}
