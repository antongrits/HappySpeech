import Foundation
import OSLog

// MARK: - MusicalSoundDrumsInteractor

/// Бизнес-логика логоритмической игры «Звуковые барабаны».
///
/// Рисунок собирается из слогов рабочего звука ребёнка
/// (`MusicalSoundDrumsContent` через `ChildRepository`). Ребёнок повторяет
/// рисунок, нажимая барабаны по громкости слогов; каждый удар сверяется с
/// ожидаемым. По завершении раунда фиксируется outcome в планировщике, по
/// окончании игры — итоговый SM-2 результат и рекорд звёзд.
@MainActor
@Observable
final class MusicalSoundDrumsInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MusicalSoundDrums"
    )

    /// Сколько раундов в одной игре.
    static let totalRounds = 4

    let childId: String
    var state: MusicalSoundDrumsModels.ViewState = .initial

    private let childRepository: (any ChildRepository)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let scoreStore: KidGameScoreStore

    init(
        childId: String,
        childRepository: (any ChildRepository)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.childRepository = childRepository
        self.adaptivePlanner = adaptivePlanner
        self.scoreStore = KidGameScoreStore(gameKey: "musicalDrums", childId: childId)
    }

    /// Загружает рабочий звук и собирает первый рисунок.
    func load() async {
        var sound = "С"
        if let childRepository, !childId.isEmpty {
            do {
                let targets = try await childRepository.fetch(id: childId).targetSounds
                if let first = targets.first { sound = first }
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        var fresh = MusicalSoundDrumsModels.ViewState.initial
        fresh.sound = sound
        fresh.pattern = MusicalSoundDrumsContent.pattern(
            for: sound,
            length: MusicalSoundDrumsContent.length(forRound: 0)
        )
        fresh.bestStars = scoreStore.bestStars
        state = fresh
        Self.logger.info("loaded sound=\(sound, privacy: .public)")
    }

    /// Текущий ожидаемый слог рисунка (для подсветки), либо nil если рисунок повторён.
    var expectedSyllable: MusicalSoundDrumsModels.Syllable? {
        guard state.progressIndex < state.pattern.count else { return nil }
        return state.pattern[state.progressIndex]
    }

    var isGameComplete: Bool {
        state.roundsPlayed >= Self.totalRounds
    }

    /// Удар по барабану: сверяется с ожидаемым слогом рисунка.
    func tap(_ drumId: MusicalSoundDrumsModels.DrumId) {
        guard state.isLoaded, !state.roundComplete, !isGameComplete else { return }
        guard let expected = expectedSyllable else { return }

        state.lastDrumId = drumId
        state.totalTaps += 1
        let hit = (drumId == expected.drum)
        if hit {
            state.correctTaps += 1
            state.progressIndex += 1
            // Логоритмика: на верный удар реально звучит слог рисунка голосом
            // Ляли (`LessonVoiceWorker`). Громкий слог (high) — нормальный темп,
            // тихий (low) — чуть медленнее: ритм слышен, не только тактилен.
            playBeat(expected)
        } else {
            // Промах не блокирует игру: остаёмся на том же слоге (errorless).
            Self.logger.info("miss expected=\(expected.drum.rawValue, privacy: .public)")
        }

        if state.progressIndex >= state.pattern.count {
            completeRound()
        }
    }

    /// Озвучивает слог удара голосом Ляли. Темп зависит от громкости слога.
    private func playBeat(_ syllable: MusicalSoundDrumsModels.Syllable) {
        let rate: Float
        switch syllable.drum {
        case .high: rate = 1.0
        case .mid:  rate = 0.92
        case .low:  rate = 0.85
        }
        Task { @MainActor in
            await LessonVoiceWorker.shared.speak(syllable.text, lessonType: "musical_drums", rate: rate)
        }
    }

    /// Завершить текущий рисунок и перейти к следующему раунду.
    private func completeRound() {
        state.roundComplete = true
        state.roundsPlayed += 1
        // Точность раунда учитывается итогово через accuracy (correctTaps /
        // totalTaps); отдельный счётчик «удачных раундов» не нужен.
        recordOutcome(correct: true)

        if isGameComplete {
            finishGame()
        }
    }

    /// Перейти к следующему рисунку (вызывается из View после показа «повторено»).
    func nextRound() {
        guard !isGameComplete else { return }
        let length = MusicalSoundDrumsContent.length(forRound: state.roundsPlayed)
        state.pattern = MusicalSoundDrumsContent.pattern(for: state.sound, length: length)
        state.progressIndex = 0
        state.roundComplete = false
        state.lastDrumId = nil
    }

    /// Полный перезапуск игры с тем же звуком.
    func reset() {
        let sound = state.sound
        let best = state.bestStars
        var fresh = MusicalSoundDrumsModels.ViewState.initial
        fresh.sound = sound
        fresh.pattern = MusicalSoundDrumsContent.pattern(
            for: sound,
            length: MusicalSoundDrumsContent.length(forRound: 0)
        )
        fresh.bestStars = best
        state = fresh
    }

    // MARK: - Persistence

    private func recordOutcome(correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = state.sound
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "drums-\(sound)-r\(self.state.roundsPlayed)",
                sound: sound,
                correct: correct
            )
        }
    }

    private func finishGame() {
        let starsEarned = state.stars
        if scoreStore.recordCompletion(stars: starsEarned) {
            state.bestStars = starsEarned
        }
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let quality = SM2Quality.fromSuccessRate(state.accuracy)
        let sound = state.sound
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
