import Foundation
import OSLog

// MARK: - SessionCompleteBusinessLogic

@MainActor
protocol SessionCompleteBusinessLogic: AnyObject {
    func loadResult(_ request: SessionCompleteModels.LoadResult.Request)
    func advancePhase(_ request: SessionCompleteModels.AdvancePhase.Request)
    func shareResult(_ request: SessionCompleteModels.ShareResult.Request)
    func playAgain(_ request: SessionCompleteModels.PlayAgain.Request)
    func proceedToNext(_ request: SessionCompleteModels.ProceedToNext.Request)
}

// MARK: - SessionCompleteInteractor

/// Бизнес-логика финального экрана сессии.
///
/// В M7.2 источник результата — параметр init'а (передаётся LessonPlayer'ом).
/// На M8 будет дополнено: запись в `SessionRepository`, обновление spaced
/// repetition в `AdaptivePlannerService.recordSessionResult(...)`,
/// разблокировка стикеров через `RewardsService`. Контракт View не изменится.
@MainActor
final class SessionCompleteInteractor: SessionCompleteBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any SessionCompletePresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionComplete")

    // MARK: - State

    private var result: SessionResult?

    // MARK: - Init

    init() {}

    // MARK: - BusinessLogic

    func loadResult(_ request: SessionCompleteModels.LoadResult.Request) {
        result = request.result
        let resultInfo = "score=\(request.result.score) stars=\(request.result.starsEarned)"
        logger.info(
            "loadResult game=\(request.result.gameTitle, privacy: .public) \(resultInfo, privacy: .public)"
        )
        presenter?.presentLoadResult(.init(result: request.result))
        publishAchievementEvent(for: request.result)
    }

    // MARK: - Achievement event (минимально-инвазивная интеграция через NotificationCenter)

    private func publishAchievementEvent(for sessionResult: SessionResult) {
        let event = AchievementEvent.sessionCompleted(
            soundId: sessionResult.soundTarget,
            score: Double(sessionResult.score),
            roundsTotal: sessionResult.attempts
        )
        // childId хранится в SessionResult.soundTarget контексте;
        // используем пустую строку — AchievementsInteractor обрабатывает gracefully.
        NotificationCenter.default.post(
            name: .achievementEventOccurred,
            object: nil,
            userInfo: [
                "childId": "",
                "event": event
            ]
        )
    }

    func advancePhase(_ request: SessionCompleteModels.AdvancePhase.Request) {
        logger.debug("advancePhase to=\(request.to.rawValue, privacy: .public)")
        presenter?.presentAdvancePhase(.init(phase: request.to))
    }

    func shareResult(_ request: SessionCompleteModels.ShareResult.Request) {
        guard let result else {
            logger.warning("shareResult: no result loaded")
            presenter?.presentFailure(.init(
                message: String(localized: "sessionComplete.error.noResult")
            ))
            return
        }
        logger.info("shareResult requested for sound=\(result.soundTarget, privacy: .public)")
        presenter?.presentShareResult(.init(shareText: makeShareText(from: result)))
    }

    func playAgain(_ request: SessionCompleteModels.PlayAgain.Request) {
        logger.info("playAgain")
        presenter?.presentPlayAgain(.init())
    }

    func proceedToNext(_ request: SessionCompleteModels.ProceedToNext.Request) {
        let hasNext = result?.nextLessonTitle != nil
        logger.info("proceedToNext hasNext=\(hasNext, privacy: .public)")
        presenter?.presentProceedToNext(.init(hasNext: hasNext))
    }

    // MARK: - Private

    private func makeShareText(from result: SessionResult) -> String {
        let percent = Int(result.score * 100)
        let stars = String(repeating: "★", count: result.starsEarned)
            + String(repeating: "☆", count: max(0, 3 - result.starsEarned))
        let template = String(localized: "sessionComplete.share.template")
        return String(
            format: template,
            result.gameTitle,
            result.soundTarget,
            percent,
            stars
        )
    }
}
