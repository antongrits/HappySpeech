import Foundation
import OSLog

// MARK: - KidGameScoreStore

/// Локальное персистентное хранилище лучших результатов («звёзд») детских
/// мини-игр, привязанное к паре (игра, ребёнок).
///
/// Хранит рекорд звёзд и счётчик завершённых раундов в `UserDefaults`, поэтому
/// данные переживают перезапуск приложения и разделены между разными детьми.
/// Это локальный игровой прогресс ребёнка (награды/звёзды); методический
/// прогресс по звукам пишется отдельно в `AdaptivePlannerService` (SM-2).
///
/// Чистая ценностная обёртка над `UserDefaults` — безопасно создавать на лету
/// в Interactor'е для каждой игры.
struct KidGameScoreStore {

    private let defaults: UserDefaults
    private let gameKey: String
    private let childId: String

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "KidGameScoreStore"
    )

    /// - Parameters:
    ///   - gameKey: стабильный идентификатор игры («animalBingo», «audioMemory» …).
    ///   - childId: идентификатор ребёнка; при пустом значении хранилище становится
    ///     no-op (Preview / тесты без профиля).
    init(defaults: UserDefaults = .standard, gameKey: String, childId: String) {
        self.defaults = defaults
        self.gameKey = gameKey
        self.childId = childId
    }

    private var bestStarsKey: String { "kidGame.\(gameKey).\(childId).bestStars" }
    private var roundsKey: String { "kidGame.\(gameKey).\(childId).rounds" }

    /// Текущий рекорд звёзд (0, если не играли или нет childId).
    var bestStars: Int {
        guard !childId.isEmpty else { return 0 }
        return defaults.integer(forKey: bestStarsKey)
    }

    /// Сколько раз игра была доведена до конца.
    var completedRounds: Int {
        guard !childId.isEmpty else { return 0 }
        return defaults.integer(forKey: roundsKey)
    }

    /// Записывает результат завершённой игры. Рекорд звёзд обновляется только
    /// вверх, счётчик раундов всегда инкрементируется. Возвращает `true`, если
    /// установлен новый рекорд.
    @discardableResult
    func recordCompletion(stars: Int) -> Bool {
        guard !childId.isEmpty else { return false }
        let clamped = max(0, min(stars, 3))
        defaults.set(completedRounds + 1, forKey: roundsKey)
        if clamped > bestStars {
            defaults.set(clamped, forKey: bestStarsKey)
            Self.logger.info("\(gameKey, privacy: .public) new best \(clamped, privacy: .public)★")
            return true
        }
        return false
    }
}
