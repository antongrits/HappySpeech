import Foundation
import OSLog

// MARK: - AnimalSoundsBingoInteractor

/// Бизнес-логика игры «Звуковое бинго».
///
/// Поле собирается из звукоподражаний под рабочие звуки ребёнка
/// (`AnimalSoundsBingoContent` через `ChildRepository`). «Диктор» называет
/// карточку, ребёнок её ищет: верная отметка фиксируется в интервальном
/// планировщике повторов, по завершении — итоговый SM-2 результат и рекорд
/// звёзд (`KidGameScoreStore`). Без репозитория (Preview/тесты) экран работает
/// на стартовом наборе.
@MainActor
@Observable
final class AnimalSoundsBingoInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AnimalSoundsBingo"
    )

    let childId: String
    var state: AnimalSoundsBingoModels.ViewState = .empty

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
        self.scoreStore = KidGameScoreStore(gameKey: "animalBingo", childId: childId)
    }

    /// Собирает поле под рабочие звуки ребёнка.
    func load() async {
        var targets: [String] = []
        if let childRepository, !childId.isEmpty {
            do {
                targets = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        state.cells = AnimalSoundsBingoContent.cells(forTargetSounds: targets)
        state.calledOutId = nil
        state.correctMarks = 0
        state.wrongMarks = 0
        state.bestStars = scoreStore.bestStars
        state.isLoaded = true
        Self.logger.info("loaded \(self.state.cells.count, privacy: .public) cells")
    }

    /// «Диктор» называет случайную ещё не отмеченную клетку.
    func callRandom() {
        let unmarked = state.cells.filter { !$0.isMarked }
        guard let next = unmarked.randomElement() else { return }
        state.calledOutId = next.id
        Self.logger.info("call \(next.label, privacy: .public)")
    }

    /// Текущая названная клетка (для озвучки во View).
    var calledCell: AnimalSoundsBingoModels.Cell? {
        guard let id = state.calledOutId else { return nil }
        return state.cells.first { $0.id == id }
    }

    func toggle(_ id: UUID) {
        guard let idx = state.cells.firstIndex(where: { $0.id == id }) else { return }
        let wasCalled = (state.calledOutId == id)
        let nowMarked = !state.cells[idx].isMarked
        state.cells[idx].isMarked.toggle()

        if let calledId = state.calledOutId {
            // Идёт активный вызов: оцениваем попадание по вызванной клетке.
            if id == calledId, nowMarked {
                state.correctMarks += 1
                recordOutcome(cell: state.cells[idx], correct: true)
            } else if id != calledId, nowMarked {
                state.wrongMarks += 1
                if let called = state.cells.first(where: { $0.id == calledId }) {
                    recordOutcome(cell: called, correct: false)
                }
            }
        }

        Self.logger.info("toggle \(self.state.cells[idx].label, privacy: .public)")
        if wasCalled {
            state.calledOutId = nil
        }
        if state.isBingo {
            finish()
        }
    }

    func reset() {
        state.cells = state.cells.map {
            var cell = $0
            cell.isMarked = false
            return cell
        }
        state.calledOutId = nil
        state.correctMarks = 0
        state.wrongMarks = 0
    }

    // MARK: - Persistence

    private func recordOutcome(cell: AnimalSoundsBingoModels.Cell, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "bingo-\(cell.soundFamily)-\(cell.label)",
                sound: cell.soundFamily,
                correct: correct
            )
        }
    }

    private func finish() {
        let stars = state.stars
        if scoreStore.recordCompletion(stars: stars) {
            state.bestStars = stars
        }
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let quality = SM2Quality.fromSuccessRate(state.accuracy)
        let sound = state.cells.first?.soundFamily ?? "С"
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
