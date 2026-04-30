import Foundation
import SwiftUI

// MARK: - ComparisonDashboard VIP Models

enum ComparisonDashboard {

    // MARK: - Requests

    struct LoadRequest {
        let childIds: [String]
    }

    // MARK: - Responses

    struct LoadResponse {
        let children: [ChildComparisonData]
    }

    // MARK: - Domain types

    struct ChildComparisonData: Identifiable, Sendable {
        let id: String
        let name: String
        let colorTheme: String
        let avatarStyle: String
        let weeklySuccess: [WeekPoint]           // последние 7 недель
        let soundAccuracy: [SoundPoint]          // по каждому звуку
        let dailyPracticeMinutes: [DayPoint]     // последние 7 дней
        let currentStreak: Int
        let totalMinutes: Int
    }

    struct WeekPoint: Identifiable, Sendable {
        let id = UUID()
        let weekLabel: String   // "Нед. 1"
        let weekIndex: Int
        let successRate: Double  // 0.0–1.0
    }

    struct SoundPoint: Identifiable, Sendable {
        let id = UUID()
        let sound: String       // "Р", "Ш" и т.д.
        let accuracy: Double    // 0.0–1.0
    }

    struct DayPoint: Identifiable, Sendable {
        let id = UUID()
        let dayLabel: String    // "Пн", "Вт" и т.д.
        let dayIndex: Int
        let minutes: Double
    }
}

// MARK: - ComparisonDashboardViewModel

@Observable
@MainActor
final class ComparisonDashboardViewModel {
    var children: [ComparisonDashboard.ChildComparisonData] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // Charts need child-color mapping
    func chartColor(for childId: String) -> Color {
        let colors: [Color] = [
            ColorTokens.Brand.primary,
            ColorTokens.Brand.sky,
            ColorTokens.Brand.mint,
            ColorTokens.Brand.lilac
        ]
        let idx = children.firstIndex { $0.id == childId } ?? 0
        return colors[idx % colors.count]
    }

    var hasData: Bool { !children.isEmpty }

    var allSounds: [String] {
        let sounds = children.flatMap { $0.soundAccuracy.map(\.sound) }
        return Array(Set(sounds)).sorted()
    }
}
