import Foundation
import OSLog

// MARK: - ColorAndSoundInteractor

/// Бизнес-логика игры «Цвет и звук» (фонематическое восприятие).
///
/// Раунды строятся под рабочие звуки ребёнка (`ColorAndSoundContent` через
/// `ChildRepository`). Ребёнок отмечает слова целевого звука среди отвлекающих;
/// каждый выбор фиксируется в интервальном планировщике, по завершении игры —
/// итоговый SM-2 результат и рекорд звёзд. Без репозитория (Preview/тесты) —
/// стартовый набор.
@MainActor
@Observable
final class ColorAndSoundInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ColorAndSound"
    )

    let childId: String
    var state: ColorAndSoundModels.ViewState = .initial

    private var rounds: [ColorAndSoundContent.Round] = []

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
        self.scoreStore = KidGameScoreStore(gameKey: "colorAndSound", childId: childId)
    }

    /// Загружает рабочие звуки и собирает раунды.
    func load() async {
        var targets: [String] = []
        if let childRepository, !childId.isEmpty {
            do {
                targets = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        rounds = ColorAndSoundContent.rounds(forTargetSounds: targets, count: 3)
        var fresh = ColorAndSoundModels.ViewState.empty
        fresh.totalRounds = rounds.count
        fresh.bestStars = scoreStore.bestStars
        fresh.isLoaded = true
        if let first = rounds.first { fresh.apply(round: first) }
        state = fresh
        Self.logger.info("loaded \(self.rounds.count, privacy: .public) rounds")
    }

    /// Тап по карточке-слову: верно, если слово принадлежит целевому звуку.
    func toggle(_ id: String) {
        guard !state.roundComplete, !state.isGameComplete,
              let idx = state.cards.firstIndex(where: { $0.id == id }),
              !state.cards[idx].isSelected else { return }

        state.cards[idx].isSelected = true
        let card = state.cards[idx]
        if card.belongs {
            state.correctPicks += 1
        } else {
            state.wrongPicks += 1
        }
        recordOutcome(card: card)
        Self.logger.info("toggle \(id, privacy: .public) belongs=\(card.belongs)")

        if state.foundCount >= state.targetCount {
            state.roundComplete = true
        }
    }

    /// Следующий раунд (после завершения текущего) или завершение игры.
    func next() {
        guard state.roundComplete, !state.isGameComplete else { return }
        state.roundIndex += 1
        if state.roundIndex < rounds.count {
            state.apply(round: rounds[state.roundIndex])
        }
        if state.isGameComplete {
            finishGame()
        }
    }

    // MARK: - Persistence

    private func recordOutcome(card: ColorAndSoundModels.WordCard) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = state.sound
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "colorSound-\(sound)-\(card.id)",
                sound: sound,
                correct: card.belongs
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
        let sound = rounds.first?.sound ?? "С"
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
