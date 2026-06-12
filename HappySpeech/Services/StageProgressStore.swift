import Foundation
import OSLog

// MARK: - StageProgressStore (P0-4)
//
// Персистентный прогресс ребёнка по 10-этапной лестнице коррекции звука
// (Фомичёва, см. wiki/concepts/correction-stages.md) — per-child-per-sound.
//
// ### Зачем
// До P0-4 каждая сессия писалась со стадией `wordInit` (хардкод в
// `SessionShellInteractor.saveSession`), а механизма продвижения ВПЕРЁД в
// проекте не было (только откат в `StageProgressionPlanner`). Лестница была
// заморожена: ребёнок навсегда оставался на `wordInit`. Этот стор хранит
// РЕАЛЬНУЮ текущую стадию ребёнка по каждому звуку и число подряд сессий,
// удовлетворивших методический критерий перехода. Источником стадии для
// сессии становится этот стор, а не константа.
//
// ### Хранение — вне Realm (UserDefaults), обоснование как у
// `ReviewScheduleStore` / `DifferentiationProgressStore` / `SpeechDisorderStore`:
// прогресс лестницы — производная адаптивная конфигурация планировщика, а не
// синхронизируемый Realm-прогресс. Добавление новой Realm-модели потребовало бы
// bump `RealmSchemaVersion` + правки DTO/репозиториев/sync-snapshot'ов (большой
// blast radius). Источник истины для агрегатов звука остаётся Realm/SM-2; этот
// стор хранит только id стадии и счётчик подряд квалифицирующих сессий.

// MARK: - StageProgress (value)

/// Снимок прогресса лестницы по одному звуку для ребёнка.
public struct StageProgress: Sendable, Equatable, Codable {
    /// Текущая рабочая стадия лестницы.
    public var stage: CorrectionStage
    /// Сколько сессий подряд выполнен критерий перехода текущей стадии.
    public var consecutiveQualifyingSessions: Int

    public init(
        stage: CorrectionStage = .isolated,
        consecutiveQualifyingSessions: Int = 0
    ) {
        self.stage = stage
        self.consecutiveQualifyingSessions = consecutiveQualifyingSessions
    }
}

// MARK: - StageProgressStoring

/// Абстракция хранилища прогресса лестницы (протокол → тестируемость, моки).
public protocol StageProgressStoring: Sendable {
    /// Текущий прогресс ребёнка по звуку. При отсутствии записи — стартовый
    /// (изолированный звук, 0 подряд квалифицирующих сессий).
    func progress(childId: String, sound: String) -> StageProgress

    /// Сохраняет прогресс ребёнка по звуку.
    func save(_ progress: StageProgress, childId: String, sound: String)

    /// Очищает прогресс по всем звукам ребёнка (например, при удалении профиля).
    func clear(childId: String)
}

public extension StageProgressStoring {
    /// Удобный доступ к текущей стадии без счётчика.
    func currentStage(childId: String, sound: String) -> CorrectionStage {
        progress(childId: childId, sound: sound).stage
    }
}

// MARK: - UserDefaultsStageProgressStore

/// UserDefaults-backed реализация. Multi-child-safe, offline, COPPA-нейтрально
/// (хранит только id стадии и счётчик сессий). Ключ —
/// `stageProgress.<childId>.<sound>`; перечень звуков ребёнка ведётся индексом
/// `stageProgressIndex.<childId>` для корректного `clear`.
public final class UserDefaultsStageProgressStore: StageProgressStoring, @unchecked Sendable {

    private let defaults: UserDefaults
    private let lock = NSLock()
    private static let keyPrefix = "stageProgress."
    private static let childIndexPrefix = "stageProgressIndex."

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StageProgressStore"
    )

    /// Инициализатор по имени suite (Sendable-параметр). `nil` → `.standard`.
    /// Используется и в проде, и в тестах (изолированный suite).
    public init(suiteName: String? = nil) {
        if let suiteName, let suite = UserDefaults(suiteName: suiteName) {
            self.defaults = suite
        } else {
            self.defaults = .standard
        }
    }

    private func key(childId: String, sound: String) -> String {
        "\(Self.keyPrefix)\(childId).\(sound)"
    }

    public func progress(childId: String, sound: String) -> StageProgress {
        guard !childId.isEmpty, !sound.isEmpty else { return StageProgress() }
        lock.lock()
        defer { lock.unlock() }
        guard
            let data = defaults.data(forKey: key(childId: childId, sound: sound)),
            let decoded = try? JSONDecoder().decode(StageProgress.self, from: data)
        else {
            return StageProgress()
        }
        return decoded
    }

    public func save(_ progress: StageProgress, childId: String, sound: String) {
        guard !childId.isEmpty, !sound.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(progress) else {
            Self.logger.error("Failed to encode stage progress")
            return
        }
        lock.lock()
        defer { lock.unlock() }
        defaults.set(data, forKey: key(childId: childId, sound: sound))
        registerSound(sound, forChild: childId)
        Self.logger.debug(
            """
            Saved stage progress sound=\(sound, privacy: .public) \
            stage=\(progress.stage.rawValue, privacy: .public) \
            streak=\(progress.consecutiveQualifyingSessions)
            """
        )
    }

    public func clear(childId: String) {
        guard !childId.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        let indexKey = Self.childIndexPrefix + childId
        let sounds = defaults.stringArray(forKey: indexKey) ?? []
        for sound in sounds {
            defaults.removeObject(forKey: key(childId: childId, sound: sound))
        }
        defaults.removeObject(forKey: indexKey)
    }

    /// Ведёт перечень звуков ребёнка, чтобы `clear` мог удалить все ключи.
    /// Вызывается под `lock`.
    private func registerSound(_ sound: String, forChild childId: String) {
        let indexKey = Self.childIndexPrefix + childId
        var sounds = defaults.stringArray(forKey: indexKey) ?? []
        guard !sounds.contains(sound) else { return }
        sounds.append(sound)
        defaults.set(sounds, forKey: indexKey)
    }
}
