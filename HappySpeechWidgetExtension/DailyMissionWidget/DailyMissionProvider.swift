import WidgetKit
import SwiftUI

// MARK: - DailyMissionEntry

struct DailyMissionEntry: TimelineEntry {
    let date: Date
    let missionTitle: String
    let missionDescription: String
    let streakDays: Int
    let lyalyaState: String  // "happy", "encouraging", "sleepy"
    let progressPercent: Double
}

// MARK: - DailyMissionProvider

struct DailyMissionProvider: TimelineProvider {

    // MARK: Placeholder

    func placeholder(in context: Context) -> DailyMissionEntry {
        DailyMissionEntry(
            date: Date(),
            missionTitle: "Звук Ш",
            missionDescription: "5 раундов",
            streakDays: 7,
            lyalyaState: "happy",
            progressPercent: 0.6
        )
    }

    // MARK: Snapshot

    func getSnapshot(in context: Context, completion: @escaping (DailyMissionEntry) -> Void) {
        completion(placeholder(in: context))
    }

    // MARK: Timeline

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyMissionEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.happyspeech.shared")

        let title = defaults?.string(forKey: "daily_mission.title") ?? "Звук Ш"
        let description = defaults?.string(forKey: "daily_mission.description") ?? "5 раундов"
        let streak = defaults?.integer(forKey: "daily_mission.streak") ?? 0
        let state = defaults?.string(forKey: "daily_mission.lyalya_state") ?? "happy"
        let progress = defaults?.double(forKey: "daily_mission.progress") ?? 0.0

        let entry = DailyMissionEntry(
            date: Date(),
            missionTitle: title,
            missionDescription: description,
            streakDays: streak,
            lyalyaState: state,
            progressPercent: progress
        )

        // Обновляем каждый час
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}
