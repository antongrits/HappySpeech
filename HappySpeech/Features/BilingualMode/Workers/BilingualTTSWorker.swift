import AVFoundation
import Foundation
import OSLog

// MARK: - BilingualTTSWorkerProtocol

@MainActor
protocol BilingualTTSWorkerProtocol: AnyObject {
    /// Озвучивает слово для выбранного второго языка.
    /// Оба языка (en-US и be-BY) используют pre-recorded m4a голоса Ляли.
    /// - Returns: фактически использованный bcp47.
    @discardableResult
    func speak(_ text: String, language: BilingualSecondLanguage, wordId: String) async -> String
    /// Останавливает текущее воспроизведение.
    func stop()
    /// Существует ли pre-recorded голос для языка (на текущем устройстве).
    func voiceAvailable(for language: BilingualSecondLanguage) -> Bool
}

// MARK: - BilingualTTSWorker
//
// ADR-V32-CHIRP3-AOEDE: Siri TTS полностью удалён.
//   Оба языка используют pre-recorded m4a (Google Chirp3-HD-Aoede):
//     en-US: Audio/Bilingual/en-US/lyalya_bil_en_{wordId}.m4a
//     be-BY: Audio/Bilingual/be-BY/lyalya_bil_be_{wordId}.m4a
//   Корпус (`pack_bilingual_vocabulary.json`) — закрытый, 32 слова на язык,
//   поэтому покрытие 100%. При отсутствии файла (mis-config) — silent skip.
//
// ADR-V31-BILINGUAL-BELARUSIAN-TTS (исторический контекст):
//   be-BY голос недоступен в Google TTS / edge-tts. ru-RU-Chirp3-HD-Aoede
//   используется как акустически близкий fallback для be-BY (то же решение,
//   что было принято для Siri ru-RU); качество детского голоса заметно выше
//   Siri Milena/Katya. Текст белорусский — модель читает кириллицу как ru-RU
//   с белорусской орфографией (мама / тата / хата / акно / дзверы и т.д.).

@MainActor
final class BilingualTTSWorker: NSObject, BilingualTTSWorkerProtocol {

    // MARK: - AVAudioPlayer (для pre-recorded m4a)

    private var player: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BilingualMode.TTSWorker"
    )

    override init() {
        super.init()
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
            return await speakBelarusian(text: text, wordId: wordId)
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
    }

    func voiceAvailable(for language: BilingualSecondLanguage) -> Bool {
        // Оба языка теперь pre-recorded → всегда доступны
        // (при условии, что bundle содержит ассеты, что валидируется в CI).
        switch language {
        case .off: return false
        case .english, .belarusian: return true
        }
    }

    // MARK: - Private: English (pre-recorded Chirp3-HD-Aoede)

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
        await playFileURL(url, logContext: "[bil/en] ")
        return "en-US"
    }

    // MARK: - Private: Belarusian (pre-recorded Chirp3-HD-Aoede, ru-RU model + be-BY text)

    private func speakBelarusian(text: String, wordId: String) async -> String {
        let audioName = "lyalya_bil_be_\(wordId)"
        guard let url = Bundle.main.url(
            forResource: audioName,
            withExtension: "m4a",
            subdirectory: "Audio/Bilingual/be-BY"
        ) else {
            Self.logger.warning(
                "BilingualTTSWorker: no be-BY audio '\(audioName, privacy: .public)' — silent skip"
            )
            return "be-BY"
        }
        await playFileURL(url, logContext: "[bil/be] ")
        return "be-BY"
    }

    // MARK: - Private: shared file playback

    private func playFileURL(_ url: URL, logContext: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            do {
                player?.stop()
                playbackContinuation?.resume()
                playbackContinuation = continuation
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()
                player = newPlayer
                newPlayer.play()
                Self.logger.debug(
                    "\(logContext, privacy: .public)playing: \(url.lastPathComponent, privacy: .public)"
                )
            } catch {
                Self.logger.warning(
                    "\(logContext, privacy: .public)AVAudioPlayer failed: \(error.localizedDescription, privacy: .public)"
                )
                playbackContinuation = nil
                continuation.resume()
            }
        }
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

// MARK: - AVAudioPlayerDelegate

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
