import Foundation
import OSLog

// MARK: - ParentInspirationBoardInteractor

/// Бизнес-логика «Доски вдохновения».
///
/// Цитаты берутся из `ParentInspirationBoardContent`; избранное
/// восстанавливается из `ParentInspirationBoardStore` при старте и сохраняется
/// при каждом изменении (переживает перезапуск). Поддерживает фильтр «только
/// избранное».
@MainActor
@Observable
final class ParentInspirationBoardInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentInspirationBoard"
    )

    var state: ParentInspirationBoardModels.ViewState

    private let store: ParentInspirationBoardStore

    init(defaults: UserDefaults = .standard) {
        self.store = ParentInspirationBoardStore(defaults: defaults)
        var initial = ParentInspirationBoardModels.ViewState.initial
        let favorites = store.loadFavorites()
        initial.quotes = initial.quotes.map { quote in
            var copy = quote
            copy.isFavorite = favorites.contains(quote.id)
            return copy
        }
        self.state = initial
    }

    func next() {
        let count = state.visibleQuotes.count
        guard count > 0 else { return }
        state.currentIndex = (state.currentIndex + 1) % count
        Self.logger.info("next → index=\(self.state.currentIndex)")
    }

    func previous() {
        let count = state.visibleQuotes.count
        guard count > 0 else { return }
        state.currentIndex = (state.currentIndex - 1 + count) % count
        Self.logger.info("previous → index=\(self.state.currentIndex)")
    }

    func toggleFavorite() {
        guard let current = state.current,
              let idx = state.quotes.firstIndex(where: { $0.id == current.id })
        else { return }
        state.quotes[idx].isFavorite.toggle()
        persistFavorites()
        // Если включён фильтр и цитата ушла из избранного — не выходим за границы.
        if state.favoritesOnly && state.current == nil {
            state.currentIndex = max(0, state.visibleQuotes.count - 1)
        }
        Self.logger.info("toggleFavorite → \(self.state.quotes[idx].isFavorite)")
    }

    /// Переключает фильтр «только избранное» (сбрасывает индекс в начало).
    func toggleFavoritesFilter() {
        state.favoritesOnly.toggle()
        state.currentIndex = 0
        Self.logger.info("favoritesOnly → \(self.state.favoritesOnly)")
    }

    private func persistFavorites() {
        let ids = Set(state.quotes.filter(\.isFavorite).map(\.id))
        store.save(favorites: ids)
    }
}
