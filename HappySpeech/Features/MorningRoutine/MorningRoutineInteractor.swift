import Foundation
import OSLog

// MARK: - MorningRoutineInteractor

/// Бизнес-логика утренней рутины.
///
/// Состояние выполненных шагов восстанавливается из `MorningRoutineStore`
/// (per child + day) и сохраняется при каждом изменении — рутина переживает
/// перезапуск и сбрасывается на следующий день. Без `childId` (Preview/тесты)
/// работает на in-memory состоянии.
@MainActor
@Observable
final class MorningRoutineInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MorningRoutine"
    )

    let childId: String
    var state: MorningRoutineModels.ViewState

    private let store: MorningRoutineStore

    init(
        childId: String,
        defaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.store = MorningRoutineStore(defaults: defaults, childId: childId)
        self.state = .initial
    }

    /// Восстанавливает состояние дня из стора.
    func load() {
        let done = store.loadDoneSteps()
        state = MorningRoutineModels.ViewState.make(doneSteps: done)
        Self.logger.info("loaded \(done.count, privacy: .public) done steps")
    }

    func toggle(_ step: MorningRoutineModels.StepKind) {
        guard let index = state.steps.firstIndex(where: { $0.id == step }) else { return }
        state.steps[index].isDone.toggle()
        store.save(doneSteps: state.doneSet)
        Self.logger.info("toggle \(step.rawValue, privacy: .public) → \(self.state.steps[index].isDone)")
    }

    func reset() {
        state = MorningRoutineModels.ViewState.make(doneSteps: [])
        store.save(doneSteps: [])
    }
}
