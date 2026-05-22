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

    /// Озвучивает одно предложение голосом Ляли (pre-recorded m4a).
    /// - Parameters:
    ///   - text: текст предложения (для логов).
    ///   - storyId: идентификатор истории для поиска аудио-файла.
    ///   - sentenceIndex: индекс предложения (1-based в имени файла).
    /// Возвращает после того, как чтение завершено или прервано.
    func speakSentence(_ text: String, storyId: String, sentenceIndex: Int) async

    /// Прерывает текущее воспроизведение, если оно активно.
    func stopSpeaking()
}

// MARK: - ReadAloudStoryWorker (Clean Swift: Worker)
//
// ADR-V31-AVSpeechSynthesizer-FALLBACK: Siri TTS удалён.
// Каждое предложение озвучивается pre-recorded файлом Ляли (edge-tts SvetlanaNeural,
// rate 90%, хранится в Audio/Lyalya/readaloud/lyalya_ra_{story_slug}_{N}.m4a).
// При отсутствии файла — silent skip (предложение подсвечено на экране).

@MainActor
final class ReadAloudStoryWorker: NSObject, ReadAloudStoryWorkerProtocol {

    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ReadAloudStory.Worker"
    )

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

    func speakSentence(_ text: String, storyId: String, sentenceIndex: Int) async {
        guard !text.isEmpty else { return }
        ensureSpokenAudioSession()

        let slug = storyId.replacingOccurrences(of: "-", with: "_")
        let audioName = "lyalya_ra_\(slug)_\(sentenceIndex)"

        guard let url = Bundle.main.url(
            forResource: audioName,
            withExtension: "m4a",
            subdirectory: "Audio/Lyalya/readaloud"
        ) else {
            Self.logger.warning(
                "ReadAloudStoryWorker: no Lyalya audio '\(audioName, privacy: .public)' — silent skip"
            )
            #if DEBUG
            assertionFailure("ReadAloudStoryWorker: missing audio '\(audioName)'")
            #endif
            return
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                player?.stop()
                continuation?.resume()
                continuation = cont
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()
                player = newPlayer
                newPlayer.play()
                Self.logger.debug("ReadAloud: playing '\(audioName, privacy: .public)'")
            } catch {
                Self.logger.warning(
                    "ReadAloudStoryWorker: AVAudioPlayer failed: \(error.localizedDescription, privacy: .public)"
                )
                continuation = nil
                cont.resume()
            }
        }
    }

    func stopSpeaking() {
        player?.stop()
        player = nil
        continuation?.resume()
        continuation = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension ReadAloudStoryWorker: AVAudioPlayerDelegate {

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.continuation?.resume()
            self?.continuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            Self.logger.error(
                "ReadAloudStoryWorker: decode error: \(error?.localizedDescription ?? "unknown", privacy: .public)"
            )
            self?.continuation?.resume()
            self?.continuation = nil
        }
    }
}
