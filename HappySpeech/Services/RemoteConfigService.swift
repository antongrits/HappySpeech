import FirebaseRemoteConfig
import Foundation
import Observation
import OSLog

// MARK: - Protocol

/// Провайдер feature flags и runtime конфигурации через Firebase Remote Config.
///
/// `RemoteConfigService` позволяет управлять функциональностью приложения без
/// обновления в App Store. Все свойства возвращают бандлированные дефолты до
/// первого успешного `fetch() + activate()` при запуске.
///
/// `fetch()` + `activate()` вызывается один раз при старте приложения (после
/// `FirebaseApp.configure()`). Кэш Remote Config — 12 часов.
///
/// `startRealtimeUpdates()` запускает подписку на серверные изменения флагов
/// через `addOnConfigUpdateListener` — автоматически активирует новые значения.
///
/// ## Пример
/// ```swift
/// let rc: RemoteConfigService = LiveRemoteConfigService()
/// try await rc.fetch()
/// _ = try await rc.activate()
/// rc.startRealtimeUpdates()
///
/// if rc.featureVoiceCloneEnabled {
///     // показать UI клонирования голоса
/// }
/// ```
///
/// ## See Also
/// - ``FCMService``
/// - ``ContentPackDownloadService``
public protocol RemoteConfigService: AnyObject, Sendable {
    // Feature flags
    var featureSeasonalEventsEnabled: Bool { get }
    var featureVoiceCloneEnabled: Bool { get }
    var featureBodyTrackingEnabled: Bool { get }
    var featureRealtimeLipsyncEnabled: Bool { get }
    var featureSpectrogramEnabled: Bool { get }
    var featureEmotionDetectionEnabled: Bool { get }
    var featureSpeakerVerificationEnabled: Bool { get }

    // Content config
    var lyalyaVoiceDefault: String { get }
    var dailyReminderTime: String { get }
    var weeklySummaryDay: String { get }

    // UI flags
    var homeShowStreakCelebration: Bool { get }
    var parentDashboardShowMLInsights: Bool { get }

    // Version management
    var minAppVersion: String { get }
    var forceUpdateMinVersion: String { get }

    func fetch() async throws
    func activate() async throws -> Bool

    /// Запускает realtime-подписку на изменения Remote Config.
    /// Новые значения применяются автоматически при получении обновления с сервера.
    /// Безопасно вызывать повторно — повторный вызов игнорируется.
    func startRealtimeUpdates()
}

// MARK: - Keys

private enum RCKey {
    static let featureSeasonalEvents          = "feature_seasonal_events_enabled"
    static let featureVoiceClone              = "feature_voice_clone_enabled"
    static let featureBodyTracking            = "feature_body_tracking_enabled"
    static let featureRealtimeLipsync         = "feature_realtime_lipsync_enabled"
    static let featureSpectrogram             = "feature_spectrogram_enabled"
    static let featureEmotionDetection        = "feature_emotion_detection_enabled"
    static let featureSpeakerVerification     = "feature_speaker_verification_enabled"
    static let lyalyaVoiceDefault             = "lyalya_voice_default"
    static let dailyReminderTime              = "daily_reminder_time"
    static let weeklySummaryDay               = "weekly_summary_day"
    static let homeShowStreakCelebration      = "home_show_streak_celebration"
    static let parentDashboardShowMLInsights  = "parent_dashboard_show_ml_insights"
    static let minAppVersion                  = "min_app_version"
    static let forceUpdateMinVersion          = "force_update_min_version"
}

// MARK: - Live Implementation

