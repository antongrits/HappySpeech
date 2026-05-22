import AVFoundation
import Foundation
import OSLog

// MARK: - BilingualTTSWorkerProtocol

@MainActor
protocol BilingualTTSWorkerProtocol: AnyObject {
    /// Озвучивает слово для выбранного второго языка.
    /// Для en-US использует pre-recorded голос Ляли (AnaNeural, детский).
    /// Для be-BY использует Siri TTS (be-BY недоступен в edge-tts —
    /// см. ADR-V31-BILINGUAL-BELARUSIAN-TTS).
    /// - Returns: фактически использованный bcp47.
    @discardableResult
    func speak(_ text: String, language: BilingualSecondLanguage, wordId: String) async -> String
    /// Останавливает текущее воспроизведение.
    func stop()
    /// Существует ли установленный голос для языка (на текущем устройстве).
    func voiceAvailable(for language: BilingualSecondLanguage) -> Bool
}

// MARK: - BilingualTTSWorker
//
// ADR-V31-BILINGUAL-BELARUSIAN-TTS:
//   be-BY голос недоступен в edge-tts (поддерживает только fr-BE и nl-BE).
//   Для белорусского языка сохраняется Siri TTS — это единственное место
//   в приложении с AVSpeechSynthesizer. Обоснование:
//   (a) be-BY — не «голос Ляли» по дизайну (это нативный голос второго языка);
//   (b) обе платформенные ru-RU озвучки (Milena/Katya) акустически близки;
//   (c) альтернатива — open-source VITS/TTS-моделей — выходит за рамки Sprint 12.
//   Тикет для будущей волны: «Заменить be-BY Siri на VITS-модель белорусского».
//
// en-US: pre-recorded через edge-tts AnaNeural (детский голос).
//   Файлы: Audio/Bilingual/en-US/lyalya_bil_en_{wordId}.m4a

@MainActor
final class BilingualTTSWorker: NSObject, BilingualTTSWorkerProtocol {

    // MARK: - AVAudioPlayer (для en-US pre-recorded)

    private var player: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    // MARK: - AVSpeechSynthesizer (только для be-BY — см. ADR выше)

    // swiftlint:disable:next weak_delegate
    private let synthesizer = AVSpeechSynthesizer()
    private var speechContinuation: CheckedContinuation<Void, Never>?

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
    func speak(
        _ text: String,
        language: BilingualSecondLanguage,
        wordId: String
    ) async -> String {
        guard !text.isEmpty, language != .off else { return language.bcp47 }
        ensurePlaybackSession()

        switch language {
        case .english:
            return await speakEnglish(text: text, wordId: wordId)
        case .belarusian:
            return await speakBelarusian(text: text)
        case .off:
            return language.bcp47
        }
    }

    func stop() {
        // Stop m4a playback.
        player?.stop()
        player = nil
        let pc = playbackContinuation
        playbackContinuation = nil
        pc?.resume()

        // Stop Siri TTS (be-BY).
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // speechContinuation будет resume через delegate didCancel.
    }

    func voiceAvailable(for language: BilingualSecondLanguage) -> Bool {
        switch language {
        case .off: return false
        case .english: return true   // pre-recorded — всегда доступно
        case .belarusian:
            // Siri be-BY — зависит от установленных голосов на устройстве.
            let voices = AVSpeechSynthesisVoice.speechVoices()
            return voices.contains { $0.language == language.bcp47 }
        }
    }

    // MARK: - Private: English (pre-recorded AnaNeural)

    private func speakEnglish(text: String, wordId: String) async -> String {
        let audioName = "lyalya_bil_en_\(wordId)"
        guard let url = Bundle.main.url(
            forResource: audioName,
            withExtension: "m4a",
            subdirectory: "Audio/Bilingual/en-US"
        ) else {
            Self.logger.warning(
                "BilingualTTSWorker: no en-US audio '\(audioName, privacy: .public)' — silent skip"
            )
            return "en-US"
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                player?.stop()
                playbackContinuation?.resume()
                playbackContinuation = cont
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()
                player = newPlayer
                newPlayer.play()
                Self.logger.debug("Bilingual EN: '\(audioName, privacy: .public)'")
            } catch {
                Self.logger.warning(
                    "BilingualTTSWorker: AVAudioPlayer failed: \(error.localizedDescription, privacy: .public)"
                )
                playbackContinuation = nil
                cont.resume()
            }
        }
        return "en-US"
    }

    // MARK: - Private: Belarusian (Siri TTS — ADR-V31-BILINGUAL-BELARUSIAN-TTS)

    private func speakBelarusian(_ text: String) async -> String {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let (voice, usedBcp47) = Self.pickBelarusianVoice()
        if voice == nil {
            Self.logger.warning(
                "BilingualTTSWorker: no installed be-BY voice; fallback to ru-RU"
            )
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            speechContinuation?.resume()
            speechContinuation = cont
            synthesizer.speak(utterance)
        }
        return usedBcp47
    }

    // MARK: - Private: Voice picking

    private static func pickBelarusianVoice() -> (AVSpeechSynthesisVoice?, String) {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        // be-BY
        if let bel = voices.first(where: { $0.language == "be-BY" }) {
            return (bel, "be-BY")
        }
        // Акустически близкий ru-RU как вынужденный fallback.
        if let ru = voices.first(where: { $0.language == "ru-RU" }) {
            return (ru, "ru-RU")
        }
        return (AVSpeechSynthesisVoice(language: "ru-RU"), "ru-RU")
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
}

// MARK: - AVAudioPlayerDelegate (en-US pre-recorded)

extension BilingualTTSWorker: AVAudioPlayerDelegate {

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            Self.logger.error(
                "BilingualTTSWorker: decode error: \(error?.localizedDescription ?? "unknown", privacy: .public)"
            )
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate (be-BY — ADR-V31-BILINGUAL-BELARUSIAN-TTS)

extension BilingualTTSWorker: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.speechContinuation?.resume()
            self?.speechContinuation = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.speechContinuation?.resume()
            self?.speechContinuation = nil
        }
    }
}
