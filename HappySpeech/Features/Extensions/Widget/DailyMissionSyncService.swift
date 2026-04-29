import Foundation
import WidgetKit
import OSLog

// MARK: - DailyMissionSyncServiceProtocol

/// Синхронизирует данные ежедневного задания с виджетом через App Group UserDefaults.
/// COPPA: ни имя ребёнка, ни персональные данные не записываются в shared контейнер.
public protocol DailyMissionSyncServiceProtocol: Sendable {
    func updateMission(
        title: String,
        description: String,
        streakDays: Int,
        lyalyaState: String,
        progress: Double
    ) async
}

// MARK: - LiveDailyMissionSyncService

public actor LiveDailyMissionSyncService: DailyMissionSyncServiceProtocol {

    private let appGroup = "group.com.happyspeech.shared"
    private let logger = Logger(subsystem: "HappySpeech", category: "DailyMissionSync")

    public init() {}

    public func updateMission(
        title: String,
        description: String,
        streakDays: Int,
        lyalyaState: String,
        progress: Double
    ) async {
        guard let defaults = UserDefaults(suiteName: appGroup) else {
            logger.error("App Group UserDefaults недоступен: group.com.happyspeech.shared")
            return
        }

        defaults.set(title, forKey: "daily_mission.title")
        defaults.set(description, forKey: "daily_mission.description")
        defaults.set(streakDays, forKey: "daily_mission.streak")
        defaults.set(lyalyaState, forKey: "daily_mission.lyalya_state")
        defaults.set(progress, forKey: "daily_mission.progress")

        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: "DailyMissionWidget")
        }

        logger.info("Синхронизировано задание дня: \(title, privacy: .public), прогресс: \(progress, privacy: .public)")
    }
}

// MARK: - MockDailyMissionSyncService

public actor MockDailyMissionSyncService: DailyMissionSyncServiceProtocol {

    public struct LastUpdate: Sendable {
        public let title: String
        public let description: String
        public let streakDays: Int
        public let lyalyaState: String
        public let progress: Double
    }

    public var lastUpdate: LastUpdate?

    public init() {}

    public func updateMission(
        title: String,
        description: String,
        streakDays: Int,
        lyalyaState: String,
        progress: Double
    ) async {
        lastUpdate = LastUpdate(
            title: title,
            description: description,
            streakDays: streakDays,
            lyalyaState: lyalyaState,
            progress: progress
        )
    }
}
