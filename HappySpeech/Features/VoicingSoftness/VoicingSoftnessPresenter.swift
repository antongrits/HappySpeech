import Foundation
import OSLog

// MARK: - VoicingSoftnessPresentationLogic

@MainActor
protocol VoicingSoftnessPresentationLogic: AnyObject {
    func presentStart(response: VoicingSoftnessModels.Start.Response) async
    func presentAnswer(response: VoicingSoftnessModels.Answer.Response) async
}

// MARK: - VoicingSoftnessPresenter (Clean Swift: Presenter)
//
// «Карта звонкости и мягкости».
//
// Строит игровые ViewModel: вопрос Ляли, зоны-домики (звонкий/глухой,
// сердитый/ласковый брат), картинки минимальной пары, тёплую обратную связь
// по «светофору» (без «неправильно») и сводку. Все строки — String(localized:).

@MainActor
final class VoicingSoftnessPresenter: VoicingSoftnessPresentationLogic {

    weak var displayLogic: (any VoicingSoftnessDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VoicingSoftness.Presenter"
    )

    init(displayLogic: (any VoicingSoftnessDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: VoicingSoftnessModels.Start.Response) async {
        let total = response.mode == .trapWords
            ? response.trapRounds.count
            : response.sortRounds.count

        let firstSort: VoicingSoftnessModels.Start.SortRoundViewModel?
        let firstTrap: VoicingSoftnessModels.Start.TrapRoundViewModel?

        switch response.mode {
        case .voicing, .softness:
            guard let item = response.sortRounds.first else {
                Self.logger.error("Start with empty sort rounds")
                return
            }
            firstSort = Self.makeSortVM(item, mode: response.mode, index: 0, total: total)
            firstTrap = nil
        case .trapWords:
            guard let round = response.trapRounds.first else {
                Self.logger.error("Start with empty trap rounds")
                return
            }
            firstSort = nil
            firstTrap = Self.makeTrapVM(round, index: 0, total: total)
        }

        let viewModel = VoicingSoftnessModels.Start.ViewModel(
            mode: response.mode,
            title: Self.title(for: response.mode),
            subtitle: Self.subtitle(for: response.mode),
            totalRounds: total,
            firstSort: firstSort,
            firstTrap: firstTrap
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: VoicingSoftnessModels.Answer.Response) async {
        let lyalyaLine = Self.feedbackLine(response: response)
        let throatHint = response.showThroatHint ? Self.throatHint(response: response) : nil

        let total = response.totalRounds
        let nextSort = response.nextSort.flatMap { item -> VoicingSoftnessModels.Start.SortRoundViewModel? in
            guard let index = response.nextRoundIndex else { return nil }
            return Self.makeSortVM(item, mode: response.mode, index: index, total: total)
        }
        let nextTrap = response.nextTrap.flatMap { round -> VoicingSoftnessModels.Start.TrapRoundViewModel? in
            guard let index = response.nextRoundIndex else { return nil }
            return Self.makeTrapVM(round, index: index, total: total)
        }

        let summary: VoicingSoftnessModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = total > 0 ? Double(response.correctCount) / Double(total) : 0
            summary = .init(
                title: String(localized: "voicingSoftness.summary.title"),
                scoreText: String(
                    format: String(localized: "voicingSoftness.summary.score"),
                    response.correctCount, total
                ),
                correctCount: response.correctCount,
                totalRounds: total,
                accuracyFraction: accuracy,
                encouragement: Self.encouragement(for: accuracy),
                showCelebration: accuracy >= 0.8
            )
        } else {
            summary = nil
        }

        let viewModel = VoicingSoftnessModels.Answer.ViewModel(
            feedback: response.feedback,
            lyalyaLine: lyalyaLine,
            correctZone: response.correctZone,
            correctOptionId: response.correctOptionId,
            throatHint: throatHint,
            triggerVoicedHaptic: response.triggerVoicedHaptic,
            replayWithEmphasis: response.replayWithEmphasis,
            isFinished: response.isFinished,
            nextSort: nextSort,
            nextTrap: nextTrap,
            summary: summary
        )
        await displayLogic?.displayAnswer(viewModel: viewModel)
    }

    // MARK: - Sort round building

    static func makeSortVM(
        _ item: VoicingSoftnessItem,
        mode: VoicingSoftnessMode,
        index: Int,
        total: Int
    ) -> VoicingSoftnessModels.Start.SortRoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "voicingSoftness.progress"),
            humanIndex, total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        let prompt = mode == .voicing
            ? String(localized: "voicingSoftness.voicing.prompt")
            : String(localized: "voicingSoftness.softness.prompt")

