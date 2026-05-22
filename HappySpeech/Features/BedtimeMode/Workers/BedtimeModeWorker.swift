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
    /// Озвучивает текст истории голосом Ляли (pre-recorded m4a).
    /// При отсутствии файла — silent skip с Logger.warning.
    func narrate(_ text: String, storyId: String) async
    /// Останавливает текущую озвучку.
    func stopNarration()
}

// MARK: - BedtimeModeWorker (Clean Swift: Worker)
//
// ADR-V31-AVSpeechSynthesizer-FALLBACK: Siri TTS удалён.
// Каждая сказка озвучивается pre-recorded файлом Ляли (edge-tts SvetlanaNeural,
// rate 85%, хранится в Audio/Lyalya/bedtime/<storyId>.m4a).
// При отсутствии файла — silent skip (текст виден на экране).

@MainActor
final class BedtimeModeWorker: BedtimeModeWorkerProtocol {

    private var player: AVAudioPlayer?
    private var narrationContinuation: CheckedContinuation<Void, Never>?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BedtimeMode.Worker"
    )

    // MARK: - story_id → audio filename mapping

    /// Маппинг идентификатора истории на имя файла в Audio/Lyalya/bedtime/.
    private static let storyAudioMap: [String: String] = [
        "story-cloud":   "lyalya_bedtime_cloud",
        "story-rabbit":  "lyalya_bedtime_rabbit",
        "story-river":   "lyalya_bedtime_river",
        "story-moon":    "lyalya_bedtime_moon",
        "story-pillow":  "lyalya_bedtime_pillow",
        "story-bear":    "lyalya_bedtime_bear",
        "story-leaf":    "lyalya_bedtime_leaf",
        "story-stars":   "lyalya_bedtime_stars",
        "story-fish":    "lyalya_bedtime_fish",
        "story-sun":     "lyalya_bedtime_sun",
        "story-snowman": "lyalya_bedtime_snowman",
        "story-mama":    "lyalya_bedtime_mama"
    ]

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

    /// Озвучивает сказку через pre-recorded голос Ляли.
    /// `storyId` используется для поиска файла; `text` — только для логов.
    func narrate(_ text: String, storyId: String) async {
        guard !text.isEmpty else { return }
        ensureSpokenAudioSession()

        guard let audioName = Self.storyAudioMap[storyId],
              let url = Bundle.main.url(
                forResource: audioName,
                withExtension: "m4a",
                subdirectory: "Audio/Lyalya/bedtime"
              ) else {
            Self.logger.warning(
                "BedtimeModeWorker: no Lyalya audio for storyId '\(storyId, privacy: .public)' — silent skip"
            )
            #if DEBUG
            assertionFailure("BedtimeModeWorker: missing bedtime audio for '\(storyId)'")
            #endif
            return
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                player?.stop()
                narrationContinuation?.resume()
                narrationContinuation = cont
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()
                player = newPlayer
                newPlayer.play()
                Self.logger.debug("BedtimeMode: playing '\(audioName, privacy: .public)'")
            } catch {
                Self.logger.warning(
                    "BedtimeModeWorker: AVAudioPlayer failed for '\(audioName, privacy: .public)': \(error.localizedDescription, privacy: .public)"
                )
                narrationContinuation = nil
                cont.resume()
            }
        }
    }

    func stopNarration() {
        player?.stop()
        player = nil
        narrationContinuation?.resume()
        narrationContinuation = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension BedtimeModeWorker: AVAudioPlayerDelegate {

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.narrationContinuation?.resume()
            self?.narrationContinuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            Self.logger.error(
                "BedtimeModeWorker: decode error: \(error?.localizedDescription ?? "unknown", privacy: .public)"
            )
            self?.narrationContinuation?.resume()
            self?.narrationContinuation = nil
        }
    }
}
