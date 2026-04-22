import CoreGraphics
import Foundation

// MARK: - ButterflyCatch VIP Models

enum ButterflyCatchModels {

    /// Направление полёта бабочки — ребёнок "ловит" её открытием рта в нужной точке.
    enum Direction: String, CaseIterable, Sendable { case left, right, up, down }

    struct Butterfly: Sendable, Identifiable, Hashable {
        let id: UUID
        let position: CGPoint           // нормализованное 0…1
        let direction: Direction
        let targetPosture: ArticulationPosture
    }

    // MARK: - StartGame
    enum StartGame {
        struct Request { let durationSec: Int }
        struct Response { let totalButterflies: Int; let durationSec: Int }
        struct ViewModel { let totalButterflies: Int; let timeLeftText: String }
    }

    // MARK: - SpawnButterfly
    enum SpawnButterfly {
        struct Request {}
        struct Response { let butterfly: Butterfly }
        struct ViewModel { let butterfly: Butterfly }
    }

    // MARK: - ScoreAttempt
    enum ScoreAttempt {
        struct Request {
            let butterflyId: UUID
            let blendshapes: FaceBlendshapes
        }
        struct Response { let caught: Bool; let totalCaught: Int }
        struct ViewModel { let caught: Bool; let scoreText: String }
    }
}
