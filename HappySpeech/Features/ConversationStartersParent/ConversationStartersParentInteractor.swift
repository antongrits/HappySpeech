import Foundation
import OSLog

// MARK: - ConversationStartersParentInteractor

/// Бизнес-логика «Темы для разговора» (родитель).
///
/// Список вопросов — курируемый логопедический контент (`ConversationStartersContent`).
/// Избранные вопросы реально сохраняются в `UserDefaults` и переживают
/// перезапуск приложения; фильтр по категории — состояние экрана.
@MainActor
@Observable
final class ConversationStartersParentInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ConversationStartersParent"
    )

    var state: ConversationStartersParentModels.ViewState = .init(questions: [])

    private let defaults: UserDefaults
    private static let storageKey = "conversationStarters.favorites"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Загружает вопросы из контента и помечает избранные по сохранённым id.
    func load() {
        let favorites = loadFavorites()
        state.questions = ConversationStartersContent.all.map { item in
            ConversationStartersParentModels.Question(
                id: item.id,
                text: item.text,
                category: item.category,
                isFavorite: favorites.contains(item.id)
            )
        }
        Self.logger.info("loaded \(self.state.questions.count, privacy: .public) questions, \(favorites.count, privacy: .public) favorites")
    }

    func toggleFavorite(_ id: String) {
        guard let idx = state.questions.firstIndex(where: { $0.id == id }) else { return }
        state.questions[idx].isFavorite.toggle()
        persistFavorites()
        Self.logger.info("toggleFavorite \(id, privacy: .public) → \(self.state.questions[idx].isFavorite)")
    }

    // MARK: - Persistence

    private func loadFavorites() -> Set<String> {
        let raw = defaults.array(forKey: Self.storageKey) as? [String] ?? []
        return Set(raw)
    }

    private func persistFavorites() {
        let favorites = state.questions.filter(\.isFavorite).map(\.id)
        defaults.set(favorites, forKey: Self.storageKey)
    }
}
