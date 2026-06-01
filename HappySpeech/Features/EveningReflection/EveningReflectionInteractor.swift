import Foundation
import OSLog

// MARK: - EveningReflectionInteractor

/// Бизнес-логика вечерней рефлексии.
///
/// История восстанавливается из `EveningReflectionStore` (per child) и
/// пополняется при сохранении записи — дневник переживает перезапуск. Без
/// `childId` (Preview/тесты) работает на in-memory истории.
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
    var isLoaded: Bool = false

    private let store: EveningReflectionStore

    init(
        childId: String,
        defaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.store = EveningReflectionStore(defaults: defaults, childId: childId)
    }

    /// Восстанавливает историю дневника.
    func load() {
        history = store.loadHistory()
        isLoaded = true
        Self.logger.info("loaded \(self.history.count, privacy: .public) entries")
    }

    func submit() {
        guard entry.mood != nil else { return }
        var saved = entry
        saved.savedAt = Date()
        history = store.append(saved)
        Self.logger.info("saved evening reflection for \(self.childId, privacy: .private)")
        entry = .init()
    }
}