/// Protocol-based DI wrapper around FirebaseRemoteConfig.
/// @Observable for SwiftUI bindings — property reads are main-actor-safe.
@Observable
public final class LiveRemoteConfigService: RemoteConfigService, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "RemoteConfig")
    private let config: RemoteConfig
    private var realtimeListenerStarted = false

    // Bundled defaults (used before first successful fetch + activate)
    // nonisolated(unsafe) required for Swift 6 strict concurrency — [String: NSObject] is not Sendable.
    // The dictionary is write-once at type definition, so there is no actual data race.
    nonisolated(unsafe) private static let defaults: [String: NSObject] = [
        RCKey.featureSeasonalEvents:         true as NSNumber,
        RCKey.featureVoiceClone:             false as NSNumber,
        RCKey.featureBodyTracking:           true as NSNumber,
        RCKey.featureRealtimeLipsync:        false as NSNumber,
        RCKey.featureSpectrogram:            true as NSNumber,
        RCKey.featureEmotionDetection:       true as NSNumber,
        RCKey.featureSpeakerVerification:    true as NSNumber,
        RCKey.lyalyaVoiceDefault:            "tuned" as NSString,
        RCKey.dailyReminderTime:             "17:00" as NSString,
        RCKey.weeklySummaryDay:              "Monday" as NSString,
        RCKey.homeShowStreakCelebration:     true as NSNumber,
        RCKey.parentDashboardShowMLInsights: true as NSNumber,
        RCKey.minAppVersion:                 "1.0.0" as NSString,
        RCKey.forceUpdateMinVersion:         "1.0.0" as NSString
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

    public var featureSpectrogramEnabled: Bool {
        config[RCKey.featureSpectrogram].boolValue
    }

    public var featureEmotionDetectionEnabled: Bool {
        config[RCKey.featureEmotionDetection].boolValue
    }

    public var featureSpeakerVerificationEnabled: Bool {
        config[RCKey.featureSpeakerVerification].boolValue
    }

    // MARK: - Content config

    public var lyalyaVoiceDefault: String {
        config[RCKey.lyalyaVoiceDefault].stringValue ?? "tuned"
    }

    public var dailyReminderTime: String {
        config[RCKey.dailyReminderTime].stringValue ?? "17:00"
    }

    public var weeklySummaryDay: String {
        config[RCKey.weeklySummaryDay].stringValue ?? "Monday"
    }

    // MARK: - UI flags

    public var homeShowStreakCelebration: Bool {
        config[RCKey.homeShowStreakCelebration].boolValue
    }

    public var parentDashboardShowMLInsights: Bool {
        config[RCKey.parentDashboardShowMLInsights].boolValue
    }

    // MARK: - Version management

    public var minAppVersion: String {
        config[RCKey.minAppVersion].stringValue ?? "1.0.0"
    }

    public var forceUpdateMinVersion: String {
        config[RCKey.forceUpdateMinVersion].stringValue ?? "1.0.0"
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

    /// Starts a realtime listener that auto-activates new config values when
    /// the server pushes an update. Safe to call multiple times — subsequent
    /// calls are no-ops.
    public func startRealtimeUpdates() {
        guard !realtimeListenerStarted else { return }
        realtimeListenerStarted = true

        config.addOnConfigUpdateListener { [weak self] update, error in
            guard let self else { return }
            if let error {
                self.logger.error("RemoteConfig realtime update error: \(error.localizedDescription)")
                return
            }
            guard let update else { return }
            self.logger.info(
                "RemoteConfig realtime update received, keys: \(update.updatedKeys.joined(separator: ", "))"
            )
            self.config.activate { _, activateError in
                if let activateError {
                    self.logger.error("RemoteConfig realtime activate error: \(activateError.localizedDescription)")
                } else {
                    self.logger.info("RemoteConfig realtime activate success")
                }
            }
        }
    }
}

// MARK: - Mock

/// Preview / test implementation with overridable property values.
public final class MockRemoteConfigService: RemoteConfigService, @unchecked Sendable {
    public var featureSeasonalEventsEnabled: Bool = true
    public var featureVoiceCloneEnabled: Bool = false
    public var featureBodyTrackingEnabled: Bool = true
    public var featureRealtimeLipsyncEnabled: Bool = false
    public var featureSpectrogramEnabled: Bool = true
    public var featureEmotionDetectionEnabled: Bool = true
    public var featureSpeakerVerificationEnabled: Bool = true
    public var lyalyaVoiceDefault: String = "tuned"
    public var dailyReminderTime: String = "17:00"
    public var weeklySummaryDay: String = "Monday"
    public var homeShowStreakCelebration: Bool = true
    public var parentDashboardShowMLInsights: Bool = true
    public var minAppVersion: String = "1.0.0"
    public var forceUpdateMinVersion: String = "1.0.0"

    public init() {}
    public func fetch() async throws {}
    public func activate() async throws -> Bool { false }
    public func startRealtimeUpdates() {}
}
