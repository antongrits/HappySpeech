import Foundation
import OSLog

// MARK: - SoundExplorerMapInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SoundExplorerMapInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundExplorerMap"
    )

    let childId: String
    var filter: SoundExplorerMapModels.MasteryFilter = .all
    var sounds: [SoundExplorerMapModels.SoundCell] = SoundExplorerMapModels.seedSounds

    init(childId: String) {
        self.childId = childId
    }

    var visible: [SoundExplorerMapModels.SoundCell] {
        sounds.filter { $0.matches(filter) }
    }

    func setFilter(_ value: SoundExplorerMapModels.MasteryFilter) {
        filter = value
        Self.logger.info("Filter = \(value.rawValue, privacy: .public)")
    }
}
