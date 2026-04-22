import Foundation
import OSLog

// MARK: - HSLogger

/// Centralised logger wrapping OSLog. Use `HSLogger` everywhere instead of `print`.
/// Each subsystem/category combination maps to a distinct log channel visible in Console.app.
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
