import ARKit
import Foundation
import OSLog

// MARK: - ARZoneBusinessLogic

@MainActor
protocol ARZoneBusinessLogic: AnyObject {
    func loadGames(_ request: ARZoneModels.LoadGames.Request)
    func selectGame(_ request: ARZoneModels.SelectGame.Request)
}

// MARK: - ARZoneInteractor

@MainActor
final class ARZoneInteractor: ARZoneBusinessLogic {

    var presenter: (any ARZonePresentationLogic)?

    // MARK: - loadGames

    func loadGames(_ request: ARZoneModels.LoadGames.Request) {
        let games = ARGameCatalog.all
        let instructions = InstructionCatalog.seeds
        let response = ARZoneModels.LoadGames.Response(
            games: games,
            instructions: instructions
        )
        presenter?.presentLoadGames(response)
        HSLogger.ar.debug("ARZone loaded \(games.count) games, \(instructions.count) steps")
    }

    // MARK: - selectGame

    func selectGame(_ request: ARZoneModels.SelectGame.Request) {
        guard let game = ARGameCatalog.game(id: request.gameId) else {
            HSLogger.ar.error("Unknown AR game id: \(request.gameId)")
            return
        }
        presenter?.presentSelectGame(ARZoneModels.SelectGame.Response(game: game))
    }
}