        return .init(
            id: item.id,
            token: item.token,
            promptLyalya: prompt,
            zones: zones(for: mode),
            audioId: item.audioId,
            progressLabel: progressLabel,
            progressFraction: fraction,
            isVoiced: item.isVoiced,
            tokenAccessibilityLabel: String(
                format: String(localized: "voicingSoftness.token.a11y"),
                item.token
            )
        )
    }

    static func zones(for mode: VoicingSoftnessMode) -> [VoicingSoftnessModels.Start.ZoneViewModel] {
        VoicingZone.zones(for: mode).map { zone in
            .init(
                id: zone,
                title: zoneTitle(zone),
                desc: zoneDesc(zone),
                emoji: zoneEmoji(zone),
                accessibilityLabel: zoneAccessibility(zone)
            )
        }
    }

    static func zoneTitle(_ zone: VoicingZone) -> String {
        switch zone {
        case .voiced:    return String(localized: "voicingSoftness.zone.voiced")
        case .voiceless: return String(localized: "voicingSoftness.zone.voiceless")
        case .hard:      return String(localized: "voicingSoftness.zone.hard")
        case .soft:      return String(localized: "voicingSoftness.zone.soft")
        }
    }

    static func zoneDesc(_ zone: VoicingZone) -> String {
        switch zone {
        case .voiced:    return String(localized: "voicingSoftness.zone.voiced.desc")
        case .voiceless: return String(localized: "voicingSoftness.zone.voiceless.desc")
        case .hard:      return String(localized: "voicingSoftness.zone.hard.desc")
        case .soft:      return String(localized: "voicingSoftness.zone.soft.desc")
        }
    }

    /// Эмодзи-горлышко/брат (метафора, дублирует SF Symbol во View для a11y).
    static func zoneEmoji(_ zone: VoicingZone) -> String {
        switch zone {
        case .voiced:    return "😮"
        case .voiceless: return "😐"
        case .hard:      return "😠"
        case .soft:      return "☺️"
        }
    }

    static func zoneAccessibility(_ zone: VoicingZone) -> String {
        switch zone {
        case .voiced:    return String(localized: "voicingSoftness.zone.voiced.a11y")
        case .voiceless: return String(localized: "voicingSoftness.zone.voiceless.a11y")
        case .hard:      return String(localized: "voicingSoftness.zone.hard.a11y")
        case .soft:      return String(localized: "voicingSoftness.zone.soft.a11y")
        }
    }

    // MARK: - Trap round building

    static func makeTrapVM(
        _ round: VoicingSoftnessTrapRound,
        index: Int,
        total: Int
    ) -> VoicingSoftnessModels.Start.TrapRoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "voicingSoftness.progress"),
            humanIndex, total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        let options = round.options.map { opt -> VoicingSoftnessModels.Start.TrapOptionViewModel in
            .init(
                id: opt.id,
                word: opt.word,
                imageAsset: opt.imageAsset,
                diffLetter: VoicingSoftnessPackLoader.letter(in: opt.word, at: opt.diffIndex),
                diffIndex: opt.diffIndex,
                accessibilityLabel: opt.word
            )
        }

        return .init(
            id: round.id,
            promptLyalya: String(
                format: String(localized: "voicingSoftness.trap.prompt"),
                round.targetWord
            ),
            targetWord: round.targetWord,
            options: options,
            progressLabel: progressLabel,
            progressFraction: fraction
        )
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func feedbackLine(response: VoicingSoftnessModels.Answer.Response) -> String {
        switch response.feedback {
        case .hit:
            if response.triggerVoicedHaptic {
                return String(localized: "voicingSoftness.feedback.hit.voiced")
            }
            return String(localized: "voicingSoftness.feedback.hit")
        case .almost:
            return String(localized: "voicingSoftness.feedback.almost")
        case .retry:
            return String(localized: "voicingSoftness.feedback.retry")
        }
    }

    /// Подсказка «потрогай горлышко» — мягкая коррекция, опора на работу голоса.
    static func throatHint(response: VoicingSoftnessModels.Answer.Response) -> String {
        if response.mode == .trapWords, let letter = response.trapDiffLetter {
            if response.trapTargetIsVoicedOrSoft {
                return String(
                    format: String(localized: "voicingSoftness.throat.trap.voiced"),
                    letter.uppercased()
                )
            }
            return String(
                format: String(localized: "voicingSoftness.throat.trap.voiceless"),
                letter.uppercased()
            )
        }
        switch response.mode {
        case .softness:
            return String(localized: "voicingSoftness.throat.softness")
        case .voicing, .trapWords:
            return String(localized: "voicingSoftness.throat.voicing")
        }
    }

    // MARK: - Headers

    static func title(for mode: VoicingSoftnessMode) -> String {
        switch mode {
        case .voicing:   return String(localized: "voicingSoftness.voicing.title")
        case .softness:  return String(localized: "voicingSoftness.softness.title")
        case .trapWords: return String(localized: "voicingSoftness.trap.title")
        }
    }

    static func subtitle(for mode: VoicingSoftnessMode) -> String {
        switch mode {
        case .voicing:   return String(localized: "voicingSoftness.voicing.subtitle")
        case .softness:  return String(localized: "voicingSoftness.softness.subtitle")
        case .trapWords: return String(localized: "voicingSoftness.trap.subtitle")
        }
    }

    // MARK: - Helpers

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "voicingSoftness.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "voicingSoftness.encourage.good")
        } else {
            return String(localized: "voicingSoftness.encourage.keepGoing")
        }
    }
}
