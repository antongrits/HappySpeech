import AVFoundation
import Foundation
import OSLog

// MARK: - GrammarFeedbackWorker

/// Воспроизводит звуковую и тактильную обратную связь при ответах.
/// Использует записанные m4a-фразы Ляли (Resources/Audio/Lyalya/),
/// с откатом на `LessonVoiceWorker` (тоже голос Ляли) если файл не найден.
/// Siri-TTS не используется.
@MainActor
final class GrammarFeedbackWorker: NSObject {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "GrammarFeedback")
    private var audioPlayer: AVAudioPlayer?
    private var speakTask: Task<Void, Never>?

    // MARK: - Lyalya asset names

    private enum LyalyaAsset {
        static let intro = "lyalya_grammar_intro"
        static let correctVariants = [
            "lyalya_grammar_correct_1",
            "lyalya_grammar_correct_2",
            "lyalya_grammar_correct_3"
        ]
        static let tryAgain = "lyalya_grammar_try_again"
        static let hint = "lyalya_grammar_hint"
        static let completeEasy = "lyalya_grammar_complete_easy"
        static let completeMedium = "lyalya_grammar_complete_medium"
        static let completeHard = "lyalya_grammar_complete_hard"

        static func modeIntro(for mode: String) -> String {
            "lyalya_grammar_\(mode)_intro"
        }
    }

    // MARK: - Haptic

    private let hapticService: any HapticService

    init(hapticService: any HapticService = LiveHapticService()) {
        self.hapticService = hapticService
    }

    func playSelectionHaptic() {
        Task { await hapticService.play(pattern: .cardSelect) }
    }

    func playSuccessHaptic() {
        Task { await hapticService.play(pattern: .perfectRound) }
    }

    func playErrorHaptic() {
        Task { await hapticService.play(pattern: .wrong) }
    }

    // MARK: - Lyalya voice-over (m4a assets + TTS fallback)

    /// Озвучивает вводную фразу для игрового режима.
    /// mode — суффикс файла: "one_many", "dative", "genitive", "instrumental".
    func speakQuestion(_ text: String, mode: String? = nil) {
        if let mode {
            let assetName = LyalyaAsset.modeIntro(for: mode)
            if playLyalyaAsset(named: assetName) { return }
        }
        if playLyalyaAsset(named: LyalyaAsset.intro) { return }
        speakTTS(text, rate: 0.45, pitch: 1.10)
    }

    /// Озвучивает подтверждение правильного ответа (случайная из 3 вариаций).
    func speakCorrectFeedback(_ text: String) {
        let variant = LyalyaAsset.correctVariants.randomElement() ?? LyalyaAsset.correctVariants[0]
        if playLyalyaAsset(named: variant) { return }
        speakTTS(text, rate: 0.50, pitch: 1.15)
    }

    /// Озвучивает поощрение при неверном ответе.
    func speakIncorrectFeedback(_ text: String) {
        if playLyalyaAsset(named: LyalyaAsset.tryAgain) { return }
        speakTTS(text, rate: 0.48, pitch: 1.05)
    }

    /// Озвучивает подсказку.
    func speakHint(_ text: String) {
        if playLyalyaAsset(named: LyalyaAsset.hint) { return }
        speakTTS(text, rate: 0.42, pitch: 1.05)
    }

    /// Озвучивает завершение уровня.
    func speakLevelComplete(difficulty: String) {
        let assetName: String
        switch difficulty {
        case "easy":   assetName = LyalyaAsset.completeEasy
        case "hard":   assetName = LyalyaAsset.completeHard
        default:       assetName = LyalyaAsset.completeMedium
        }
        if playLyalyaAsset(named: assetName) { return }
        speakTTS(String(localized: "grammar.game.feedback.level_complete", bundle: .main), rate: 0.50, pitch: 1.15)
    }

    func stopSpeaking() {
        speakTask?.cancel()
        speakTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        LessonVoiceWorker.shared.stop()
    }

    // MARK: - Sound feedback (через HapticService — без системных звуков)

    /// Тактильный feedback успеха (без системных звуков).
    func playSuccessSound() {
        Task { await hapticService.play(pattern: .perfectRound) }
    }

    /// Тактильный feedback ошибки (без системных звуков).
    func playErrorSound() {
        Task { await hapticService.play(pattern: .wrong) }
    }

    // MARK: - Private

    /// Воспроизводит m4a-файл из Audio/Lyalya/.
    /// Audio/ подключён как folder reference, путь в бандле: <bundle>/Audio/Lyalya/<name>.m4a.
    /// Возвращает true если файл найден и воспроизведение запущено.
    @discardableResult
    private func playLyalyaAsset(named name: String) -> Bool {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "m4a",
            subdirectory: "Audio/Lyalya"
        ) else {
            logger.debug("Lyalya asset not found: \(name, privacy: .public) — falling back to TTS")
            return false
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            logger.debug("Lyalya playing: \(name, privacy: .public)")
            return true
        } catch {
            logger.error("AVAudioPlayer failed for \(name, privacy: .public): \(error)")
            return false
        }
    }

    private func speakTTS(_ text: String, rate: Float, pitch: Float) {
        speakTask?.cancel()
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await LessonVoiceWorker.shared.speak(text, lessonType: "grammar", rate: rate)
            self.speakTask = nil
        }
    }

    deinit {
        speakTask?.cancel()
    }
}
