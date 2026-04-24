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

        let steps = response.instructions.map { seed in
            InstructionStep(
                id: seed.id,
                number: seed.number,
                title: String(localized: String.LocalizationValue(seed.titleKey)),
                body: String(localized: String.LocalizationValue(seed.bodyKey)),
                icon: seed.icon,
                tintIndex: seed.tintIndex
            )
        }

        let isSupported = ARFaceTrackingConfiguration.isSupported
        let phase: ARZonePhase = isSupported ? .ready : .unsupported
        // Приветственное состояние маскота — на входе машет ребёнку лапой.
        let mascotState: LyalyaAnimation = isSupported ? .waving : .sad

        let vm = ARZoneModels.LoadGames.ViewModel(
            cards: cards,
            instructionSteps: steps,
            mascotState: mascotState,
            phase: phase,
            isARSupported: isSupported
        )
        viewModel?.displayLoadGames(vm)
    }

    func presentSelectGame(_ response: ARZoneModels.SelectGame.Response) {
        let vm = ARZoneModels.SelectGame.ViewModel(destination: response.game.destination)
        viewModel?.displaySelectGame(vm)
    }
}
