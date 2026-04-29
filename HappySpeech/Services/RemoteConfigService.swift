import FirebaseRemoteConfig
import Foundation
import OSLog
import Observation

// MARK: - Protocol

/// Provides feature flags and runtime configuration from Firebase Remote Config.
/// fetch() + activate() should be called once at app launch (after FirebaseApp.configure()).
/// All properties return bundled defaults until the first successful fetch + activate.
public protocol RemoteConfigService: AnyObject, Sendable {
    // Feature flags
    var featureSeasonalEventsEnabled: Bool { get }
    var featureVoiceCloneEnabled: Bool { get }
    var featureBodyTrackingEnabled: Bool { get }
    var featureRealtimeLipsyncEnabled: Bool { get }

    // Content config
    var lyalyaVoiceDefault: String { get }
    var dailyReminderTime: String { get }

    // UI flags
    var homeShowStreakCelebration: Bool { get }
    var parentDashboardShowMLInsights: Bool { get }

    func fetch() async throws
    func activate() async throws -> Bool
}

// MARK: - Keys

private enum RCKey {
    static let featureSeasonalEvents = "feature_seasonal_events_enabled"
    static let featureVoiceClone = "feature_voice_clone_enabled"
    static let featureBodyTracking = "feature_body_tracking_enabled"
    static let featureRealtimeLipsync = "feature_realtime_lipsync_enabled"
    static let lyalyaVoiceDefault = "lyalya_voice_default"
    static let dailyReminderTime = "daily_reminder_time"
    static let homeShowStreakCelebration = "home_show_streak_celebration"
    static let parentDashboardShowMLInsights = "parent_dashboard_show_ml_insights"
}

// MARK: - Live Implementation

/// Protocol-based DI wrapper around FirebaseRemoteConfig.
/// @Observable for SwiftUI bindings — property reads are main-actor-safe.
@Observable
public final class LiveRemoteConfigService: RemoteConfigService, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "RemoteConfig")
    private let config: RemoteConfig

    // Bundled defaults (used before first successful fetch + activate)
    // nonisolated(unsafe) required for Swift 6 strict concurrency — [String: NSObject] is not Sendable.
    // The dictionary is write-once at type definition, so there is no actual data race.
    nonisolated(unsafe) private static let defaults: [String: NSObject] = [
        RCKey.featureSeasonalEvents:      true as NSNumber,
        RCKey.featureVoiceClone:          false as NSNumber,
        RCKey.featureBodyTracking:        false as NSNumber,
        RCKey.featureRealtimeLipsync:     false as NSNumber,
        RCKey.lyalyaVoiceDefault:         "tuned" as NSString,
        RCKey.dailyReminderTime:          "17:00" as NSString,
        RCKey.homeShowStreakCelebration:   true as NSNumber,
        RCKey.parentDashboardShowMLInsights: true as NSNumber,
    ]

    public init(minimumFetchInterval: TimeInterval = 3600) {
        config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval
        config.configSettings = settings
        config.setDefaults(Self.defaults)
    }

    // MARK: - Feature flags

    public var featureSeasonalEventsEnabled: Bool {
        config[RCKey.featureSeasonalEvents].boolValue
    }

    public var featureVoiceCloneEnabled: Bool {
        config[RCKey.featureVoiceClone].boolValue
    }

    public var featureBodyTrackingEnabled: Bool {
        config[RCKey.featureBodyTracking].boolValue
    }

    public var featureRealtimeLipsyncEnabled: Bool {
        config[RCKey.featureRealtimeLipsync].boolValue
    }

    // MARK: - Content config

    public var lyalyaVoiceDefault: String {
        config[RCKey.lyalyaVoiceDefault].stringValue ?? "tuned"
    }

    public var dailyReminderTime: String {
        config[RCKey.dailyReminderTime].stringValue ?? "17:00"
    }

    // MARK: - UI flags

    public var homeShowStreakCelebration: Bool {
        config[RCKey.homeShowStreakCelebration].boolValue
    }

    public var parentDashboardShowMLInsights: Bool {
        config[RCKey.parentDashboardShowMLInsights].boolValue
    }

    // MARK: - Lifecycle

    /// Fetches remote values. Respects minimumFetchInterval (no-op if called too soon).
    public func fetch() async throws {
        do {
            let status = try await config.fetch()
            logger.info("RemoteConfig fetch status: \(String(describing: status.rawValue))")
        } catch {
            logger.error("RemoteConfig fetch failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Activates fetched values. Returns true if new values were activated.
    public func activate() async throws -> Bool {
        let activated = try await config.activate()
        logger.info("RemoteConfig activate: \(activated)")
        return activated
    }
}

// MARK: - Mock

/// Preview / test implementation with overridable property values.
public final class MockRemoteConfigService: RemoteConfigService, @unchecked Sendable {
    public var featureSeasonalEventsEnabled: Bool = true
    public var featureVoiceCloneEnabled: Bool = false
    public var featureBodyTrackingEnabled: Bool = false
    public var featureRealtimeLipsyncEnabled: Bool = false
    public var lyalyaVoiceDefault: String = "tuned"
    public var dailyReminderTime: String = "17:00"
    public var homeShowStreakCelebration: Bool = true
    public var parentDashboardShowMLInsights: Bool = true

    public init() {}
    public func fetch() async throws {}
    public func activate() async throws -> Bool { false }
}
