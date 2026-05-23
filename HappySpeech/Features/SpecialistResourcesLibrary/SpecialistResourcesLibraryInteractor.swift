import Foundation
import OSLog

// MARK: - SpecialistResourcesLibraryInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SpecialistResourcesLibraryInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistResourcesLibrary"
    )

    let specialistId: String
    var state: SpecialistResourcesLibraryModels.ViewState

    init(specialistId: String) {
        self.specialistId = specialistId
        self.state = .initial
    }

    func setFilter(_ kind: SpecialistResourcesLibraryModels.ResourceKind) {
        state.filter = kind
        Self.logger.info("setFilter \(kind.rawValue, privacy: .public)")
    }
}
