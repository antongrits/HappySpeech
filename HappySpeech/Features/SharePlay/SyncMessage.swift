import Foundation

// MARK: - SyncMessage
//
// Codable + Sendable сообщение для GroupSessionMessenger.
// COPPA: нет PII детей — только игровое состояние (roundIndex, score, soundId).
// senderId = UIDevice.identifierForVendor (не имя, не email).

struct SyncMessage: Codable, Sendable, Equatable {

    // MARK: - Kind

    enum Kind: Codable, Sendable, Equatable {
        /// Ведущий объявляет начало раунда.
        case roundStart(roundIndex: Int, soundId: String)
        /// Участник завершил раунд с результатом.
        case roundComplete(roundIndex: Int, score: Double)
        /// Участник ответил на вопрос.
        case childAnswer(roundIndex: Int, answer: String, isCorrect: Bool)
        /// Просьба синхронизировать анимацию Ляли.
        case lyalyaCelebration(intensity: String)
        /// Сессия завершена — финальный счёт.
        case sessionComplete(totalScore: Double)
        /// Участник готов (heartbeat при входе в сессию).
        case participantReady
    }

    let kind: Kind
    /// Unix-timestamp момента отправки.
    let timestamp: TimeInterval
    /// UIDevice.identifierForVendor — не содержит имени или email.
    let senderId: String

    // MARK: - Factory

    static func roundStart(roundIndex: Int, soundId: String, senderId: String) -> SyncMessage {
        SyncMessage(
            kind: .roundStart(roundIndex: roundIndex, soundId: soundId),
            timestamp: Date().timeIntervalSince1970,
            senderId: senderId
        )
    }

    static func roundComplete(roundIndex: Int, score: Double, senderId: String) -> SyncMessage {
        SyncMessage(
            kind: .roundComplete(roundIndex: roundIndex, score: score),
            timestamp: Date().timeIntervalSince1970,
            senderId: senderId
        )
    }

    static func childAnswer(
        roundIndex: Int,
        answer: String,
        isCorrect: Bool,
        senderId: String
    ) -> SyncMessage {
        SyncMessage(
            kind: .childAnswer(roundIndex: roundIndex, answer: answer, isCorrect: isCorrect),
            timestamp: Date().timeIntervalSince1970,
            senderId: senderId
        )
    }

    static func lyalyaCelebration(intensity: String, senderId: String) -> SyncMessage {
        SyncMessage(
            kind: .lyalyaCelebration(intensity: intensity),
            timestamp: Date().timeIntervalSince1970,
            senderId: senderId
        )
    }

    static func sessionComplete(totalScore: Double, senderId: String) -> SyncMessage {
        SyncMessage(
            kind: .sessionComplete(totalScore: totalScore),
            timestamp: Date().timeIntervalSince1970,
            senderId: senderId
        )
    }

    static func participantReady(senderId: String) -> SyncMessage {
        SyncMessage(
            kind: .participantReady,
            timestamp: Date().timeIntervalSince1970,
            senderId: senderId
        )
    }
}
