import Foundation
import OSLog

// MARK: - DifferentiationProgressStore
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Прогресс лестницы дифференциации (СЛОГ → СЛОВО → ФРАЗА → ТЕКСТ) для пары
// и ребёнка. Хранит достигнутый уровень и число подряд успешных сессий на
// текущем уровне — это нужно для критериев перехода методиста (например
// 90% × 2 сессии на слоге; завершение пары 90% × 3 сессии на тексте).

/// Снимок прогресса по конкретной паре для ребёнка.
public struct DifferentiationProgress: Sendable, Equatable, Codable {
    /// Текущий рабочий уровень лестницы.
    public var level: DifferentiationLevel
    /// Сколько сессий подряд критерий уровня выполнен.
    public var consecutiveQualifyingSessions: Int
    /// Завершена ли вся пара (критерий этапа 14 на уровне ТЕКСТ).
    public var isPairCompleted: Bool

    public init(
        level: DifferentiationLevel = .syllable,
        consecutiveQualifyingSessions: Int = 0,
        isPairCompleted: Bool = false
    ) {
        self.level = level
        self.consecutiveQualifyingSessions = consecutiveQualifyingSessions
        self.isPairCompleted = isPairCompleted
    }
}

// MARK: - DifferentiationProgressStoring

/// Абстракция хранилища прогресса лестницы (протокол → тестируемость, моки).
@MainActor
public protocol DifferentiationProgressStoring: AnyObject {
    /// Возвращает прогресс ребёнка по паре; при отсутствии — начальный
    /// (первый доступный уровень пары).
    func progress(childId: String, pairId: String) -> DifferentiationProgress

    /// Сохраняет прогресс ребёнка по паре.
    func save(_ progress: DifferentiationProgress, childId: String, pairId: String)

    /// Очищает прогресс (например, при удалении профиля ребёнка).
    func clear(childId: String)
}

// MARK: - UserDefaultsDifferentiationProgressStore
//
// Прогресс лестницы — конфигурационный признак планировщика, а не часть
// синхронизируемого Realm-прогресса. По образцу `SpeechDisorderStore`
// (та же мотивация: не трогать Realm-миграции ради per-pair состояния)
// хранится per-child-per-pair ключом в `UserDefaults`. Multi-child-safe,
// offline, COPPA-нейтрально (хранится только id уровня и счётчик сессий).

@MainActor
public final class UserDefaultsDifferentiationProgressStore: DifferentiationProgressStoring {

    private let defaults: UserDefaults
    private static let keyPrefix = "soundTrafficLight.progress."
    private static let childIndexPrefix = "soundTrafficLight.progressIndex."

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.ProgressStore"
    )

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(childId: String, pairId: String) -> String {
        "\(Self.keyPrefix)\(childId).\(pairId)"
    }

    public func progress(childId: String, pairId: String) -> DifferentiationProgress {
        guard !childId.isEmpty, !pairId.isEmpty,
              let data = defaults.data(forKey: key(childId: childId, pairId: pairId)),
              let decoded = try? JSONDecoder().decode(DifferentiationProgress.self, from: data)
        else {
            // Стартовый уровень — первый доступный у пары (обычно слог);
            // если пара без слогов (legacy), вызывающий код подберёт слово.
            return DifferentiationProgress(level: .syllable)
        }
        return decoded
    }

    public func save(_ progress: DifferentiationProgress, childId: String, pairId: String) {
        guard !childId.isEmpty, !pairId.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(progress) else {
            Self.logger.error("Failed to encode differentiation progress")
            return
        }
        defaults.set(data, forKey: key(childId: childId, pairId: pairId))
        registerPair(pairId, forChild: childId)
        Self.logger.debug(
            "Saved differentiation progress pair=\(pairId, privacy: .public) level=\(progress.level.rawValue, privacy: .public)"
        )
    }

    public func clear(childId: String) {
        guard !childId.isEmpty else { return }
        let indexKey = Self.childIndexPrefix + childId
        let pairIds = defaults.stringArray(forKey: indexKey) ?? []
        for pairId in pairIds {
            defaults.removeObject(forKey: key(childId: childId, pairId: pairId))
        }
        defaults.removeObject(forKey: indexKey)
    }

    /// Ведёт перечень пар ребёнка, чтобы `clear` мог удалить все ключи.
    private func registerPair(_ pairId: String, forChild childId: String) {
        let indexKey = Self.childIndexPrefix + childId
        var pairIds = defaults.stringArray(forKey: indexKey) ?? []
        guard !pairIds.contains(pairId) else { return }
        pairIds.append(pairId)
        defaults.set(pairIds, forKey: indexKey)
    }
}
