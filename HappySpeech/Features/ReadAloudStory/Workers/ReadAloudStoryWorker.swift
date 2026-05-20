import AVFoundation
import Foundation
import OSLog

// MARK: - ReadAloudStoryWorkerProtocol

@MainActor
public protocol ReadAloudStoryWorkerProtocol: AnyObject {
    /// Размер корпуса историй.
    var libraryCount: Int { get }

    /// Выбирает случайную историю, исключая `excludeStoryId`.
    func pickStory(excluding excludeStoryId: String?) -> ReadAloudStory?

    /// Озвучивает одно предложение голосом ru-RU `Milena`.
    /// Возвращает после того, как чтение завершено или прервано.
    func speakSentence(_ text: String) async

    /// Прерывает текущее воспроизведение, если оно активно.
    func stopSpeaking()
}

// MARK: - ReadAloudStoryWorker (Clean Swift: Worker)
//
// AVSpeechSynthesizer обёртка с ru-RU голосом. Воспроизводит одно
// предложение за раз — каллер (Interactor) управляет последовательностью.
// Скорость чуть ниже стандартной (×0.9) — read-aloud для детей 5–8.

@MainActor
final class ReadAloudStoryWorker: NSObject, ReadAloudStoryWorkerProtocol {

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ReadAloudStory.Worker"
    )

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Corpus

    var libraryCount: Int { ReadAloudStoryCorpus.allStories.count }

    func pickStory(excluding excludeStoryId: String?) -> ReadAloudStory? {
        ReadAloudStoryCorpus.randomStory(excluding: excludeStoryId)
    }

    // MARK: - Audio session

    private func ensureSpokenAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            Self.logger.warning(
                "AVAudioSession setup failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Speaking

    func speakSentence(_ text: String) async {
        guard !text.isEmpty else { return }
        ensureSpokenAudioSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.preferredRussianVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.4

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuation = cont
            synthesizer.speak(utterance)
        }
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        continuation?.resume()
        continuation = nil
    }

    // MARK: - Voice selection

    private static func preferredRussianVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let russian = voices.filter { $0.language == "ru-RU" }
        if let milena = russian.first(where: { $0.name.lowercased().contains("milena") }) {
            return milena
        }
        if let yuri = russian.first(where: { $0.name.lowercased().contains("yuri") }) {
            return yuri
        }
        return russian.first ?? AVSpeechSynthesisVoice(language: "ru-RU")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension ReadAloudStoryWorker: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.continuation?.resume()
            self?.continuation = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.continuation?.resume()
            self?.continuation = nil
        }
    }
}
