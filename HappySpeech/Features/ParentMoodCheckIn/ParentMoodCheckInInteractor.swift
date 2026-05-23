import Foundation
import OSLog

// MARK: - ParentMoodCheckInInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ParentMoodCheckInInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentMoodCheckIn"
    )

    var entry: ParentMoodCheckInModels.Entry = .init()
    var lastSavedAt: Date?

    func save() {
        guard let mood = entry.mood else { return }
        lastSavedAt = Date()
        Self.logger.info("Parent mood logged: \(mood.rawValue, privacy: .public)")
    }
}
