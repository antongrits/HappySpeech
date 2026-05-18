import Foundation
import OSLog

// MARK: - RetellingPresentationLogic

@MainActor
protocol RetellingPresentationLogic: AnyObject {
    func presentStart(response: RetellingModels.Start.Response) async
    func presentToggle(response: RetellingModels.ToggleLink.Response) async
    func presentFinish(response: RetellingModels.Finish.Response) async
}

// MARK: - RetellingPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему».
//
// Строит ViewModel истории, кадров-опор, покрытия смысловых звеньев и
// итоговой сводки с наводящими вопросами. Все строки — String(localized:).

@MainActor
final class RetellingPresenter: RetellingPresentationLogic {

    weak var displayLogic: (any RetellingDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Retelling.Presenter"
    )

    init(displayLogic: (any RetellingDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: RetellingModels.Start.Response) async {
        let frames = response.story.frames.map { frame in
            RetellingModels.Start.FrameViewModel(
                id: frame.id,
                sentence: frame.sentence,
                symbolName: frame.symbolName,
                linkLabel: Self.linkLabel(frame.link),
                accessibilityLabel: String(
                    format: String(localized: "retelling.frame.a11y"),
                    Self.linkLabel(frame.link),
                    frame.sentence
                )
            )
        }
        let viewModel = RetellingModels.Start.ViewModel(
            title: String(localized: "retelling.title"),
            storyTitle: response.story.title,
            fullText: response.story.fullText,
            frames: frames,
            listenPrompt: String(localized: "retelling.listen.prompt")
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Toggle

    func presentToggle(response: RetellingModels.ToggleLink.Response) async {
        let fraction = response.totalFrames > 0
            ? Double(response.coveredFrameIds.count) / Double(response.totalFrames)
            : 0
        let viewModel = RetellingModels.ToggleLink.ViewModel(
            coveredFrameIds: response.coveredFrameIds,
            coverageLabel: String(
                format: String(localized: "retelling.coverage"),
                response.coveredFrameIds.count,
                response.totalFrames
            ),
            coverageFraction: fraction
        )
        await displayLogic?.displayToggle(viewModel: viewModel)
    }

    // MARK: - Finish

    func presentFinish(response: RetellingModels.Finish.Response) async {
        let fraction = response.totalFrames > 0
            ? Double(response.coveredCount) / Double(response.totalFrames)
            : 0
        let hints = response.missedLinks.map { Self.hint(for: $0) }
        let viewModel = RetellingModels.Finish.ViewModel(
            title: String(localized: "retelling.summary.title"),
            scoreText: String(
                format: String(localized: "retelling.summary.score"),
                response.coveredCount,
                response.totalFrames
            ),
            coverageFraction: fraction,
            hints: hints,
            encouragement: Self.encouragement(for: fraction)
        )
        await displayLogic?.displayFinish(viewModel: viewModel)
    }

    // MARK: - Helpers

    static func linkLabel(_ link: SemanticLinkKind) -> String {
        switch link {
        case .hero:     return String(localized: "retelling.link.hero")
        case .place:    return String(localized: "retelling.link.place")
        case .problem:  return String(localized: "retelling.link.problem")
        case .solution: return String(localized: "retelling.link.solution")
        }
    }

    /// Наводящий вопрос Ляли по пропущенному смысловому звену.
    static func hint(for link: SemanticLinkKind) -> String {
        switch link {
        case .hero:     return String(localized: "retelling.hint.hero")
        case .place:    return String(localized: "retelling.hint.place")
        case .problem:  return String(localized: "retelling.hint.problem")
        case .solution: return String(localized: "retelling.hint.solution")
        }
    }

    private static func encouragement(for fraction: Double) -> String {
        if fraction >= 0.75 {
            return String(localized: "retelling.encourage.great")
        } else if fraction >= 0.4 {
            return String(localized: "retelling.encourage.good")
        } else {
            return String(localized: "retelling.encourage.keepGoing")
        }
    }
}
