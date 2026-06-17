import Foundation
import OSLog

// MARK: - AdvancedGrammarFeedbackWorker
//
// Озвучка и тактильная обратная связь «Грамматического конструктора-2».
// Голос — записи Ляли через `LessonVoiceWorker` (с silent-skip, если нет m4a);
// Siri-TTS для целых фраз не используется. Хаптика — через `HapticService`.

@MainActor
final class AdvancedGrammarFeedbackWorker {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "AdvancedGrammarFeedback")
    private let haptic: any HapticService
    private let voice: LessonVoiceWorker
    private var speakTask: Task<Void, Never>?

    init(
        haptic: any HapticService = LiveHapticService(),
        voice: LessonVoiceWorker = .shared
    ) {
        self.haptic = haptic
        self.voice = voice
    }

    deinit {
        speakTask?.cancel()
    }

    // MARK: - Haptic

    func selection() {
        Task { [haptic] in await haptic.play(pattern: .cardSelect) }
    }

    func success() {
        Task { [haptic] in await haptic.play(pattern: .perfectRound) }
    }

    func softError() {
        Task { [haptic] in await haptic.play(pattern: .wrong) }
    }

    // MARK: - Voice

    /// Проговаривает произвольный текст (вопрос / полную фразу / подсказку)
    /// голосом Ляли. `onFinished` зовётся на @MainActor после завершения.
    func speak(_ text: String, onFinished: (@MainActor () -> Void)? = nil) {
        guard !text.isEmpty else { onFinished?(); return }
        speakTask?.cancel()
        voice.stop()
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voice.speak(text, lessonType: "advanced_grammar")
            guard !Task.isCancelled else { return }
            onFinished?()
            self.speakTask = nil
        }
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        voice.stop()
    }
}
