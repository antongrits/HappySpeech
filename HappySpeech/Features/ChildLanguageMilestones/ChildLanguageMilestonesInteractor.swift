import Foundation
import OSLog

// MARK: - ChildLanguageMilestonesInteractor

/// Родительский чек-лист речевых вех. Все отметки ставит родитель вручную —
/// они НЕ выводятся из данных. Отметки персистятся per-child в UserDefaults,
/// поэтому сохраняются между запусками (раньше терялись при закрытии).
@MainActor
@Observable
final class ChildLanguageMilestonesInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ChildLanguageMilestones"
    )

    var state: ChildLanguageMilestonesModels.ViewState

    private let childId: String
    private let defaults: UserDefaults

    private var storageKey: String { "languageMilestones.achieved.\(childId)" }

    init(childId: String = "", defaults: UserDefaults = .standard) {
        self.childId = childId
        self.defaults = defaults
        var initial = ChildLanguageMilestonesModels.ViewState.initial
        let achievedIds = Set(defaults.stringArray(forKey: "languageMilestones.achieved.\(childId)") ?? [])
        if !achievedIds.isEmpty {
            initial.items = initial.items.map { item in
                var copy = item
                copy.isAchieved = achievedIds.contains(item.id)
                return copy
            }
        }
        self.state = initial
    }

    func toggle(_ id: String) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].isAchieved.toggle()
        Self.logger.info("toggle \(id, privacy: .public) → \(self.state.items[idx].isAchieved)")
        persist()
    }

    private func persist() {
        let achievedIds = state.items.filter(\.isAchieved).map(\.id)
        defaults.set(achievedIds, forKey: storageKey)
    }
}
