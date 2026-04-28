import AVFoundation
import Foundation
import OSLog

// MARK: - CustomizationVoicePreviewWorker

/// Воспроизводит preview-голос Ляли.
/// Приоритет: m4a файл из Resources/Audio/Voice/ → AVSpeechSynthesizer fallback.
/// Файлы: lyalya_voice_classic_preview.m4a, lyalya_voice_soft_preview.m4a, lyalya_voice_cheerful_preview.m4a
/// (добавляются sound-curator на шаге F2-009)
@MainActor
final class CustomizationVoicePreviewWorker: NSObject {

    // MARK: - State

    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private(set) var currentVoice: LyalyaVoice?
    var onPlaybackFinished: ((LyalyaVoice) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CustomizationVoicePreviewWorker")

    private let previewPhrase = "Привет! Я Ляля! Давай заниматься!"

    // MARK: - Play

    /// Запускает воспроизведение preview для выбранного голоса.
    /// Если тот же голос уже играет — останавливает.
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
        // Fallback: AVSpeechSynthesizer
        playWithTTS(voice: voice)
    }

    // MARK: - Stop

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
        currentVoice = nil
    }

    // MARK: - Private: file playback

    private func tryPlayFile(voice: LyalyaVoice) -> Bool {
        guard let url = Bundle.main.url(
            forResource: voice.previewFile,
            withExtension: "m4a",
            subdirectory: "Audio/Voice"
        ) else {
            logger.info("Preview file not found for voice=\(voice.rawValue), falling back to TTS")
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

    // MARK: - Private: TTS fallback

    private func playWithTTS(voice: LyalyaVoice) {
        let synth = AVSpeechSynthesizer()
        synth.delegate = self
        speechSynthesizer = synth

        let utterance = AVSpeechUtterance(string: previewPhrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.pitchMultiplier = voice.speechPitch
        utterance.rate = voice == .cheerful ? 0.52 : (voice == .soft ? 0.44 : 0.48)

        synth.speak(utterance)
        logger.info("TTS fallback playing for voice=\(voice.rawValue)")
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

// MARK: - AVSpeechSynthesizerDelegate

extension CustomizationVoicePreviewWorker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let voice = self.currentVoice {
                self.onPlaybackFinished?(voice)
            }
            self.currentVoice = nil
            self.speechSynthesizer = nil
        }
    }
}
