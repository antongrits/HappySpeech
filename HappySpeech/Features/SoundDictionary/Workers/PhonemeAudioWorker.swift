import AVFoundation
import Foundation
import OSLog

// MARK: - PhonemeAudioWorkerProtocol

@MainActor
protocol PhonemeAudioWorkerProtocol: AnyObject {
    /// Воспроизводит сэмпл фонемы. Если в bundle нет нужного файла —
    /// fallback на голос Ляли (записанное слово-пример через ``LessonVoiceWorker``).
    /// Возвращает `(success, usedFallbackTTS)`.
    func playSample(for entry: PhonemeEntry) async -> (Bool, Bool)
    func stop()
}

// MARK: - PhonemeAudioWorker
//
// Block AE v21 — звуковой воркер для SoundDictionary.
//
// Стратегия (v25 — без Siri TTS):
//  1. Если у фонемы есть `audioResourceName` и файл найден в bundle —
//     воспроизводим через ``AVAudioPlayer``.
//  2. Иначе — fallback: записанный голос Ляли через ``LessonVoiceWorker``.
//     Озвучивается слово-пример фонемы (например «солнце» для «С»), а не
//     одиночная буква — слово есть в `lyalya-phrase-mapping.json`. Если и
//     слова в маппинге нет — тишина (silent skip), но НИКОГДА не Siri.
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
    private var speakTask: Task<Void, Never>?

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

        // 2. Fallback — голос Ляли: озвучиваем слово-пример фонемы.
        //    Если слова нет в маппинге Ляли — LessonVoiceWorker делает
        //    silent skip. Siri TTS не используется.
        Self.logger.debug("playSample Lyalya fallback: \(entry.exampleWord, privacy: .public)")
        speakTask?.cancel()
        speakTask = Task { @MainActor [weak self] in
            await LessonVoiceWorker.shared.speak(
                entry.exampleWord,
                lessonType: "sound_dictionary"
            )
            self?.speakTask = nil
        }
        // usedFallbackTTS=false: системный Siri-TTS больше не задействован.
        return (true, false)
    }

    func stop() {
        player?.stop()
        player = nil
        speakTask?.cancel()
        speakTask = nil
        LessonVoiceWorker.shared.stop()
    }
}
