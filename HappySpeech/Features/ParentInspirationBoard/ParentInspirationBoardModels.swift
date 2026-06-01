import Foundation

// MARK: - ParentInspirationBoardModels

/// Модели «Доски вдохновения» для родителей.
///
/// Цитаты берутся из `ParentInspirationBoardContent`, избранное персистится
/// через `ParentInspirationBoardStore`.
enum ParentInspirationBoardModels {

    struct Quote: Identifiable, Hashable {
        let id: String
        let text: String
        let author: String
        let role: String
        var isFavorite: Bool = false
    }

    struct ViewState: Equatable {
        var quotes: [Quote]
        var currentIndex: Int
        /// Показывать только избранное.
        var favoritesOnly: Bool = false

        /// Цитаты с учётом фильтра «только избранное».
        var visibleQuotes: [Quote] {
            favoritesOnly ? quotes.filter(\.isFavorite) : quotes
        }

        var current: Quote? {
            let list = visibleQuotes
            return list.indices.contains(currentIndex) ? list[currentIndex] : nil
        }

        var favoritesCount: Int { quotes.filter(\.isFavorite).count }

        static let initial = ViewState(
            quotes: ParentInspirationBoardContent.quotes,
            currentIndex: 0
        )
    }
}
