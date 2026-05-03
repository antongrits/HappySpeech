import AVFoundation
import Foundation
import OSLog

// MARK: - CustomizationVoicePreviewWorker

/// Воспроизводит preview-голос Ляли.
/// Приоритет: m4a файл из Resources/Audio/Voice/ → silent skip (без Siri TTS).
/// Файлы: lyalya_voice_classic_preview.m4a, lyalya_voice_soft_preview.m4a, lyalya_voice_cheerful_preview.m4a
/// (добавляются sound-curator на шаге F2-009)
@MainActor
final class CustomizationVoicePreviewWorker: NSObject {

    // MARK: - State

    private var audioPlayer: AVAudioPlayer?
    private(set) var currentVoice: LyalyaVoice?
    var onPlaybackFinished: ((LyalyaVoice) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CustomizationVoicePreviewWorker")

    // MARK: - Play

    /// Запускает воспроизведение preview для выбранного голоса.
    /// Если тот же голос уже играет — останавливает.
    /// Если m4a файл не найден — silent skip (без Siri TTS).
    func play(voice: LyalyaVoice) {
        if currentVoice == voice {
            stop()
            return
        }
        stop()
        currentVoice = voice

        if tryPlayFile(voice: voice) {
            return
        }
        // Silent skip: preview файл не записан — логируем warning, не используем Siri TTS
        logger.warning("Preview m4a not found for voice=\(voice.rawValue) — silent skip (add to sound-assets)")
        currentVoice = nil
        onPlaybackFinished?(voice)
    }

    // MARK: - Stop

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentVoice = nil
    }

    // MARK: - Private: file playback

    private func tryPlayFile(voice: LyalyaVoice) -> Bool {
        guard let url = Bundle.main.url(
            forResource: voice.previewFile,
            withExtension: "m4a",
            subdirectory: "Audio/Voice"
        ) else {
            logger.info("Preview file not found for voice=\(voice.rawValue)")
            return false
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            logger.info("Playing preview file for voice=\(voice.rawValue)")
            return true
        } catch {
            logger.error("AVAudioPlayer init failed: \(error)")
            return false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension CustomizationVoicePreviewWorker: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let voice = self.currentVoice {
                self.onPlaybackFinished?(voice)
            }
            self.currentVoice = nil
            self.audioPlayer = nil
        }
    }
}
