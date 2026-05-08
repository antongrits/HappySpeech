import Foundation
import OSLog

// MARK: - PronunciationLeaderboardPresenter
//
// Преобразует Response из Interactor в готовые для отрисовки строки.
// Считает позиции, добавляет медали, формирует trend label.

@MainActor
final class PronunciationLeaderboardPresenter {

    weak var viewModel: PronunciationLeaderboardViewModel?

    /// Имя текущего ребёнка-владельца устройства (для подсветки строки).
    /// Если nil — никакая строка не подсвечивается.
    var youChildId: String?

    /// Известные имена детей (childId → name) — заполняем перед presentLoad.
    var childNameRegistry: [String: String] = [:]

    // MARK: - Load

    func presentLoad(_ response: PronunciationLeaderboard.LoadResponse) {
        let comparisonByChild = Dictionary(
            uniqueKeysWithValues: response.comparison.map { ($0.childId, $0) }
        )

        let rows = response.entries.enumerated().map { index, entry -> PronunciationLeaderboard.LeaderboardRow in
            let position = index + 1
            let childName = childName(for: entry.childId, fallback: comparisonByChild[entry.childId]?.childName)
            let comparison = comparisonByChild[entry.childId]

            let trendLabel = makeTrendLabel(comparison: comparison)
            let trendIcon = makeTrendIcon(comparison: comparison)
            let trendColor = makeTrendColorToken(comparison: comparison)
            let medal = makeMedalSymbol(position: position)

            return PronunciationLeaderboard.LeaderboardRow(
                id: entry.childId,
                position: position,
                childName: childName,
                accuracyText: "\(Int(entry.weeklyAccuracy * 100))%",
                accuracy: entry.weeklyAccuracy,
                sessionsCountText: makeSessionsCountText(count: entry.sessionsCount),
                trendLabel: trendLabel,
                trendIcon: trendIcon,
                trendColorToken: trendColor,
                medalSymbol: medal,
                isYou: entry.childId == youChildId
            )
        }

        viewModel?.rows = rows
        viewModel?.scope = response.scope
        viewModel?.state = rows.isEmpty ? .empty : .ready
        viewModel?.errorMessage = nil
        viewModel?.totalChildrenText = String(
            format: String(localized: "leaderboard.summary.total"),
            rows.count
        )
    }

    func presentError(_ message: String) {
        viewModel?.state = .error(message)
        viewModel?.errorMessage = message
    }

    // MARK: - Builders

    private func childName(for childId: String, fallback: String?) -> String {
        if let registered = childNameRegistry[childId], !registered.isEmpty {
            return registered
        }
        return fallback ?? String(localized: "leaderboard.unknown_child")
    }

    private func makeMedalSymbol(position: Int) -> String? {
        switch position {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return nil
        }
    }

    private func makeTrendLabel(comparison: PronunciationLeaderboard.WeeklyComparison?) -> String {
        guard let comparison else {
            return String(localized: "leaderboard.trend.no_data")
        }
        let delta = comparison.currentAccuracy - comparison.previousAccuracy
        let percentDelta = Int((delta * 100).rounded())
        switch comparison.trend {
        case .improving:
            return "+\(percentDelta)%"
        case .declining:
            return "\(percentDelta)%"
        case .stable:
            return String(localized: "leaderboard.trend.stable")
        }
    }

    private func makeTrendIcon(comparison: PronunciationLeaderboard.WeeklyComparison?) -> String {
        guard let comparison else { return "minus.circle" }
        switch comparison.trend {
        case .improving: return "arrow.up.right.circle.fill"
        case .declining: return "arrow.down.right.circle.fill"
        case .stable:    return "equal.circle.fill"
        }
    }

    private func makeTrendColorToken(comparison: PronunciationLeaderboard.WeeklyComparison?) -> String {
        guard let comparison else { return "neutral" }
        switch comparison.trend {
        case .improving: return "success"
        case .declining: return "warning"
        case .stable:    return "neutral"
        }
    }

    private func makeSessionsCountText(count: Int) -> String {
        // Простая русская плюрализация для "занятий" / "занятие" / "занятия".
        let mod10 = count % 10
        let mod100 = count % 100
        let suffix: String
        if mod100 >= 11 && mod100 <= 14 {
            suffix = String(localized: "leaderboard.sessions.many")
        } else {
            switch mod10 {
            case 1: suffix = String(localized: "leaderboard.sessions.one")
            case 2, 3, 4: suffix = String(localized: "leaderboard.sessions.few")
            default: suffix = String(localized: "leaderboard.sessions.many")
            }
        }
        return "\(count) \(suffix)"
    }
}

// MARK: - PronunciationLeaderboardViewModel

@Observable
@MainActor
final class PronunciationLeaderboardViewModel {
    var state: PronunciationLeaderboard.ScreenState = .loading
    var rows: [PronunciationLeaderboard.LeaderboardRow] = []
    var scope: PronunciationLeaderboard.Scope = .thisWeek
    var totalChildrenText: String = ""
    var errorMessage: String?
}
