import Foundation

// MARK: - OfflineMiniGame VIP Models

enum OfflineMiniGameModels {

    // MARK: - Game Type

    enum GameType: String, CaseIterable, Sendable {
        case tapLyalya
        case dragClouds
        case findPair
    }

    // MARK: - StartGame

    enum StartGame {
        struct Request {
            let gameType: GameType
        }
        struct Response {
            let gameType: GameType
            let durationSeconds: Int
        }
        struct ViewModel {
            let gameType: GameType
            let durationSeconds: Int
            let titleKey: String
            let instructionKey: String
        }
    }

    // MARK: - FinishGame

    enum FinishGame {
        struct Request {
            let gameType: GameType
            let rawScore: Int
        }
        struct Response {
            let gameType: GameType
            let rawScore: Int
            let displayScore: String
        }
        struct ViewModel {
            let displayScore: String
            let congratsText: String
        }
    }
}
