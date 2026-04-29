import Foundation
import OSLog

// MARK: - OfflineMiniGameBusinessLogic

@MainActor
protocol OfflineMiniGameBusinessLogic: AnyObject {
    func startGame(_ request: OfflineMiniGameModels.StartGame.Request) async
    func finishGame(_ request: OfflineMiniGameModels.FinishGame.Request) async
}

// MARK: - OfflineMiniGamePresentationLogic

@MainActor
protocol OfflineMiniGamePresentationLogic: AnyObject {
    func presentStartGame(_ response: OfflineMiniGameModels.StartGame.Response)
    func presentFinishGame(_ response: OfflineMiniGameModels.FinishGame.Response)
}

// MARK: - OfflineMiniGameDisplayLogic

@MainActor
protocol OfflineMiniGameDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: OfflineMiniGameModels.StartGame.ViewModel)
    func displayFinishGame(_ viewModel: OfflineMiniGameModels.FinishGame.ViewModel)
}

// MARK: - OfflineMiniGameInteractor

@MainActor
final class OfflineMiniGameInteractor: OfflineMiniGameBusinessLogic {

    var presenter: (any OfflineMiniGamePresentationLogic)?

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "OfflineMiniGame")

    func startGame(_ request: OfflineMiniGameModels.StartGame.Request) async {
        Self.logger.debug("startGame: \(request.gameType.rawValue)")
        let duration: Int = switch request.gameType {
        case .tapLyalya: 5
        case .dragClouds: 20
        case .findPair: 60
        }
        let response = OfflineMiniGameModels.StartGame.Response(
            gameType: request.gameType,
            durationSeconds: duration
        )
        presenter?.presentStartGame(response)
    }

    func finishGame(_ request: OfflineMiniGameModels.FinishGame.Request) async {
        Self.logger.debug("finishGame: score=\(request.rawScore) type=\(request.gameType.rawValue)")
        let display = String(format: String(localized: "offline.minigame.score.format"), request.rawScore)
        let response = OfflineMiniGameModels.FinishGame.Response(
            gameType: request.gameType,
            rawScore: request.rawScore,
            displayScore: display
        )
        presenter?.presentFinishGame(response)
    }
}

// MARK: - OfflineMiniGamePresenter

@MainActor
final class OfflineMiniGamePresenter: OfflineMiniGamePresentationLogic {

    weak var viewModel: (any OfflineMiniGameDisplayLogic)?

    func presentStartGame(_ response: OfflineMiniGameModels.StartGame.Response) {
        let (titleKey, instrKey): (String, String) = switch response.gameType {
        case .tapLyalya:  ("offline.minigame.tap.title", "offline.minigame.tap.instruction")
        case .dragClouds: ("offline.minigame.drag.title", "offline.minigame.drag.instruction")
        case .findPair:   ("offline.minigame.pair.title", "offline.minigame.pair.instruction")
        }
        let vm = OfflineMiniGameModels.StartGame.ViewModel(
            gameType: response.gameType,
            durationSeconds: response.durationSeconds,
            titleKey: titleKey,
            instructionKey: instrKey
        )
        viewModel?.displayStartGame(vm)
    }

    func presentFinishGame(_ response: OfflineMiniGameModels.FinishGame.Response) {
        let congrats: String = switch response.gameType {
        case .tapLyalya  where response.rawScore >= 10: String(localized: "offline.minigame.congrats.great")
        case .dragClouds where response.rawScore >= 5:  String(localized: "offline.minigame.congrats.great")
        case .findPair   where response.rawScore <= 30: String(localized: "offline.minigame.congrats.great")
        default: String(localized: "offline.minigame.congrats.good")
        }
        let vm = OfflineMiniGameModels.FinishGame.ViewModel(
            displayScore: response.displayScore,
            congratsText: congrats
        )
        viewModel?.displayFinishGame(vm)
    }
}
