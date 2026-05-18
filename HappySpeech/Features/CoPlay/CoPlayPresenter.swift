import Foundation
import OSLog

// MARK: - CoPlayPresentationLogic

@MainActor
protocol CoPlayPresentationLogic: AnyObject {
    func presentStart(response: CoPlayModels.Start.Response) async
    func presentNextTurn(response: CoPlayModels.NextTurn.Response) async
}

// MARK: - CoPlayPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 8 «Занятие вместе».
//
// Строит ViewModel ходов совместной игры: подсветка роли, реплика-образец,
// инструкция, прогресс, итоговый инструктаж взрослому.
// Все строки — String(localized:).

@MainActor
final class CoPlayPresenter: CoPlayPresentationLogic {

    weak var displayLogic: (any CoPlayDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CoPlay.Presenter"
    )

    init(displayLogic: (any CoPlayDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: CoPlayModels.Start.Response) async {
        guard let firstTurn = response.activity.turns.first else {
            Self.logger.error("Start with empty turns")
            return
        }
        let total = response.activity.turns.count
        let viewModel = CoPlayModels.Start.ViewModel(
            title: String(localized: "coPlay.title"),
            activityTitle: response.activity.title,
            symbolName: response.activity.symbolName,
            adultBriefing: response.activity.adultBriefing,
            totalTurns: total,
            firstTurn: Self.makeTurnVM(firstTurn, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - NextTurn

    func presentNextTurn(response: CoPlayModels.NextTurn.Response) async {
        let nextVM: CoPlayModels.Start.TurnViewModel?
        if let nextTurn = response.nextTurn, let nextIndex = response.nextTurnIndex {
            nextVM = Self.makeTurnVM(nextTurn, index: nextIndex, total: response.totalTurns)
        } else {
            nextVM = nil
        }

        let summary: CoPlayModels.NextTurn.SummaryViewModel?
        if response.isFinished {
            summary = .init(
                title: String(localized: "coPlay.summary.title"),
                turnsLabel: String(
                    format: String(localized: "coPlay.summary.turns"),
                    response.totalTurns
                ),
                adultTip: String(localized: "coPlay.summary.adultTip")
            )
        } else {
            summary = nil
        }

        let viewModel = CoPlayModels.NextTurn.ViewModel(
            isFinished: response.isFinished,
            nextTurn: nextVM,
            summary: summary
        )
        await displayLogic?.displayNextTurn(viewModel: viewModel)
    }

    // MARK: - Turn building

    static func makeTurnVM(
        _ turn: CoPlayTurn,
        index: Int,
        total: Int
    ) -> CoPlayModels.Start.TurnViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "coPlay.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0
        let roleLabel = turn.role == .adult
            ? String(localized: "coPlay.role.adult")
            : String(localized: "coPlay.role.child")

        return .init(
            id: turn.id,
            role: turn.role,
            line: turn.line,
            instruction: turn.instruction,
            roleLabel: roleLabel,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "coPlay.turn.a11y"),
                roleLabel,
                turn.line
            )
        )
    }
}
