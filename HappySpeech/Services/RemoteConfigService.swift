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
    var featureQwenKidCircuit: Bool { get }

    // Content config
    var lyalyaVoiceDefault: String { get }
    var dailyReminderTime: String { get }
    var weeklySummaryDay: String { get }
    var parentSummaryDay: String { get }

    // Onboarding & session
    var onboardingSkipAllowed: Bool { get }
    var demoModeSteps: Int { get }
    var maxSessionDurationMin: Int { get }

    // UI flags
    var homeShowStreakCelebration: Bool { get }
    var parentDashboardShowMLInsights: Bool { get }

    // Version management
    var minAppVersion: String { get }
    var forceUpdateMinVersion: String { get }

    // Block U.5 v18 — A/B Testing
    /// Вариант туториала: `"A"` (default step-by-step) или `"B"` (gamified mini-quest).
    /// Назначается через Firebase A/B Testing. Activation event: `app_first_open`.
    var tutorialVariant: String { get }

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
    static let featureQwenKidCircuit          = "feature_qwen_kid_circuit"
    static let lyalyaVoiceDefault             = "lyalya_voice_default"
    static let dailyReminderTime              = "daily_reminder_time"
    static let weeklySummaryDay               = "weekly_summary_day"
    static let parentSummaryDay               = "parent_summary_day"
    static let onboardingSkipAllowed          = "onboarding_skip_allowed"
    static let demoModeSteps                  = "demo_mode_steps"
    static let maxSessionDurationMin          = "max_session_duration_min"
    static let homeShowStreakCelebration      = "home_show_streak_celebration"
    static let parentDashboardShowMLInsights  = "parent_dashboard_show_ml_insights"
    static let minAppVersion                  = "min_app_version"
    static let forceUpdateMinVersion          = "force_update_min_version"
    static let tutorialVariant                = "tutorial_variant"
}

// MARK: - Live Implementation

/// Protocol-based DI wrapper around FirebaseRemoteConfig.
/// @Observable for SwiftUI bindings — property reads are main-actor-safe.
@Observable
public final class LiveRemoteConfigService: RemoteConfigService, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "RemoteConfig")
    private let config: RemoteConfig
    // Флаг пишется один раз при первом вызове startRealtimeUpdates() и читается в том же методе.
    // В проекте startRealtimeUpdates вызывается строго из MainActor при старте приложения — гонки
    // данных нет. @unchecked Sendable на классе оправдан, поэтому isolation на instance property
    // не нужна (nonisolated(unsafe) не имеет эффекта для нестатических stored properties в Swift 6).
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
        RCKey.featureQwenKidCircuit:         false as NSNumber,
        RCKey.lyalyaVoiceDefault:            "pro" as NSString,
        RCKey.dailyReminderTime:             "17:00" as NSString,
        RCKey.weeklySummaryDay:              "sunday" as NSString,
        RCKey.parentSummaryDay:              "sunday" as NSString,
        RCKey.onboardingSkipAllowed:         true as NSNumber,
        RCKey.demoModeSteps:                 15 as NSNumber,
        RCKey.maxSessionDurationMin:         25 as NSNumber,
        RCKey.homeShowStreakCelebration:     true as NSNumber,
        RCKey.parentDashboardShowMLInsights: true as NSNumber,
        RCKey.minAppVersion:                 "1.0.0" as NSString,
        RCKey.forceUpdateMinVersion:         "1.0.0" as NSString,
        RCKey.tutorialVariant:               "A" as NSString
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

    public var featureQwenKidCircuit: Bool {
        config[RCKey.featureQwenKidCircuit].boolValue
    }

    // MARK: - Content config

    public var lyalyaVoiceDefault: String {
        let v = config[RCKey.lyalyaVoiceDefault].stringValue
        return v.isEmpty ? "pro" : v
    }

    public var dailyReminderTime: String {
        let v = config[RCKey.dailyReminderTime].stringValue
        return v.isEmpty ? "17:00" : v
    }

    public var weeklySummaryDay: String {
        let v = config[RCKey.weeklySummaryDay].stringValue
        return v.isEmpty ? "sunday" : v
    }

    public var parentSummaryDay: String {
        let v = config[RCKey.parentSummaryDay].stringValue
        return v.isEmpty ? "sunday" : v
    }

    // MARK: - Onboarding & session config

    public var onboardingSkipAllowed: Bool {
        config[RCKey.onboardingSkipAllowed].boolValue
    }

    public var demoModeSteps: Int {
        let v = config[RCKey.demoModeSteps].numberValue.intValue
        return v > 0 ? v : 15
    }

    public var maxSessionDurationMin: Int {
        let v = config[RCKey.maxSessionDurationMin].numberValue.intValue
        return v > 0 ? v : 25
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
        let v = config[RCKey.minAppVersion].stringValue
        return v.isEmpty ? "1.0.0" : v
    }

    public var forceUpdateMinVersion: String {
        let v = config[RCKey.forceUpdateMinVersion].stringValue
        return v.isEmpty ? "1.0.0" : v
    }

    /// Plan v18 Block U.5 — A/B Testing tutorial variant.
    /// Возвращает `"A"` или `"B"` (нормализуется в uppercase). Дефолт `"A"`.
    public var tutorialVariant: String {
        let raw = config[RCKey.tutorialVariant].stringValue.uppercased()
        return (raw == "B") ? "B" : "A"
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
    public var featureQwenKidCircuit: Bool = false
    public var lyalyaVoiceDefault: String = "pro"
    public var dailyReminderTime: String = "17:00"
    public var weeklySummaryDay: String = "sunday"
    public var parentSummaryDay: String = "sunday"
    public var onboardingSkipAllowed: Bool = true
    public var demoModeSteps: Int = 15
    public var maxSessionDurationMin: Int = 25
    public var homeShowStreakCelebration: Bool = true
    public var parentDashboardShowMLInsights: Bool = true
    public var minAppVersion: String = "1.0.0"
    public var forceUpdateMinVersion: String = "1.0.0"
    public var tutorialVariant: String = "A"

    public init() {}
    public func fetch() async throws {}
    public func activate() async throws -> Bool { false }
    public func startRealtimeUpdates() {}
}
