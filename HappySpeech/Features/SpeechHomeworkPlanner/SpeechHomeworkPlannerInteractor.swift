import Foundation
import OSLog

// MARK: - SpeechHomeworkPlannerInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SpeechHomeworkPlannerInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechHomeworkPlanner"
    )

    var items: [SpeechHomeworkPlannerModels.Item] = SpeechHomeworkPlannerModels.seed

    var doneCount: Int { items.filter { $0.isDone }.count }
    var progress: Double { Double(doneCount) / Double(max(items.count, 1)) }

    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isDone.toggle()
        Self.logger.info("Toggle homework \(self.items[i].title, privacy: .public) → \(self.items[i].isDone)")
    }
}
