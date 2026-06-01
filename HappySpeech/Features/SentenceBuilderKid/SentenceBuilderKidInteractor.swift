import Foundation
import OSLog

// MARK: - SentenceBuilderKidInteractor

/// Бизнес-логика игры «Собери предложение».
///
/// Предложения подбираются под рабочий звук ребёнка
/// (`SentenceBuilderKidContent` через `ChildRepository`). Ребёнок собирает фразу
/// из перемешанных слов; верный/неверный порядок фиксируется в интервальном
/// планировщике, по завершении игры — итоговый SM-2 результат и рекорд звёзд.
/// Без репозитория (Preview/тесты) используется стартовый набор.
@MainActor
@Observable
final class SentenceBuilderKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SentenceBuilderKid"
    )

    let childId: String
    var state: SentenceBuilderKidModels.ViewState = .initial

    private var sentences: [SentenceBuilderKidContent.Sentence] = []
    private var scoredThisSentence = false

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
        self.scoreStore = KidGameScoreStore(gameKey: "sentenceBuilder", childId: childId)
    }

    /// Загружает рабочий звук и набор предложений.
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
        sentences = SentenceBuilderKidContent.sentences(for: sound, count: 4)
        var fresh = SentenceBuilderKidModels.ViewState(available: [], assembled: [], sound: sound)
        fresh.totalSentences = sentences.count
        fresh.bestStars = scoreStore.bestStars
        fresh.isLoaded = true
        if let first = sentences.first { fresh.load(sentence: first) }
        scoredThisSentence = false
        state = fresh
        Self.logger.info("loaded \(self.sentences.count, privacy: .public) sentences sound=\(sound, privacy: .public)")
    }

    func pickFromAvailable(_ chipId: UUID) {
        guard let idx = state.available.firstIndex(where: { $0.id == chipId }) else { return }
        let chip = state.available.remove(at: idx)
        state.assembled.append(chip)
        Self.logger.info("pick \(chip.text, privacy: .public)")
        evaluateIfFull()
    }

    func removeFromAssembled(_ chipId: UUID) {
        guard let idx = state.assembled.firstIndex(where: { $0.id == chipId }) else { return }
        let chip = state.assembled.remove(at: idx)
        state.available.append(chip)
        Self.logger.info("remove \(chip.text, privacy: .public)")
        scoredThisSentence = false
    }

    /// Когда фраза собрана — фиксируем результат один раз для этого предложения.
    private func evaluateIfFull() {
        guard state.isFull, !scoredThisSentence else { return }
        scoredThisSentence = true
        state.attempts += 1
        let correct = state.isCorrect
        if correct { state.solvedCount += 1 }
        recordOutcome(correct: correct)
    }

    /// Следующее предложение (после успешной сборки) или завершение игры.
    func next() {
        guard !state.isGameComplete else { return }
        state.sentenceIndex += 1
        scoredThisSentence = false
        if state.sentenceIndex < sentences.count {
            state.load(sentence: sentences[state.sentenceIndex])
        }
        if state.isGameComplete {
            finishGame()
        }
    }

    /// Сброс текущего предложения (перемешать заново).
    func reset() {
        guard state.sentenceIndex < sentences.count else { return }
        scoredThisSentence = false
        state.load(sentence: sentences[state.sentenceIndex])
    }

    // MARK: - Persistence

    private func recordOutcome(correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = state.sound
        let idx = state.sentenceIndex
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "sentence-\(sound)-\(idx)",
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
