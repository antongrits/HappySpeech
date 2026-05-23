import Foundation
import OSLog

// MARK: - EveningReflectionInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class EveningReflectionInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "EveningReflection"
    )

    let childId: String
    var entry: EveningReflectionModels.Entry = .init()
    var history: [EveningReflectionModels.Entry] = []

    init(childId: String) {
        self.childId = childId
    }

    func submit() {
        guard entry.mood != nil else { return }
        var saved = entry
        saved.savedAt = Date()
        history.insert(saved, at: 0)
        Self.logger.info("Saved evening reflection for \(self.childId, privacy: .private)")
        entry = .init()
    }
}
