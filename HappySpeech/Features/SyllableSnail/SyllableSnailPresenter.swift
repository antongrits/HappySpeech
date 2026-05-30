import Foundation
import OSLog

// MARK: - SyllableSnailPresentationLogic

@MainActor
protocol SyllableSnailPresentationLogic: AnyObject {
    func presentStart(response: SyllableSnailModels.Start.Response) async
    func presentTap(response: SyllableSnailModels.Tap.Response) async
    func presentSubmit(response: SyllableSnailModels.Submit.Response) async
    func presentFix(response: SyllableSnailModels.Fix.Response) async
}

// MARK: - SyllableSnailPresenter (Clean Swift: Presenter)
//
// F2-003 «Слоговая улитка» (Wave 2).
//
// Строит игровые ViewModel: приглашение Ляли по режиму, тропинку-слоги, тёплую
// обратную связь по «светофору» (без «неправильно») и сводку. Все строки —
// String(localized:).

@MainActor
final class SyllableSnailPresenter: SyllableSnailPresentationLogic {

    weak var displayLogic: (any SyllableSnailDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableSnail.Presenter"
    )

    init(displayLogic: (any SyllableSnailDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: SyllableSnailModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = SyllableSnailModels.Start.ViewModel(
            title: String(localized: "syllableSnail.title"),
            modeLabel: Self.modeLabel(response.mode),
            tierLabel: Self.tierLabel(response.tier),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Tap (режим A)

    func presentTap(response: SyllableSnailModels.Tap.Response) async {
        let line = Self.tapFeedbackLine(
            tier: response.feedback,
            expected: response.expectedSyllables
        )
        let viewModel = SyllableSnailModels.Tap.ViewModel(
            feedback: response.feedback,
            lyalyaLine: line,
            expectedSyllables: response.expectedSyllables,
            replayBySyllable: response.replayBySyllable,
            snailReachedHome: response.snailReachedHome,
            showHint: response.showHint,
            isFinished: response.isFinished,
            nextRound: Self.nextVM(response.nextRound, index: response.nextRoundIndex, total: response.totalRounds),
            summary: Self.summary(
                isFinished: response.isFinished,
                correct: response.correctCount,
                total: response.totalRounds
            )
        )
        await displayLogic?.displayTap(viewModel: viewModel)
    }

    // MARK: - Submit (режим B)

    func presentSubmit(response: SyllableSnailModels.Submit.Response) async {
        let line = Self.assembleFeedbackLine(tier: response.feedback, expected: response.expected)
        let viewModel = SyllableSnailModels.Submit.ViewModel(
            feedback: response.feedback,
            lyalyaLine: line,
            assembled: response.assembled,
            snailReachedHome: response.snailReachedHome,
            replayBySyllable: response.replayBySyllable,
            firstWrongSlotIndex: response.firstWrongSlotIndex,
            showHint: response.showHint,
            isFinished: response.isFinished,
            nextRound: Self.nextVM(response.nextRound, index: response.nextRoundIndex, total: response.totalRounds),
            summary: Self.summary(
                isFinished: response.isFinished,
                correct: response.correctCount,
                total: response.totalRounds
            )
        )
        await displayLogic?.displaySubmit(viewModel: viewModel)
    }

    // MARK: - Fix (режим C)

    func presentFix(response: SyllableSnailModels.Fix.Response) async {
        let line = Self.fixFeedbackLine(tier: response.feedback, expected: response.expected)
        let viewModel = SyllableSnailModels.Fix.ViewModel(
            feedback: response.feedback,
            lyalyaLine: line,
            assembled: response.assembled,
            snailReachedHome: response.snailReachedHome,
            replayBySyllable: response.replayBySyllable,
            firstWrongSlotIndex: response.firstWrongSlotIndex,
            showHint: response.showHint,
            isFinished: response.isFinished,
            nextRound: Self.nextVM(response.nextRound, index: response.nextRoundIndex, total: response.totalRounds),
            summary: Self.summary(
                isFinished: response.isFinished,
                correct: response.correctCount,
                total: response.totalRounds
            )
        )
        await displayLogic?.displayFix(viewModel: viewModel)
    }

    // MARK: - Round building

    static func makeRoundVM(
        _ round: SnailRound,
        index: Int,
        total: Int
    ) -> SyllableSnailModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "syllableSnail.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        let tiles = round.tiles.map { tile in
            SyllableSnailModels.Start.TileViewModel(
                id: tile.id,
                text: tile.text,
                accessibilityLabel: String(
                    format: String(localized: "syllableSnail.tile.a11y"),
                    tile.text
                )
            )
        }

        return .init(
            id: round.id,
            mode: round.mode,
            imageAsset: round.word.imageAsset,
            wordText: round.word.word,
            promptLyalya: prompt(for: round.mode, word: round.word.word),
            pathSlotsCount: round.word.syllables.count,
            tiles: tiles,
            audioSyllables: round.word.audioSyllables,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "syllableSnail.round.a11y"),
                round.word.word
            )
        )
    }

    private static func nextVM(
        _ round: SnailRound?,
        index: Int?,
        total: Int
    ) -> SyllableSnailModels.Start.RoundViewModel? {
        guard let round, let index else { return nil }
        return makeRoundVM(round, index: index, total: total)
    }

    // MARK: - Prompts (по режиму)

    static func prompt(for mode: SnailMode, word: String) -> String {
        switch mode {
        case .clap:
            return String(localized: "syllableSnail.prompt.clap")
        case .build:
            return String(localized: "syllableSnail.prompt.build")
        case .fix:
            return String(localized: "syllableSnail.prompt.fix")
        }
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func tapFeedbackLine(tier: FeedbackTier, expected: Int) -> String {
        switch tier {
        case .hit:
            return String(localized: "syllableSnail.tap.hit")
        case .almost:
            return String(localized: "syllableSnail.tap.almost")
        case .retry:
            return String(
                format: String(localized: "syllableSnail.tap.retry"),
                expected
            )
        }
    }

    static func assembleFeedbackLine(tier: FeedbackTier, expected: String) -> String {
        switch tier {
        case .hit:
            return String(localized: "syllableSnail.build.hit")
        case .almost:
            return String(localized: "syllableSnail.build.almost")
        case .retry:
            return String(
                format: String(localized: "syllableSnail.build.retry"),
                expected
            )
        }
    }

    static func fixFeedbackLine(tier: FeedbackTier, expected: String) -> String {
        switch tier {
        case .hit:
            return String(localized: "syllableSnail.fix.hit")
        case .almost:
            return String(localized: "syllableSnail.fix.almost")
        case .retry:
            return String(
                format: String(localized: "syllableSnail.fix.retry"),
                expected
            )
        }
    }

    // MARK: - Labels

    static func modeLabel(_ mode: SnailMode) -> String {
        switch mode {
        case .clap:  return String(localized: "syllableSnail.mode.clap")
        case .build: return String(localized: "syllableSnail.mode.build")
        case .fix:   return String(localized: "syllableSnail.mode.fix")
        }
    }

    static func tierLabel(_ tier: SyllableTier) -> String {
        switch tier {
        case .oneSyllableOpen:          return String(localized: "syllableSnail.tier.1")
        case .twoSyllablesOpen:         return String(localized: "syllableSnail.tier.2")
        case .threeSyllablesWithClosed: return String(localized: "syllableSnail.tier.3")
        case .consonantCluster:         return String(localized: "syllableSnail.tier.4")
        }
    }

    // MARK: - Summary

    static func summary(
        isFinished: Bool,
        correct: Int,
        total: Int
    ) -> SyllableSnailModels.SummaryViewModel? {
        guard isFinished else { return nil }
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0
        return .init(
            title: String(localized: "syllableSnail.summary.title"),
            scoreText: String(
                format: String(localized: "syllableSnail.summary.score"),
                correct,
                total
            ),
            correctCount: correct,
            totalRounds: total,
            accuracyFraction: accuracy,
            encouragement: encouragement(for: accuracy),
            showCelebration: accuracy >= 0.8
        )
    }

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "syllableSnail.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "syllableSnail.encourage.good")
        } else {
            return String(localized: "syllableSnail.encourage.keepGoing")
        }
    }
}
