import Foundation

// MARK: - SiblingMessage
//
// Типы сообщений, передаваемых между устройствами через MultipeerConnectivity.
// Кодируется в JSON через JSONEncoder, передаётся как Data в MCSession.send(.reliable).
//
// Все сообщения — только между устройствами в LAN, никакого облака (COPPA-compliant).

enum SiblingMessage: Codable, Sendable {

    /// Ребёнок нажал «Я готов» в лобби.
    case readyState(isReady: Bool)

    /// Хост начинает раунд — отправляет слово и номер раунда.
    case roundStart(word: String, roundIndex: Int)

    /// Устройство отправляет свой PronunciationScorer score за текущий раунд.
    case scoreUpdate(score: Float, roundIndex: Int)

    /// Итог раунда: ID победителя (displayName) или nil = ничья.
    case roundResult(winnerPeerID: String?)

    /// Итог всей игры: финальные очки по displayName.
    case gameResult(finalScores: [String: Int])

    /// Экстренный разрыв соединения (ребёнок вышел из игры).
    case disconnect

    // MARK: - Codable (manual для associated values)

    private enum CodingKeys: String, CodingKey {
        case type, isReady, word, roundIndex, score, winnerPeerID, finalScores
    }

    private enum MessageType: String, Codable {
        case readyState, roundStart, scoreUpdate, roundResult, gameResult, disconnect
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .readyState:
            let isReady = try container.decode(Bool.self, forKey: .isReady)
            self = .readyState(isReady: isReady)
        case .roundStart:
            let word = try container.decode(String.self, forKey: .word)
            let roundIndex = try container.decode(Int.self, forKey: .roundIndex)
            self = .roundStart(word: word, roundIndex: roundIndex)
        case .scoreUpdate:
            let score = try container.decode(Float.self, forKey: .score)
            let roundIndex = try container.decode(Int.self, forKey: .roundIndex)
            self = .scoreUpdate(score: score, roundIndex: roundIndex)
        case .roundResult:
            let winnerPeerID = try container.decodeIfPresent(String.self, forKey: .winnerPeerID)
            self = .roundResult(winnerPeerID: winnerPeerID)
        case .gameResult:
            let finalScores = try container.decode([String: Int].self, forKey: .finalScores)
            self = .gameResult(finalScores: finalScores)
        case .disconnect:
            self = .disconnect
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .readyState(let isReady):
            try container.encode(MessageType.readyState, forKey: .type)
            try container.encode(isReady, forKey: .isReady)
        case .roundStart(let word, let roundIndex):
            try container.encode(MessageType.roundStart, forKey: .type)
            try container.encode(word, forKey: .word)
            try container.encode(roundIndex, forKey: .roundIndex)
        case .scoreUpdate(let score, let roundIndex):
            try container.encode(MessageType.scoreUpdate, forKey: .type)
            try container.encode(score, forKey: .score)
            try container.encode(roundIndex, forKey: .roundIndex)
        case .roundResult(let winnerPeerID):
            try container.encode(MessageType.roundResult, forKey: .type)
            try container.encodeIfPresent(winnerPeerID, forKey: .winnerPeerID)
        case .gameResult(let finalScores):
            try container.encode(MessageType.gameResult, forKey: .type)
            try container.encode(finalScores, forKey: .finalScores)
        case .disconnect:
            try container.encode(MessageType.disconnect, forKey: .type)
        }
    }
}
