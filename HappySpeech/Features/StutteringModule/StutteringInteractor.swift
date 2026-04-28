import Foundation
import OSLog

// MARK: - StutteringBusinessLogic

@MainActor
protocol StutteringBusinessLogic: AnyObject {
    func loadScreen(_ request: StutteringModels.LoadScreen.Request)
    func selectMode(_ request: StutteringModels.SelectMode.Request)
}

// MARK: - StutteringInteractor

@MainActor
final class StutteringInteractor: StutteringBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any StutteringPresentationLogic)?

    private let logger = HSLogger.ui

    // MARK: - Defaults key

    private let welcomeSeenKey = "stuttering_welcome_shown"

    // MARK: - LoadScreen

    func loadScreen(_ request: StutteringModels.LoadScreen.Request) {
        let cards: [ExerciseCardData] = [
            ExerciseCardData(
                mode: .metronome,
                titleKey: "stuttering.exercise.metronome.title",
                subtitleKey: "stuttering.exercise.metronome.subtitle",
                symbol: "metronome",
                symbolColor: .primary,
                duration: "~5 мин"
            ),
            ExerciseCardData(
                mode: .breathing,
                titleKey: "stuttering.exercise.breathing.title",
                subtitleKey: "stuttering.exercise.breathing.subtitle",
                symbol: "leaf.fill",
                symbolColor: .mint,
                duration: "~3 мин"
            ),
            ExerciseCardData(
                mode: .softOnset,
                titleKey: "stuttering.exercise.soft_start.title",
                subtitleKey: "stuttering.exercise.soft_start.subtitle",
                symbol: "light.beacon.max",
                symbolColor: .butter,
                duration: "~5 мин"
            ),
            ExerciseCardData(
                mode: .diary,
                titleKey: "stuttering.exercise.diary.title",
                subtitleKey: "stuttering.exercise.diary.subtitle",
                symbol: "book.fill",
                symbolColor: .sky,
                duration: "~1 мин"
            )
        ]
        let hasSeenWelcome = UserDefaults.standard.bool(forKey: welcomeSeenKey)
        let response = StutteringModels.LoadScreen.Response(
            cards: cards,
            hasSeenWelcome: hasSeenWelcome
        )
        presenter?.presentLoadScreen(response)
        logger.info("StutteringInteractor: loadScreen hasSeenWelcome=\(hasSeenWelcome, privacy: .public)")
    }

    // MARK: - SelectMode

    func selectMode(_ request: StutteringModels.SelectMode.Request) {
        logger.info("StutteringInteractor: selectMode=\(request.mode.rawValue, privacy: .public)")
        presenter?.presentSelectMode(.init(mode: request.mode))
    }

    // MARK: - Welcome dismiss

    func markWelcomeSeen() {
        UserDefaults.standard.set(true, forKey: welcomeSeenKey)
        logger.info("StutteringInteractor: welcome marked seen")
    }
}
