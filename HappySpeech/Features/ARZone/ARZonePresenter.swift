import ARKit
import Foundation

// MARK: - ARZonePresentationLogic

@MainActor
protocol ARZonePresentationLogic: AnyObject {
    func presentLoadGames(_ response: ARZoneModels.LoadGames.Response)
    func presentSelectGame(_ response: ARZoneModels.SelectGame.Response)
}

// MARK: - ARZonePresenter

@MainActor
final class ARZonePresenter: ARZonePresentationLogic {

    weak var viewModel: (any ARZoneDisplayLogic)?

    func presentLoadGames(_ response: ARZoneModels.LoadGames.Response) {
        let cards = response.games.enumerated().map { index, game in
            ARGameCard(
                id: game.id,
                title: String(localized: String.LocalizationValue(game.nameKey)),
                subtitle: String(localized: String.LocalizationValue(game.descriptionKey)),
                iconName: game.iconName,
                difficulty: game.difficulty,
                estimatedMinutes: game.estimatedMinutes,
                accentColorIndex: index,
                destination: game.destination
            )
        }
        let vm = ARZoneModels.LoadGames.ViewModel(
            cards: cards,
            isARSupported: ARFaceTrackingConfiguration.isSupported
        )
        viewModel?.displayLoadGames(vm)
    }

    func presentSelectGame(_ response: ARZoneModels.SelectGame.Response) {
        let vm = ARZoneModels.SelectGame.ViewModel(destination: response.game.destination)
        viewModel?.displaySelectGame(vm)
    }
}
