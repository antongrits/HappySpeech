import Foundation
import OSLog

// MARK: - SpeechHomeworkPlannerInteractor

/// Недельный план домашней практики (рекомендованный шаблон). Отметки
/// «выполнено» реально персистятся в UserDefaults и сохраняются между
/// запусками (раньше терялись при закрытии экрана).
@MainActor
@Observable
final class SpeechHomeworkPlannerInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechHomeworkPlanner"
    )

    var items: [SpeechHomeworkPlannerModels.Item]

    var doneCount: Int { items.filter { $0.isDone }.count }
    var progress: Double { Double(doneCount) / Double(max(items.count, 1)) }

    private let defaults: UserDefaults
    private static let storageKey = "speechHomework.doneIds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let doneIds = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
        self.items = SpeechHomeworkPlannerModels.seed.map { item in
            var copy = item
            copy.isDone = doneIds.contains(item.id)
            return copy
        }
    }

    func toggle(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isDone.toggle()
        Self.logger.info("Toggle homework \(self.items[i].title, privacy: .public) → \(self.items[i].isDone)")
        persist()
    }

    private func persist() {
        let doneIds = items.filter(\.isDone).map(\.id)
        defaults.set(doneIds, forKey: Self.storageKey)
    }
}
