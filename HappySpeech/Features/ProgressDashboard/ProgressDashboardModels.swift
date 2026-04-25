import Foundation
import SwiftUI

// MARK: - ProgressDashboard VIP Models
//
// Доменные модели + transport-слои Request / Response / ViewModel.
// Контур: parent. Дашборд прогресса ребёнка с summary-карточками,
// графиками (bar + line через Apple Charts), AI-сводкой от LLM и сеткой
// звуков с трендами. Источник данных в M7.2 — in-memory seed; на M8 будет
// агрегация из `SessionRepository` и `LLMDecisionService.generateParentSummary`.

enum ProgressDashboardModels {

    // MARK: - LoadDashboard

    enum LoadDashboard {
        struct Request: Sendable {
            let childId: String
            let forceReload: Bool
            init(childId: String, forceReload: Bool = false) {
                self.childId = childId
                self.forceReload = forceReload
            }
        }

        struct Response: Sendable {
            let summary: DashboardSummary
            let dailyAccuracy: [DailyAccuracy]
            let weeklyAccuracy: [WeeklyAccuracy]
            let sounds: [SoundProgress]
        }

        struct ViewModel: Sendable {
            let summaryCards: [SummaryCardViewModel]
            let dailyChart: [DailyChartPoint]
            let weeklyChart: [WeeklyChartPoint]
            let dailyAxisLabels: [String]
            let soundCells: [SoundProgressCellViewModel]
            let isEmpty: Bool
            let emptyTitle: String
            let emptyMessage: String
        }
    }

    // MARK: - LoadSoundDetail

    enum LoadSoundDetail {
        struct Request: Sendable {
            let sound: String
        }
        struct Response: Sendable {
            let progress: SoundProgress
            let history: [DailyAccuracy]
        }
        struct ViewModel: Sendable {
            let detail: SoundDetailViewModel
        }
    }

    // MARK: - RequestLLMSummary

    enum RequestLLMSummary {
        struct Request: Sendable {
            let childName: String
            let summary: DashboardSummary
            let topSound: SoundProgress?
        }
        struct Response: Sendable {
            let summaryText: String
            let isFallback: Bool
        }
        struct ViewModel: Sendable {
            let summary: LLMSummaryViewModel
        }
    }

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable {
            let message: String
        }
        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}

// MARK: - Domain types

struct DashboardSummary: Sendable, Equatable {
    let overallAccuracy: Float       // 0...1
    let streakDays: Int
    let totalMinutes: Int
    let totalStars: Int
}

struct SoundProgress: Sendable, Identifiable, Equatable, Hashable {
    var id: String { sound }
    let sound: String
    let accuracy: Float              // 0...1
    let sessions: Int
    let trend: ProgressTrend
}

enum ProgressTrend: String, Sendable, Equatable {
    case up
    case down
    case stable
}

struct DailyAccuracy: Sendable, Identifiable, Equatable, Hashable {
    var id: String { day }
    let day: String      // «Пн», «Вт» и т.д.
    let accuracy: Float  // 0...1
}

struct WeeklyAccuracy: Sendable, Identifiable, Equatable, Hashable {
    var id: Int { weekIndex }
    let weekIndex: Int
    let label: String   // «Нед 1»
    let accuracy: Float // 0...1
}

// MARK: - View-ready

struct SummaryCardViewModel: Sendable, Identifiable, Equatable {
    enum Kind: String, Sendable, Equatable {
        case accuracy
        case streak
        case minutes
        case stars
    }

    let id: String
    let kind: Kind
    let title: String
    let value: String
    let valueAccent: SummaryAccent
    let caption: String?
    let progress: Double?
    let accessibilityLabel: String
}

enum SummaryAccent: Sendable, Equatable {
    case accent
    case butter
    case mint
    case lilac
}

struct DailyChartPoint: Sendable, Identifiable, Equatable, Hashable {
    var id: String { day }
    let day: String
    let value: Double      // 0...100 (percent)
}

struct WeeklyChartPoint: Sendable, Identifiable, Equatable, Hashable {
    var id: Int { weekIndex }
    let weekIndex: Int
    let label: String
    let value: Double      // 0...100 (percent)
}

struct SoundProgressCellViewModel: Sendable, Identifiable, Equatable, Hashable {
    let id: String        // sound letter
    let sound: String
    let accuracyText: String
    let accuracyValue: Double  // 0...100
    let trend: ProgressTrend
    let trendIconName: String
    let sessionsCaption: String
    let familyHueName: String
    let accessibilityLabel: String
}

struct LLMSummaryViewModel: Sendable, Equatable {
    let title: String
    let bodyText: String
    let isFallback: Bool
    let accessibilityLabel: String
}

// MARK: - Detail view-model

struct SoundDetailViewModel: Sendable, Equatable, Hashable {
    let sound: String
    let accuracyPercent: Int
    let sessionsCount: Int
    let trend: ProgressTrend
    let history: [DailyChartPoint]
    let title: String
    let trendDescription: String
    let accessibilityLabel: String
}
