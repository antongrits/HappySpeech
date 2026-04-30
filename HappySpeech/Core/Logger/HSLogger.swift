import Foundation
import OSLog

// MARK: - HSLogger

/// Централизованная система логирования HappySpeech на базе OSLog.
///
/// `HSLogger` — единственный разрешённый способ логирования в проекте.
/// Вызов стандартного вывода запрещён правилами кода и SwiftLint (custom rule `no_print`).
///
/// Каждая категория маппируется на отдельный канал в Console.app —
/// фильтрация по категории даёт мгновенный контекст при дебаггинге.
///
/// Subsystem автоматически берётся из `Bundle.main.bundleIdentifier`
/// (обычно `ru.happyspeech.app`).
///
/// ## Пример
/// ```swift
/// // Информационное сообщение
/// HSLogger.audio.info("Запись начата, format: \(format)")
///
/// // Ошибка с деталями
/// HSLogger.ml.error("PronunciationScorer не загружен: \(error.localizedDescription)")
///
/// // Debug (не попадает в release build)
/// HSLogger.realm.debug("Realm открыт: \(filePath)")
/// ```
///
/// ## See Also
/// - ``AppError``
/// - ``RealmActor``
public enum HSLogger {

    // MARK: - Subsystems

    private static let subsystem = Bundle.main.bundleIdentifier ?? "ru.happyspeech.app"

    // MARK: - Categories

    public static let app        = Logger(subsystem: subsystem, category: "App")
    public static let auth       = Logger(subsystem: subsystem, category: "Auth")
    public static let audio      = Logger(subsystem: subsystem, category: "Audio")
    public static let asr        = Logger(subsystem: subsystem, category: "ASR")
    public static let ar         = Logger(subsystem: subsystem, category: "AR")
    public static let content    = Logger(subsystem: subsystem, category: "Content")
    public static let sync       = Logger(subsystem: subsystem, category: "Sync")
    public static let realm      = Logger(subsystem: subsystem, category: "Realm")
    public static let ml         = Logger(subsystem: subsystem, category: "ML")
    public static let llm        = Logger(subsystem: subsystem, category: "LLM")
    public static let analytics  = Logger(subsystem: subsystem, category: "Analytics")
    public static let planner    = Logger(subsystem: subsystem, category: "Planner")
    public static let rewards    = Logger(subsystem: subsystem, category: "Rewards")
    public static let network    = Logger(subsystem: subsystem, category: "Network")
    public static let ui         = Logger(subsystem: subsystem, category: "UI")
    public static let navigation = Logger(subsystem: subsystem, category: "Navigation")
}
