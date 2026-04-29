import ActivityKit
import Foundation

// MARK: - LessonSessionAttributes

/// ActivityKit-атрибуты урока для Live Activity и Dynamic Island.
/// COPPA: никаких личных данных ребёнка — только анонимный контент.
@available(iOS 16.1, *)
public struct LessonSessionAttributes: ActivityAttributes {

    public typealias ContentState = LessonSessionState

    /// Стабильный идентификатор сессии (UUID).
    public let sessionId: String

    /// Отображаемое название урока (например, «Звук С»).
    public let lessonTitle: String

    /// Идентификатор целевого звука (например, «s», «sh»).
    public let soundId: String

    /// Общее количество раундов в сессии.
    public let totalRounds: Int

    public init(
        sessionId: String,
        lessonTitle: String,
        soundId: String,
        totalRounds: Int
    ) {
        self.sessionId = sessionId
        self.lessonTitle = lessonTitle
        self.soundId = soundId
        self.totalRounds = totalRounds
    }

    // MARK: - ContentState

    /// Изменяемое состояние Live Activity — обновляется при каждом раунде.
    public struct LessonSessionState: Codable, Hashable, Sendable {

        /// Текущий раунд (1-based).
        public var currentRound: Int

        /// Накопленный счёт за сессию.
        public var score: Int

        /// Активное время сессии в секундах (без пауз).
        public var elapsedSeconds: Int

        /// Текущий стрик правильных ответов подряд.
        public var streakCount: Int

        public init(
            currentRound: Int,
            score: Int,
            elapsedSeconds: Int,
            streakCount: Int
        ) {
            self.currentRound = currentRound
            self.score = score
            self.elapsedSeconds = elapsedSeconds
            self.streakCount = streakCount
        }
    }
}
