import Foundation
import OSLog

// MARK: - ComprehensionDetectivePresentationLogic

@MainActor
protocol ComprehensionDetectivePresentationLogic: AnyObject {
    func presentStart(response: ComprehensionDetectiveModels.Start.Response) async
    func presentPick(response: ComprehensionDetectiveModels.Pick.Response) async
}

// MARK: - ComprehensionDetectivePresenter (Clean Swift: Presenter)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив» (F2-014).
//
// Строит игровые ViewModel: текст инструкции (озвучивается Лялей), сетку из
// 4 картинок, тёплую обратную связь по «светофору» (без «неправильно») и
// сводку «дело раскрыто». Все строки — String(localized:).

@MainActor
final class ComprehensionDetectivePresenter: ComprehensionDetectivePresentationLogic {

    weak var displayLogic: (any ComprehensionDetectiveDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.Presenter"
    )

    init(displayLogic: (any ComprehensionDetectiveDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: ComprehensionDetectiveModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = ComprehensionDetectiveModels.Start.ViewModel(
            title: String(localized: "detective.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Pick

    func presentPick(response: ComprehensionDetectiveModels.Pick.Response) async {
        let lyalyaLine = Self.feedbackLine(tier: response.feedback)

        let nextVM: ComprehensionDetectiveModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: ComprehensionDetectiveModels.Pick.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "detective.summary.title"),
                scoreText: String(
                    format: String(localized: "detective.summary.score"),
                    response.correctCount,
                    response.totalRounds
                ),
                correctCount: response.correctCount,
                totalRounds: response.totalRounds,
                accuracyFraction: accuracy,
                encouragement: Self.encouragement(for: accuracy),
                showCelebration: accuracy >= 0.8
            )
        } else {
            summary = nil
        }

        let viewModel = ComprehensionDetectiveModels.Pick.ViewModel(
            feedback: response.feedback,
            lyalyaLine: lyalyaLine,
            correctPictureId: response.correctPictureId,
            hintPictureId: response.showHint ? response.correctPictureId : nil,
            replaySlowly: response.replaySlowly,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: summary
        )
        await displayLogic?.displayPick(viewModel: viewModel)
    }

    // MARK: - Round building

    static func makeRoundVM(
        _ round: DetectiveRound,
        index: Int,
        total: Int
    ) -> ComprehensionDetectiveModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "detective.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        let pictures = round.shuffledPictures.map { picture in
            ComprehensionDetectiveModels.Start.PictureViewModel(
                id: picture.id,
                symbolName: picture.symbolName,
                accessibilityLabel: picture.label
            )
        }

        return .init(
            id: round.id,
            tier: round.item.tier,
            tierLabel: localized(round.item.tier.titleKey),
            tierHint: localized(round.item.tier.hintKey),
            instruction: round.item.instruction,
            pictures: pictures,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "detective.instruction.a11y"),
                round.item.instruction
            )
        )
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func feedbackLine(tier: FeedbackTier) -> String {
        switch tier {
        case .hit:
            return String(localized: "detective.feedback.hit")
        case .almost:
            return String(localized: "detective.feedback.almost")
        case .retry:
            // Подсказка: мягко показываем, что верная картинка светится.
            return String(localized: "detective.feedback.retry")
        }
    }

    // MARK: - Helpers

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "detective.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "detective.encourage.good")
        } else {
            return String(localized: "detective.encourage.keepGoing")
        }
    }

    // MARK: - Localization helper

    static func localized(_ key: String) -> String {
        let value = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        return value
    }
}
