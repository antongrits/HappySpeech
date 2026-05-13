import AVFoundation
import Foundation
import OSLog

// MARK: - PhonemeAudioWorkerProtocol

@MainActor
protocol PhonemeAudioWorkerProtocol: AnyObject {
    /// Воспроизводит сэмпл фонемы. Если в bundle нет нужного файла —
    /// fallback на ``AVSpeechSynthesizer`` (RU).
    /// Возвращает `(success, usedFallbackTTS)`.
    func playSample(for entry: PhonemeEntry) async -> (Bool, Bool)
    func stop()
}

// MARK: - PhonemeAudioWorker
//
// Block AE v21 — звуковой воркер для SoundDictionary.
//
// Стратегия:
//  1. Если у фонемы есть `audioResourceName` и файл найден в bundle —
//     воспроизводим через ``AVAudioPlayer``.
//  2. Иначе — fallback: ``AVSpeechSynthesizer`` с русским голосом
//     и pre-utterance delay 0.05s. Скорость 0.45 — медленнее обычной,
//     чтобы ребёнок слышал артикуляцию.
//
// Поток: воркер привязан к main actor; для playback используется
// `AVAudioPlayer` (фоновое декодирование внутри AVF).

@MainActor
final class PhonemeAudioWorker: PhonemeAudioWorkerProtocol {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDictionary.AudioWorker"
    )

    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()

    init() {}

    func playSample(for entry: PhonemeEntry) async -> (Bool, Bool) {
        // 1. Bundle .m4a first.
        if let name = entry.audioResourceName,
           let url = Bundle.main.url(forResource: name, withExtension: "m4a") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = 0.95
                let ok = player.play()
                self.player = player
                if ok {
                    Self.logger.debug("playSample bundle ok: \(name, privacy: .public)")
                    return (true, false)
                }
            } catch {
                Self.logger.error("playSample bundle failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // 2. Fallback to TTS.
        let utterance = AVSpeechUtterance(string: entry.cyrillic)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = 0.45
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
        Self.logger.debug("playSample TTS fallback: \(entry.cyrillic, privacy: .public)")
        return (true, true)
    }

    func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
