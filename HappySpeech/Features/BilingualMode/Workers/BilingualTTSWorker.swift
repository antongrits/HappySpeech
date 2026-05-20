import AVFoundation
import Foundation
import OSLog

// MARK: - BilingualTTSWorkerProtocol

@MainActor
protocol BilingualTTSWorkerProtocol: AnyObject {
    /// Озвучивает текст голосом BCP-47 (например, `"be-BY"` или `"en-US"`).
    /// Если голос для языка не доступен — fallback на `en-US`.
    /// Возвращает фактически использованный bcp47.
    @discardableResult
    func speak(_ text: String, language: BilingualSecondLanguage) async -> String
    /// Останавливает текущее воспроизведение.
    func stop()
    /// Существует ли установленный голос для языка (на текущем устройстве).
    func voiceAvailable(for language: BilingualSecondLanguage) -> Bool
}

// MARK: - BilingualTTSWorker

@MainActor
final class BilingualTTSWorker: NSObject, BilingualTTSWorkerProtocol {

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BilingualMode.TTSWorker"
    )

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public

    @discardableResult
    func speak(_ text: String, language: BilingualSecondLanguage) async -> String {
        guard !text.isEmpty, language != .off else { return language.bcp47 }
        ensurePlaybackSession()

        let (voice, usedBcp47) = Self.pickVoice(for: language)
        if voice == nil {
            Self.logger.warning(
                "No installed voice for \(language.bcp47, privacy: .public); fallback to en-US"
            )
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuation = cont
            synthesizer.speak(utterance)
        }
        return usedBcp47
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        continuation?.resume()
        continuation = nil
    }

    func voiceAvailable(for language: BilingualSecondLanguage) -> Bool {
        guard language != .off else { return false }
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.contains { $0.language == language.bcp47 }
    }

    // MARK: - Audio session

    private func ensurePlaybackSession() {
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

    // MARK: - Voice picking

    /// Возвращает доступный голос + bcp47 для которого он реально нашёлся.
    private static func pickVoice(
        for language: BilingualSecondLanguage
    ) -> (AVSpeechSynthesisVoice?, String) {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let exact = voices.first(where: { $0.language == language.bcp47 }) {
            return (exact, language.bcp47)
        }
        // Belarusian → fallback to ru-RU акустически близко, но методически
        // мы хотим именно второй язык. По ТЗ — fallback на en-US.
        if let english = voices.first(where: { $0.language == "en-US" }) {
            return (english, "en-US")
        }
        return (nil, language.bcp47)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension BilingualTTSWorker: AVSpeechSynthesizerDelegate {

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
