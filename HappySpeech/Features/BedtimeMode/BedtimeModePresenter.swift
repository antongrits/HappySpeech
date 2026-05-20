import Foundation
import OSLog

// MARK: - BedtimeModePresentationLogic

@MainActor
protocol BedtimeModePresentationLogic: AnyObject {
    func presentStart(response: BedtimeModeModels.Start.Response) async
    func presentAdvance(stage: BedtimeStage) async
    func presentNewStory(response: BedtimeModeModels.Start.Response) async
}

// MARK: - BedtimeModePresenter (Clean Swift: Presenter)
//
// v31 Волна B, Функция Ф.3 «Bedtime mode».

@MainActor
final class BedtimeModePresenter: BedtimeModePresentationLogic {

    weak var displayLogic: (any BedtimeModeDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BedtimeMode.Presenter"
    )

    init(displayLogic: (any BedtimeModeDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentStart(response: BedtimeModeModels.Start.Response) async {
        let viewModel = Self.makeViewModel(response: response)
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    func presentAdvance(stage: BedtimeStage) async {
        await displayLogic?.displayAdvance(stage: stage)
    }

    func presentNewStory(response: BedtimeModeModels.Start.Response) async {
        let viewModel = Self.makeViewModel(response: response)
        await displayLogic?.displayNewStory(viewModel: viewModel)
    }

    // MARK: - Helpers

    static func makeViewModel(
        response: BedtimeModeModels.Start.Response
    ) -> BedtimeModeModels.Start.ViewModel {
        let countLabel = String(
            format: String(localized: "bedtime.library.count"),
            response.storiesCountInLibrary
        )
        return .init(
            title: String(localized: "bedtime.title"),
            introMessage: String(localized: "bedtime.intro"),
            breathingTitle: String(localized: "bedtime.breathing.title"),
            breathingHint: String(localized: "bedtime.breathing.hint"),
            storyTitle: response.story.title,
            storyText: response.story.text,
            farewell: String(localized: "bedtime.farewell"),
            breathing: response.breathing,
            storiesCountLabel: countLabel
        )
    }
}
