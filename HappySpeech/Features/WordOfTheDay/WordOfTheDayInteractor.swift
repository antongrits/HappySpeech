import Foundation
import OSLog

// MARK: - WordOfTheDayInteractor

/// «Слово дня»: ребёнок произносит слово дня, получает оценку.
///
/// Block C v23: ранее `startRecording()` фабриковал `Int.random(2...3)` звёзд
/// без реального аудио. Теперь — настоящая запись + on-device pronunciation
/// scoring (тот же ``PronunciationScorerService``, что в основном контуре).
/// Если ввод недоступен (нет микрофона / запись упала / звук не оценён) —
/// нейтральный исход `.tryAgain`, БЕЗ сфабрикованных звёзд.
@MainActor
@Observable
final class WordOfTheDayInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordOfTheDay"
    )

    let childId: String
    var card: WordOfTheDayModels.Card
    var phase: WordOfTheDayModels.RecordingPhase = .idle
    /// true в промежутке воспроизведения модели Ляли
    var isPlayingModel: Bool = false

    private let audioService: (any AudioService)?
    private let scorer: (any PronunciationScorerService)?
    /// F1-016 — единый планировщик интервальных повторов. Слово дня — стандалон-фича
    /// вне SessionShell, поэтому кормит FSRS напрямую. Опционален: при `nil`
    /// (Preview/неполная среда) повтор просто не фиксируется.
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private var scoringTask: Task<Void, Never>?

    /// Порог «зачёта» произношения для интервального повтора: ★≥2 (та же планка
    /// «good», что используется в остальных контурах). Ниже — слово возвращается на
    /// повтор завтра, не наказание.
    private static let passStars = 2

    init(
        childId: String,
        audioService: (any AudioService)? = nil,
        scorer: (any PronunciationScorerService)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.card = WordOfTheDayModels.wordForToday()
        self.audioService = audioService
        self.scorer = scorer
        self.adaptivePlanner = adaptivePlanner
    }

    /// Озвучивает слово дня голосом Ляли — реальная запись слова из phrase-mapping
    /// (через LessonVoiceWorker), а не canned-фраза. `isPlayingModel` сбрасывается
    /// по фактическому завершению воспроизведения (speak ждёт конца).
    func playModelAudio() {
        guard !isPlayingModel else { return }
        isPlayingModel = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            await LessonVoiceWorker.shared.speak(self.card.word, lessonType: "word_of_the_day")
            self.isPlayingModel = false
        }
    }

    func startRecording() {
        guard phase != .recording else { return }
        phase = .recording

        scoringTask?.cancel()
        scoringTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.recordAndScore()
        }
    }

    func reset() {
        scoringTask?.cancel()
        scoringTask = nil
        phase = .idle
    }

    // MARK: - Private

    private func recordAndScore() async {
        guard let audioService, let scorer else {
            // Сервисы не инжектированы (Preview/неполная среда) — без фабрикации.
            Self.logger.debug("WOTD: audio/scorer недоступны — tryAgain")
            phase = .tryAgain
            return
        }

        // Разрешение на микрофон (обычно уже выдано на PermissionsView).
        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            if !granted {
                Self.logger.info("WOTD: микрофон не разрешён — tryAgain")
                phase = .tryAgain
                return
            }
        }

        do {
            try await audioService.startRecording()
            // Короткая запись слова дня (детский UX: ~2 секунды).
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let url = try await audioService.stopRecording()
            let score = try await scorer.score(audioURL: url, targetSound: card.targetSound)
            guard !Task.isCancelled else { return }

            guard score.isScored else {
                // Звук вне поддержанных групп или модель недоступна — нейтрально.
                Self.logger.info("WOTD: '\(self.card.word, privacy: .public)' notScored — tryAgain")
                phase = .tryAgain
                return
            }

            let stars = Self.stars(for: score.value)
            phase = .scored(stars)
            Self.logger.info("WOTD: '\(self.card.word, privacy: .public)' score=\(score.value) → ★\(stars)")

            // F1-016 — фиксируем реальный исход произнесённого слова в FSRS-лестнице.
            // correct = ★≥2 (реальная оценка скорера, не хардкод). itemId — слово,
            // sound — целевой звук слова. Персистит планировщик (per-child UserDefaults).
            await adaptivePlanner?.recordItemOutcome(
                childId: childId,
                itemId: card.word,
                sound: card.targetSound,
                correct: stars >= Self.passStars
            )
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.warning("WOTD: запись/скоринг упали (\(error.localizedDescription)) — tryAgain")
            phase = .tryAgain
        }
    }

    /// Маппинг score [0;1] → звёзды [0;3] по тем же порогам, что в основном контуре.
    private static func stars(for value: Double) -> Int {
        switch value {
        case 0.85...:      return 3
        case 0.65..<0.85:  return 2
        case 0.40..<0.65:  return 1
        default:           return 0
        }
    }
}
