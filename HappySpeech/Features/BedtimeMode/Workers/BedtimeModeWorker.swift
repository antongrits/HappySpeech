import AVFoundation
import Foundation
import OSLog

// MARK: - BedtimeModeWorkerProtocol

@MainActor
public protocol BedtimeModeWorkerProtocol: AnyObject {
    /// Доступная история (случайная, исключая `excludeId`, если задан).
    func pickStory(excluding excludeId: String?) -> BedtimeStory?
    /// Размер корпуса историй.
    var libraryCount: Int { get }
    /// Параметры дыхательного цикла.
    func breathingCycle() -> BedtimeBreathingCycle
    /// Озвучивает текст истории голосом ru-RU (по умолчанию пытается
    /// использовать `Milena`, fallback — системный ru-RU голос).
    func narrate(_ text: String) async
    /// Останавливает текущую озвучку.
    func stopNarration()
}

// MARK: - BedtimeModeWorker (Clean Swift: Worker)

@MainActor
final class BedtimeModeWorker: NSObject, BedtimeModeWorkerProtocol {

    private let synthesizer = AVSpeechSynthesizer()
    private var narrationContinuation: CheckedContinuation<Void, Never>?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BedtimeMode.Worker"
    )

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Corpus

    func pickStory(excluding excludeId: String?) -> BedtimeStory? {
        BedtimeModeCorpus.randomStory(excluding: excludeId)
    }

    var libraryCount: Int { BedtimeModeCorpus.allStories.count }

    func breathingCycle() -> BedtimeBreathingCycle {
        BedtimeBreathingCycle()
    }

    // MARK: - Audio session

    /// Активирует sessionCategory `.spokenAudio` для рассказчика, чтобы
    /// история продолжала играть при выключении экрана и совмещалась с
    /// другими источниками звука (например, тихий фоновый плейлист).
    private func ensureSpokenAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true, options: [])
        } catch {
            Self.logger.warning(
                "AVAudioSession setup failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Narration

    func narrate(_ text: String) async {
        guard !text.isEmpty else { return }
        ensureSpokenAudioSession()

        // Подбираем голос: Milena ru-RU (если установлен), иначе любой ru-RU.
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.preferredRussianVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.5
        utterance.postUtteranceDelay = 0.6

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            narrationContinuation = cont
            synthesizer.speak(utterance)
        }
    }

    func stopNarration() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        narrationContinuation?.resume()
        narrationContinuation = nil
    }

    // MARK: - Voice selection

    private static func preferredRussianVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let russian = voices.filter { $0.language == "ru-RU" }
        if let milena = russian.first(where: { $0.name.lowercased().contains("milena") }) {
            return milena
        }
        if let katya = russian.first(where: { $0.name.lowercased().contains("katya") }) {
            return katya
        }
        return russian.first ?? AVSpeechSynthesisVoice(language: "ru-RU")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension BedtimeModeWorker: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.narrationContinuation?.resume()
            self?.narrationContinuation = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.narrationContinuation?.resume()
            self?.narrationContinuation = nil
        }
    }
}
