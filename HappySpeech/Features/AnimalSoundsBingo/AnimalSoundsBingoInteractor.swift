import Foundation
import OSLog

// MARK: - AnimalSoundsBingoInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class AnimalSoundsBingoInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AnimalSoundsBingo"
    )

    let childId: String
    var state: AnimalSoundsBingoModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    /// Эмулирует «диктора bingo» — рандомно выбирает unmarked клетку
    /// и помечает её как «названную». Ребёнок tap → mark.
    func callRandom() {
        let unmarked = state.cells.filter { !$0.isMarked }
        guard let next = unmarked.randomElement() else { return }
        state.calledOutId = next.id
        Self.logger.info("call \(next.label, privacy: .public)")
    }

    func toggle(_ id: UUID) {
        guard let idx = state.cells.firstIndex(where: { $0.id == id }) else { return }
        state.cells[idx].isMarked.toggle()
        Self.logger.info("toggle \(self.state.cells[idx].label, privacy: .public)")
        if state.calledOutId == id {
            state.calledOutId = nil
        }
    }

    func reset() {
        state = .initial
    }
}
