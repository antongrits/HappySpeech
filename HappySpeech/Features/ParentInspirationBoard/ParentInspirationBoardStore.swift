import Foundation

// MARK: - ParentInspirationBoardStore

/// Персистентное хранилище избранных цитат родителя.
///
/// Множество id избранных цитат хранится в `UserDefaults` и переживает
/// перезапуск. Избранное общее для родительского профиля (не привязано к
/// ребёнку).
struct ParentInspirationBoardStore {

    private let defaults: UserDefaults
    private static let key = "parentInspiration.favorites"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Множество id избранных цитат.
    func loadFavorites() -> Set<String> {
        let array = defaults.stringArray(forKey: Self.key) ?? []
        return Set(array)
    }

    /// Сохраняет множество id избранных.
    func save(favorites: Set<String>) {
        defaults.set(Array(favorites), forKey: Self.key)
    }
}
