import ActivityKit
import Foundation
import OSLog

// MARK: - LiveActivityManager

/// Управляет жизненным циклом Live Activity для сессии урока.
///
/// Использование:
/// ```swift
/// await LiveActivityManager.shared.start(
///     sessionId: id, lessonTitle: "Звук С", soundId: "s", totalRounds: 5
/// )
/// await LiveActivityManager.shared.update(round: 2, score: 10, elapsed: 45, streak: 2)
/// await LiveActivityManager.shared.end()
/// ```
///
/// COPPA: атрибуты не содержат имени ребёнка или других персональных данных.
///
/// Swift 6 note: `Activity<T>` не является `Sendable`. Мы оборачиваем его в
/// `ActivityBox` — `@unchecked Sendable`-контейнер — и защищаем доступ через `@MainActor`.
@available(iOS 16.1, *)
@MainActor
public final class LiveActivityManager {

    // MARK: - Nested helpers

    /// Обёртка над `Activity<LessonSessionAttributes>` для Swift 6.
    /// Доступ всегда происходит с `@MainActor`, что обеспечивает thread safety.
    private final class ActivityBox: @unchecked Sendable {
        let activity: Activity<LessonSessionAttributes>
        init(_ activity: Activity<LessonSessionAttributes>) {
            self.activity = activity
        }
    }

    // MARK: - Shared

    public static let shared = LiveActivityManager()

    // MARK: - Private

    private var box: ActivityBox?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "LiveActivity")

    private init() {}

    // MARK: - Public API

    /// Запускает Live Activity для новой сессии урока.
    /// Если Live Activities отключены на устройстве — вызов игнорируется.
    public func start(
        sessionId: String,
        lessonTitle: String,
        soundId: String,
        totalRounds: Int
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities отключены на устройстве — пропуск запуска")
            return
        }

        await terminateCurrent()

        let attributes = LessonSessionAttributes(
            sessionId: sessionId,
            lessonTitle: lessonTitle,
            soundId: soundId,
            totalRounds: totalRounds
        )
        let initialState = LessonSessionAttributes.LessonSessionState(
            currentRound: 1,
            score: 0,
            elapsedSeconds: 0,
            streakCount: 0
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            box = ActivityBox(activity)
            logger.info("Live Activity запущена: sessionId=\(sessionId, privacy: .public)")
        } catch {
            logger.error("Ошибка запуска Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Обновляет состояние Live Activity после завершения раунда.
    public func update(round: Int, score: Int, elapsed: Int, streak: Int) async {
        guard let currentBox = box else { return }
        let newState = LessonSessionAttributes.LessonSessionState(
            currentRound: round,
            score: score,
            elapsedSeconds: elapsed,
            streakCount: streak
        )
        await currentBox.activity.update(ActivityContent(state: newState, staleDate: nil))
        logger.debug("Live Activity обновлена: round=\(round) score=\(score) elapsed=\(elapsed)")
    }

    /// Завершает Live Activity и скрывает её с экрана блокировки.
    public func end() async {
        await terminateCurrent()
    }

    // MARK: - Private

    private func terminateCurrent() async {
        guard let currentBox = box else { return }
        box = nil
        let finalContent = currentBox.activity.content
        await currentBox.activity.end(finalContent, dismissalPolicy: .default)
        logger.info("Live Activity завершена")
    }
}
