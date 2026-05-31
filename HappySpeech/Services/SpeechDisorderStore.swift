import Foundation
import OSLog

// MARK: - SpeechDisorderStore (F1-021)

/// Хранилище выбранного типа речевого нарушения для ребёнка.
///
/// ### Почему UserDefaults, а не Realm
/// Профиль нарушения — конфигурационный признак планировщика, а не часть
/// синхронизируемого прогресса. Добавление поля в Realm-модель `ChildProfile`
/// потребовало бы bump `RealmSchemaVersion` (13 → 14) + правки DTO, репозитория,
/// sync-snapshot'ов и маппинга — большой blast radius ради одного enum.
/// Проект уже хранит адаптивную конфигурацию вне Realm (`AdaptivePlannerSeed`),
/// поэтому профиль нарушения хранится тем же способом: per-child ключ в
/// `UserDefaults`, что делает его multi-child-safe и не трогает миграции.
///
/// `LiveAdaptivePlannerService` читает значение при построении дневного маршрута;
/// `ProfileEditor` и онбординг — пишут.
public enum SpeechDisorderStore {

    private static let keyPrefix = "speech.disorder."

    private static func key(for childId: String) -> String {
        keyPrefix + childId
    }

    /// Сохраняет тип нарушения для конкретного ребёнка.
    public static func save(
        _ disorder: SpeechDisorder,
        childId: String,
        defaults: UserDefaults = .standard
    ) {
        guard !childId.isEmpty else { return }
        defaults.set(disorder.rawValue, forKey: key(for: childId))
        HSLogger.planner.info(
            "SpeechDisorder saved childId=\(childId, privacy: .private) disorder=\(disorder.rawValue, privacy: .public)"
        )
    }

    /// Возвращает тип нарушения ребёнка; при отсутствии — `.default` (дислалия).
    public static func load(
        childId: String,
        defaults: UserDefaults = .standard
    ) -> SpeechDisorder {
        guard !childId.isEmpty,
              let raw = defaults.string(forKey: key(for: childId)),
              let disorder = SpeechDisorder(rawValue: raw)
        else {
            return .default
        }
        return disorder
    }

    /// Удаляет сохранённое значение (например, при удалении профиля).
    public static func clear(childId: String, defaults: UserDefaults = .standard) {
        guard !childId.isEmpty else { return }
        defaults.removeObject(forKey: key(for: childId))
    }
}
