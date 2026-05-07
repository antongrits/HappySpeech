import Foundation
import OSLog

// MARK: - FamilyLeaderboardPresentationLogic

@MainActor
protocol FamilyLeaderboardPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: FamilyLeaderboardModels.Load.Response) async
}

// MARK: - FamilyLeaderboardPresenter (Clean Swift: Presenter)
//
// Block S.2 v16 — Response → ViewModel.
// Локализация всех текстов, форматирование процентов, медалей.

@MainActor
final class FamilyLeaderboardPresenter: FamilyLeaderboardPresentationLogic {

    weak var displayLogic: (any FamilyLeaderboardDisplayLogic)?

    init(displayLogic: (any FamilyLeaderboardDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: FamilyLeaderboardModels.Load.Response) async {
        let title = String(localized: "leaderboard.title")
        let subtitle: String
        if response.entries.isEmpty {
            subtitle = String(localized: "leaderboard.subtitle.empty")
        } else {
            subtitle = String(
                format: String(localized: "leaderboard.subtitle.weekTotal"),
                response.totalSessionsAcrossFamily
            )
        }

        let rows: [FamilyLeaderboardModels.Load.ViewModel.Row] = response.entries
            .enumerated()
            .map { index, entry in
                let rank = index + 1
                let medal: FamilyLeaderboardModels.Load.ViewModel.Medal? = switch rank {
                case 1: .gold
                case 2: .silver
                case 3: .bronze
                default: nil
                }
                let primary = String(
                    format: String(localized: "leaderboard.row.sessions"),
                    entry.sessionCount
                )
                let secondary = String(
                    format: String(localized: "leaderboard.row.accuracy"),
                    Int(round(entry.avgAccuracy * 100))
                )
                let scoreLabel = String(
                    format: String(localized: "leaderboard.row.score"),
                    Int(round(entry.totalScore))
                )
                let a11y = String(
                    format: String(localized: "leaderboard.row.a11y"),
                    rank,
                    entry.childName,
                    entry.sessionCount,
                    Int(round(entry.avgAccuracy * 100))
                )
                return FamilyLeaderboardModels.Load.ViewModel.Row(
                    id: entry.id,
                    rank: rank,
                    medal: medal,
                    childName: entry.childName,
                    primaryStat: primary,
                    secondaryStat: secondary,
                    scoreLabel: scoreLabel,
                    colorHex: entry.colorTheme,
                    accessibilityLabel: a11y,
                    isLeader: rank == 1
                )
            }

        let viewModel = FamilyLeaderboardModels.Load.ViewModel(
            title: title,
            subtitle: subtitle,
            periodLabel: response.period.localizedTitle,
            rows: rows,
            isEmpty: rows.isEmpty
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }
}
