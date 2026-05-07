import Foundation
import SwiftUI

// MARK: - FamilyLeaderboardModels (Clean Swift: Models)
//
// Block S.2 v16 — Family Leaderboard (multi-child weekly competition).
//
// Видим только parent context (FamilyHome). Дети НЕ видят leaderboard
// в ChildHome — COPPA strict.

// MARK: - LeaderboardPeriod

enum LeaderboardPeriod: String, Sendable, CaseIterable {
    case week
    case month
    case allTime

    var localizedTitle: String {
        switch self {
        case .week:    return String(localized: "leaderboard.period.week")
        case .month:   return String(localized: "leaderboard.period.month")
        case .allTime: return String(localized: "leaderboard.period.allTime")
        }
    }
}

// MARK: - FamilyLeaderboardModels namespace

enum FamilyLeaderboardModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let parentId: String
            let period: LeaderboardPeriod
        }

        struct Response: Sendable {
            let entries: [Entry]
            let period: LeaderboardPeriod
            let totalSessionsAcrossFamily: Int
            let weekStartDate: Date
        }

        struct Entry: Sendable, Identifiable {
            let id: String           // childId
            let childName: String
            let avatarStyle: String
            let colorTheme: String
            let sessionCount: Int
            let totalScore: Double   // sum of correctAttempts × successRate
            let avgAccuracy: Double  // 0.0 — 1.0
            let currentStreak: Int
        }

        struct ViewModel: Sendable {

            let title: String
            let subtitle: String
            let periodLabel: String
            let rows: [Row]
            let isEmpty: Bool

            struct Row: Sendable, Identifiable {
                let id: String
                let rank: Int
                let medal: Medal?
                let childName: String
                let primaryStat: String     // "X сессий"
                let secondaryStat: String   // "точность 87%"
                let scoreLabel: String      // "1240 очков"
                let colorHex: String
                let accessibilityLabel: String
                let isLeader: Bool
            }

            enum Medal: String, Sendable {
                case gold
                case silver
                case bronze

                var symbolName: String {
                    switch self {
                    case .gold:   return "1.circle.fill"
                    case .silver: return "2.circle.fill"
                    case .bronze: return "3.circle.fill"
                    }
                }

                var emoji: String {
                    switch self {
                    case .gold:   return "🥇"
                    case .silver: return "🥈"
                    case .bronze: return "🥉"
                    }
                }
            }
        }
    }

    // MARK: ChangePeriod

    enum ChangePeriod {
        struct Request: Sendable {
            let period: LeaderboardPeriod
        }
    }
}
