import Foundation

// MARK: - PronunciationLeaderboard Namespace
//
// VIP модели для PronunciationLeaderboard (T.3 v17 / Block T).
// Внутри одной семьи (parentId), parent-only по COPPA.
// Per-child weekly accuracy ranking + сравнение текущая vs прошлая неделя.

enum PronunciationLeaderboard {

    // MARK: - Requests

    struct LoadRequest: Equatable {
        let parentId: String
    }

    struct SelectScopeRequest: Equatable {
        let scope: Scope
    }

    enum Scope: String, CaseIterable, Equatable {
        case thisWeek
        case lastWeek
        case allTime

        var localizedTitle: String {
            switch self {
            case .thisWeek: return String(localized: "leaderboard.scope.this_week")
            case .lastWeek: return String(localized: "leaderboard.scope.last_week")
            case .allTime:  return String(localized: "leaderboard.scope.all_time")
            }
        }
    }

    // MARK: - Responses

    struct LoadResponse {
        let entries: [LeaderboardEntryData]
        let comparison: [WeeklyComparison]   // per child: this vs last week
        let scope: Scope
    }

    /// Per-child сравнение текущей и прошлой недели.
    struct WeeklyComparison: Sendable {
        let childId: String
        let childName: String
        let currentAccuracy: Double
        let previousAccuracy: Double
        let trend: Trend
    }

    enum Trend: String, Sendable {
        case improving
        case stable
        case declining
    }

    // MARK: - ViewModel rows

    /// Строка лидерборда — finalized для UI.
    struct LeaderboardRow: Identifiable, Equatable {
        let id: String                   // childId
        let position: Int                // 1, 2, 3 ...
        let childName: String
        let accuracyText: String         // "84%"
        let accuracy: Double             // 0–1
        let sessionsCountText: String    // "7 занятий"
        let trendLabel: String           // "+5%" / "стабильно" / "−3%"
        let trendIcon: String            // SF Symbol
        let trendColorToken: String      // "success" | "warning" | "neutral"
        let medalSymbol: String?         // "1.circle.fill" / "trophy.fill"
        let isYou: Bool                  // подсветка
    }

    enum ScreenState: Equatable {
        case loading
        case empty
        case ready
        case error(String)
    }
}
