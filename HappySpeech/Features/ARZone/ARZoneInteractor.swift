import ARKit
import Foundation
import OSLog

// MARK: - ARZoneBusinessLogic

@MainActor
protocol ARZoneBusinessLogic: AnyObject {
    func loadGames(_ request: ARZoneModels.LoadGames.Request)
    func selectGame(_ request: ARZoneModels.SelectGame.Request)
    func selectFallback(_ request: ARZoneModels.SelectFallback.Request)
}

// MARK: - ARZoneInteractor

@MainActor
final class ARZoneInteractor: ARZoneBusinessLogic {

    var presenter: (any ARZonePresentationLogic)?

    // MARK: - loadGames

    func loadGames(_ request: ARZoneModels.LoadGames.Request) {
        let games = ARGameCatalog.all
        let instructions = InstructionCatalog.seeds
        let tips = InstructionCatalog.tipSeeds
        let response = ARZoneModels.LoadGames.Response(
            games: games,
            instructions: instructions,
            tips: tips
        )
        presenter?.presentLoadGames(response)
        HSLogger.ar.debug(
            "ARZone loaded \(games.count) games, \(instructions.count) steps, \(tips.count) tips"
        )
    }

    // MARK: - selectGame

    func selectGame(_ request: ARZoneModels.SelectGame.Request) {
        guard let game = ARGameCatalog.game(id: request.gameId) else {
            HSLogger.ar.error("Unknown AR game id: \(request.gameId)")
            return
        }
        presenter?.presentSelectGame(ARZoneModels.SelectGame.Response(game: game))
    }

    // MARK: - selectFallback

    /// Пользователь нажал «Открыть 2D-альтернативу» на устройстве без TrueDepth.
    func selectFallback(_ request: ARZoneModels.SelectFallback.Request) {
        HSLogger.ar.info("ARZone fallback CTA tapped — routing back to map.")
        presenter?.presentSelectFallback(ARZoneModels.SelectFallback.Response())
    }
}
