import Foundation
import SwiftUI

// MARK: - ChildHome VIP Models

enum ChildHomeModels {

    // MARK: - Fetch
    enum Fetch {
        struct Request {
            let childId: String
        }
        struct Response {
            let childName: String
            let currentStreak: Int
            let mascotMood: MascotMood
            let mascotPhrase: String?
            let dailyTargetSound: String
            let dailyStage: String
            let dailyProgress: Double
            let soundProgress: [SoundProgressData]
        }
        struct ViewModel {
            let childName: String
            let currentStreak: Int
            let mascotMood: MascotMood
            let mascotPhrase: String?
            let dailyMission: DailyMission
            let soundProgress: [SoundProgressItem]
        }
    }

    // MARK: - Data transfer

    struct SoundProgressData: Sendable {
        let sound: String
        let stageName: String
        let rate: Double
    }

    // MARK: - Supporting ViewModel types

    struct DailyMission: Hashable {
        let targetSound: String
        let title: String
        let subtitle: String
        let progress: Double

        static let placeholder = DailyMission(
            targetSound: "Р",
            title: "Звук Р в словах",
            subtitle: "Этап 3 · Слова с Р в начале",
            progress: 0.0
        )
    }

    struct SoundProgressItem: Identifiable, Hashable {
        var id: String { sound }
        let sound: String
        let stageName: String
        let rate: Double
        let accent: SoundFamily
    }
}
