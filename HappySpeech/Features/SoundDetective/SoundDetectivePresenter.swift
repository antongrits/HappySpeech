import Foundation
import OSLog

// MARK: - SoundDetectivePresentationLogic

@MainActor
protocol SoundDetectivePresentationLogic: AnyObject {
    func presentStart(response: SoundDetectiveModels.Start.Response) async
    func presentAnswer(response: SoundDetectiveModels.Answer.Response) async
}

// MARK: - SoundDetectivePresenter (Clean Swift: Presenter)
//
// F2-009 «Звуковой детектив» (Wave 2).
//
// Строит игровые ViewModel: вопрос Ляли-детектива, зоны-окошки «полоски
// слова», тёплую обратную связь по «светофору» (без «неправильно») и сводку
// «дело раскрыто». Все строки — String(localized:).

@MainActor
final class SoundDetectivePresenter: SoundDetectivePresentationLogic {

    weak var displayLogic: (any SoundDetectiveDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDetective.Presenter"
    )

    init(displayLogic: (any SoundDetectiveDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: SoundDetectiveModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = SoundDetectiveModels.Start.ViewModel(
            title: String(localized: "soundDetective.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: SoundDetectiveModels.Answer.Response) async {
        let lyalyaLine = Self.feedbackLine(
            tier: response.feedback,
            correctZone: response.correctZone
        )

        let nextVM: SoundDetectiveModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: SoundDetectiveModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "soundDetective.summary.title"),
                scoreText: String(
                    format: String(localized: "soundDetective.summary.score"),
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

        let viewModel = SoundDetectiveModels.Answer.ViewModel(
            feedback: response.feedback,
            lyalyaLine: lyalyaLine,
            correctZone: response.correctZone,
            highlightSoundIndex: response.highlightSoundIndex,
            replayWithEmphasis: response.replayWithEmphasis,
            hintZone: response.showHint ? response.correctZone : nil,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: summary
        )
        await displayLogic?.displayAnswer(viewModel: viewModel)
    }

    // MARK: - Round building

    static func makeRoundVM(
        _ round: SoundDetectiveRound,
        index: Int,
        total: Int
    ) -> SoundDetectiveModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "soundDetective.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        return .init(
            id: round.id,
            imageAsset: round.item.imageAsset,
            wordText: round.item.word,
            promptLyalya: String(
                format: String(localized: "soundDetective.prompt"),
                round.item.targetSound
            ),
            zones: zones(for: round),
            audioWordId: round.item.id,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "soundDetective.round.a11y"),
                round.item.word,
                round.item.targetSound
            )
        )
    }

    /// Зоны-окошки в порядке доступности уровня.
    private static func zones(
        for round: SoundDetectiveRound
    ) -> [SoundDetectiveModels.Start.ZoneViewModel] {
        round.availableZones.map { zone in
            .init(
                id: zone,
                label: zoneLabel(zone),
                colorHint: colorHint(zone),
                accessibilityLabel: zoneAccessibilityLabel(zone)
            )
        }
    }

    static func zoneLabel(_ zone: SoundZone) -> String {
        switch zone {
        case .start:  return String(localized: "soundDetective.zone.start")
        case .middle: return String(localized: "soundDetective.zone.middle")
        case .end:    return String(localized: "soundDetective.zone.end")
        case .absent: return String(localized: "soundDetective.zone.absent")
        }
    }

    static func zoneAccessibilityLabel(_ zone: SoundZone) -> String {
        switch zone {
        case .start:  return String(localized: "soundDetective.zone.start.a11y")
        case .middle: return String(localized: "soundDetective.zone.middle.a11y")
        case .end:    return String(localized: "soundDetective.zone.end.a11y")
        case .absent: return String(localized: "soundDetective.zone.absent.a11y")
        }
    }

    static func colorHint(_ zone: SoundZone) -> SoundDetectiveModels.Start.ZoneColorHint {
        switch zone {
        case .start:  return .start
        case .middle: return .middle
        case .end:    return .end
        case .absent: return .absent
        }
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func feedbackLine(tier: FeedbackTier, correctZone: SoundZone) -> String {
        switch tier {
        case .hit:
            // На попадание называем зону — закрепляем результат анализа.
            return String(
                format: String(localized: "soundDetective.feedback.hit"),
                zoneLabel(correctZone)
            )
        case .almost:
            return String(localized: "soundDetective.feedback.almost")
        case .retry:
            // Подсказка: мягко показываем верную зону.
            return String(
                format: String(localized: "soundDetective.feedback.retry"),
                zoneLabel(correctZone)
            )
        }
    }

    // MARK: - Helpers

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "soundDetective.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "soundDetective.encourage.good")
        } else {
            return String(localized: "soundDetective.encourage.keepGoing")
        }
    }
}
