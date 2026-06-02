import Foundation
import OSLog

// MARK: - ImitationLabInteractor

/// Бизнес-логика «Лаборатории подражания» (articulation-imitation).
///
/// Образцы отбираются под рабочие звуки ребёнка (`ImitationLabContent` через
/// `ChildRepository`). Цикл: послушать образец (реальный аудио-эталон через
/// `LessonVoiceWorker`) → повторить вслух → запись + оценка произношения
/// (`PronunciationScorerService` + `ASRService`). Каждая попытка фиксируется в
/// интервальном планировщике с реальным исходом, по завершении набора —
/// итоговый SM-2 результат по среднему баллу и рекорд звёзд. Нет входного
/// сигнала (отказ микрофона / тишина) → честный no-input без начисления звёзд.
/// Без репозитория (Preview/тесты) — стартовый набор.
@MainActor
@Observable
final class ImitationLabInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ImitationLab"
    )

    let childId: String
    var state: ImitationLabModels.ViewState = .empty

    /// Идёт запись голоса ребёнка по образцу с этим id (для UI-индикатора).
    var recordingSampleId: String?

    private let childRepository: (any ChildRepository)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let audioService: (any AudioService)?
    private let scorer: (any PronunciationScorerService)?
    private let scoreStore: KidGameScoreStore
    private var practiceTask: Task<Void, Never>?

    init(
        childId: String,
        childRepository: (any ChildRepository)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        audioService: (any AudioService)? = nil,
        scorer: (any PronunciationScorerService)? = nil
    ) {
        self.childId = childId
        self.childRepository = childRepository
        self.adaptivePlanner = adaptivePlanner
        self.audioService = audioService
        self.scorer = scorer
        self.scoreStore = KidGameScoreStore(gameKey: "imitationLab", childId: childId)
    }

    /// Собирает набор образцов под рабочие звуки ребёнка.
    func load() async {
        var targets: [String] = []
        if let childRepository, !childId.isEmpty {
            do {
                targets = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        state.samples = ImitationLabContent.samples(forTargetSounds: targets)
        state.currentSampleId = nil
        state.bestStars = scoreStore.bestStars
        state.isLoaded = true
        Self.logger.info("loaded \(self.state.samples.count, privacy: .public) samples")
    }

    /// Прослушать образец: реально воспроизводит аудио-эталон голосом Ляли
    /// (`LessonVoiceWorker` — семейная запись → m4a Ляли). Произносится сначала
    /// название образца, затем звукоподражание (модель артикуляции).
    func playSample(_ id: String) {
        guard let idx = state.samples.firstIndex(where: { $0.id == id }) else { return }
        state.samples[idx].isPlayed = true
        state.currentSampleId = id
        let sample = state.samples[idx]
        Self.logger.info("play sample \(id, privacy: .public)")
        Task { @MainActor in
            await LessonVoiceWorker.shared.speak(sample.name, lessonType: "imitation")
            await LessonVoiceWorker.shared.speak(sample.onomatopoeia, lessonType: "imitation")
        }
    }

    /// Порог «засчитано» — 60 из 100 (как в RepeatAfterModel/основном контуре).
    static let passThreshold: Float = 0.6

    /// Повторить образец вслух: РЕАЛЬНАЯ запись + оценка произношения
    /// (`PronunciationScorerService`). Никакого «всегда получилось»: исход
    /// определяется реальным баллом. Нет входного сигнала (отказ микрофона /
    /// тишина / звук вне поддержанных групп) → честный no-input без звёзд,
    /// образец остаётся доступным для повторной попытки.
    func practice(_ id: String) {
        guard let idx = state.samples.firstIndex(where: { $0.id == id }),
              !state.samples[idx].isPracticed,
              recordingSampleId == nil else { return }
        recordingSampleId = id
        let sample = state.samples[idx]
        practiceTask?.cancel()
        practiceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.recordAndScore(sample: sample)
            self.recordingSampleId = nil
        }
    }

    private func recordAndScore(sample: ImitationLabModels.SoundSample) async {
        guard let audioService, let scorer else {
            // Сервисы не инжектированы (Preview/неполная среда) — честный no-input.
            Self.logger.debug("imitation: audio/scorer недоступны — noInput")
            return
        }
        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            if !granted {
                Self.logger.info("imitation: микрофон не разрешён — noInput")
                return
            }
        }
        do {
            try await audioService.startRecording()
            // Короткая запись подражания (детский UX: ~2 секунды).
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let url = try await audioService.stopRecording()
            let score = try await scorer.score(audioURL: url, targetSound: sample.soundFamily)
            guard !Task.isCancelled else { return }
            guard score.isScored else {
                Self.logger.info("imitation: '\(sample.id, privacy: .public)' notScored — noInput")
                return
            }
            recordResult(id: sample.id, score: Float(score.value))
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.warning("imitation: запись/скоринг упали (\(error.localizedDescription, privacy: .public)) — noInput")
        }
    }

    /// Зафиксировать РЕАЛЬНЫЙ результат попытки (`score` ∈ `[0...1]`).
    /// Вызывается из `recordAndScore` после оценки `PronunciationScorerService`;
    /// также служит детерминированным seam для тестов (без живого микрофона).
    func recordResult(id: String, score: Float) {
        guard let idx = state.samples.firstIndex(where: { $0.id == id }),
              !state.samples[idx].isPracticed else { return }
        let clamped = max(0, min(score, 1))
        let passed = clamped >= Self.passThreshold
        state.samples[idx].isPracticed = true
        state.samples[idx].score = clamped
        state.samples[idx].didPass = passed
        let sample = state.samples[idx]
        recordOutcome(sample: sample, correct: passed)
        Self.logger.info("practiced \(id, privacy: .public) score=\(clamped) passed=\(passed)")
        if state.isComplete { finish() }
    }

    func reset() {
        practiceTask?.cancel()
        practiceTask = nil
        recordingSampleId = nil
        state.samples = state.samples.map {
            var sample = $0
            sample.isPlayed = false
            sample.isPracticed = false
            sample.score = nil
            sample.didPass = false
            return sample
        }
        state.currentSampleId = nil
    }

    // MARK: - Persistence

    private func recordOutcome(sample: ImitationLabModels.SoundSample, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "imitation-\(sample.id)",
                sound: sample.soundFamily,
                correct: correct
            )
        }
    }

    private func finish() {
        let starsEarned = state.stars
        if scoreStore.recordCompletion(stars: starsEarned) {
            state.bestStars = starsEarned
        }
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = state.samples.first?.soundFamily ?? "С"
        // SM-2 quality из РЕАЛЬНОГО среднего балла произношения (доля удачных),
        // а не фиксированный .perfect.
        let scored = state.samples.compactMap(\.score)
        let successRate = scored.isEmpty
            ? 0
            : Double(scored.reduce(0, +) / Float(scored.count))
        let quality = SM2Quality.fromSuccessRate(successRate)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await planner.recordSessionResult(
                    childId: self.childId,
                    soundTarget: sound,
                    qualityScore: quality
                )
            } catch {
                Self.logger.error("recordSession failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
