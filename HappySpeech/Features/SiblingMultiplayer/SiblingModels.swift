import Foundation
import MultipeerConnectivity

// MARK: - SiblingModels
//
// VIP envelope types для модуля «Игра вдвоём» (Sibling Multiplayer).
// Все три экрана (Discovery, Lobby, Game) используют единый пространство имён.

enum SiblingModels {

    // MARK: - Discovery

    enum Discovery {
        struct Request {}
        struct Response {
            var peers: [MCPeerID]
        }
        struct ViewModel {
            var peers: [SiblingPeerViewModel]
            var isSearching: Bool
        }
    }

    enum InvitePeer {
        struct Request {
            var peerID: MCPeerID
        }
        struct Response {
            var peerID: MCPeerID
        }
        struct ViewModel {
            var peerID: MCPeerID
        }
    }

    // MARK: - Lobby

    enum LobbyLoad {
        struct Request {
            var peerID: MCPeerID
            var localDisplayName: String
        }
        struct Response {
            var localDisplayName: String
            var peerDisplayName: String
        }
        struct ViewModel {
            var localDisplayName: String
            var peerDisplayName: String
        }
    }

    enum ReadyState {
        struct Request {
            var isReady: Bool
        }
        struct Response {
            var localReady: Bool
            var peerReady: Bool
        }
        struct ViewModel {
            var localReady: Bool
            var peerReady: Bool
            var shouldStartGame: Bool
        }
    }

    enum LobbyTimeout {
        struct Request {}
        struct Response {}
        struct ViewModel {
            var errorMessage: String
        }
    }

    // MARK: - Game

    enum GameLoad {
        struct Request {
            var childId: String
            var peerDisplayName: String
        }
        struct Response {
            var words: [String]
            var peerDisplayName: String
            var totalRounds: Int
        }
        struct ViewModel {
            var words: [String]
            var peerDisplayName: String
            var totalRounds: Int
        }
    }

    enum RoundStart {
        struct Request {
            var roundIndex: Int
        }
        struct Response {
            var roundIndex: Int
            var word: String
            var totalRounds: Int
        }
        struct ViewModel {
            var roundIndex: Int
            var word: String
            var totalRounds: Int
            var roundLabel: String
        }
    }

    enum ScoreUpdate {
        struct Request {
            var ourScore: Float
            var peerScore: Float
            var roundIndex: Int
        }
        struct Response {
            var ourRoundResult: Float
            var peerRoundResult: Float
            var ourTotalPoints: Int
            var peerTotalPoints: Int
        }
        struct ViewModel {
            var ourRoundResult: Float
            var peerRoundResult: Float
            var ourTotalPoints: Int
            var peerTotalPoints: Int
        }
    }

    enum RoundResult {
        struct Request {
            var winnerPeerID: String?
        }
        struct Response {
            var winnerName: String?
        }
        struct ViewModel {
            var winnerName: String?
            var isOurWin: Bool
            var resultLabel: String
        }
    }

    enum GameResult {
        struct Request {
            var finalScores: [String: Int]
        }
        struct Response {
            var winnerName: String?
            var ourFinalScore: Int
            var peerFinalScore: Int
        }
        struct ViewModel {
            var winnerName: String?
            var ourFinalScore: Int
            var peerFinalScore: Int
            var isOurWin: Bool
            var isTie: Bool
            var resultTitle: String
        }
    }
}

// MARK: - SiblingPeerViewModel

struct SiblingPeerViewModel: Identifiable, Equatable {
    let id: String
    let displayName: String
    let peerID: MCPeerID

    static func == (lhs: SiblingPeerViewModel, rhs: SiblingPeerViewModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - RoundPhase

enum RoundPhase: Equatable {
    case idle
    case playing
    case listening
    case result(winnerName: String?)
    case gameOver(winnerName: String?)
}

// MARK: - SiblingGameDisplay

@Observable
@MainActor
final class SiblingGameDisplay {
    var currentWord: String = ""
    var roundIndex: Int = 1
    var totalRounds: Int = 5
    var ourScore: Int = 0
    var peerScore: Int = 0
    var ourRoundResult: Float = 0.0
    var peerRoundResult: Float = 0.0
    var isListening: Bool = false
    var roundPhase: RoundPhase = .idle
    var winnerName: String?
    var peerDisplayName: String = ""
    var localDisplayName: String = ""
    var roundLabel: String = ""
}
