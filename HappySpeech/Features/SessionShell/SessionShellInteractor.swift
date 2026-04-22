import Foundation
import OSLog
import UIKit

// MARK: - SessionShellBusinessLogic

@MainActor
protocol SessionShellBusinessLogic: AnyObject {
    func startSession(_ request: SessionShellModels.StartSession.Request) async
    func completeActivity(_ request: SessionShellModels.CompleteActivity.Request) async
    func pauseSession(_ request: SessionShellModels.PauseSession.Request)
    func resumeSession()
    func skipCurrentActivity() async
    func endSessionEarly() async
}

// MARK: - SessionShellInteractor

/// Orchestrates a full session: loads a route from `AdaptivePlannerService`, passes
/// activities to game children, collects score, and decides when to stop (including
/// fatigue detection based on consecutive errors and session length).
@MainActor
final class SessionShellInteractor: SessionShellBusinessLogic {

    var presenter: (any SessionShellPresentationLogic)?

    private let contentService: any ContentService
    private let adaptivePlannerService: any AdaptivePlannerService
    private let sessionRepository: any SessionRepository
    private let hapticService: any HapticService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionShell")

    private var activities: [SessionActivity] = []
    private var currentIndex: Int = 0
    private var sessionStartTime: Date = Date()
    private var errorCount: Int = 0
    private var consecutiveErrors: Int = 0
    private var isPaused: Bool = false
    private var pauseStartTime: Date?
    private var accumulatedPauseSeconds: TimeInterval = 0

    // MARK: Fatigue thresholds

    private let maxConsecutiveErrors = 3
    private let maxSessionMinutes: Double = 15

    // MARK: Init

    init(
        contentService: any ContentService,
        adaptivePlannerService: any AdaptivePlannerService,
        sessionRepository: any SessionRepository,
        hapticService: any HapticService
    ) {
        self.contentService = contentService
        self.adaptivePlannerService = adaptivePlannerService
        self.sessionRepository = sessionRepository
        self.hapticService = hapticService
    }

    // MARK: SessionShellBusinessLogic

    func startSession(_ request: SessionShellModels.StartSession.Request) async {
        sessionStartTime = Date()
        accumulatedPauseSeconds = 0
        errorCount = 0
        consecutiveErrors = 0
        currentIndex = 0
        isPaused = false

        let activities = await loadActivities(for: request)
        self.activities = activities

        let totalMinutes = max(activities.count * 2, 1)
        logger.info("Session started: type=\(request.sessionType.rawValue) steps=\(activities.count)")

        let response = SessionShellModels.StartSession.Response(
            activities: activities,
            totalSteps: activities.count,
            estimatedMinutes: totalMinutes
        )
        await presenter?.presentStartSession(response)
    }

    func completeActivity(_ request: SessionShellModels.CompleteActivity.Request) async {
        guard currentIndex < activities.count else {
            logger.warning("completeActivity called with currentIndex=\(self.currentIndex) >= activities=\(self.activities.count)")
            return
        }

        if request.score < 0.5 {
            consecutiveErrors += 1
            errorCount += request.errorCount
            hapticService.notification(.warning)
        } else {
            consecutiveErrors = 0
            hapticService.notification(.success)
        }

        activities[currentIndex].isCompleted = true
        activities[currentIndex].score = request.score

        let fatigueDetected = detectFatigue()
        let nextActivity: SessionActivity? = {
            let nextIdx = currentIndex + 1
            guard nextIdx < activities.count else { return nil }
            return activities[nextIdx]
        }()
        currentIndex += 1

        let reward: RewardItem? = request.score >= 0.8 ? .star : nil

        let response = SessionShellModels.CompleteActivity.Response(
            nextActivity: fatigueDetected ? nil : nextActivity,
            isSessionComplete: nextActivity == nil || fatigueDetected,
            earnedReward: reward,
            fatigueDetected: fatigueDetected
        )
        logger.info("Activity \(request.activityId) score=\(request.score) fatigue=\(fatigueDetected) complete=\(response.isSessionComplete)")

        if response.isSessionComplete {
            await saveSession()
        }
        await presenter?.presentCompleteActivity(response)
    }

    func pauseSession(_ request: SessionShellModels.PauseSession.Request) {
        guard !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()

        let progress = Float(currentIndex) / Float(max(activities.count, 1))
        let response = SessionShellModels.PauseSession.Response(currentProgress: progress)
        presenter?.presentPauseSession(response)
    }

    func resumeSession() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        accumulatedPauseSeconds += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        isPaused = false
    }

    func skipCurrentActivity() async {
        guard currentIndex < activities.count else { return }
        activities[currentIndex].isCompleted = true
        activities[currentIndex].score = 0
        let skippedId = activities[currentIndex].id
        logger.info("Skipped activity id=\(skippedId)")
        await completeActivity(SessionShellModels.CompleteActivity.Request(
            activityId: skippedId,
            score: 0,
            durationSeconds: 0,
            errorCount: 0
        ))
    }

    func endSessionEarly() async {
        logger.info("Ending session early: \(self.currentIndex)/\(self.activities.count)")
        await saveSession()
    }

    // MARK: Private

    private func detectFatigue() -> Bool {
        let elapsed = activeElapsedSeconds / 60
        return consecutiveErrors >= maxConsecutiveErrors || elapsed >= maxSessionMinutes
    }

    private var activeElapsedSeconds: TimeInterval {
        let total = Date().timeIntervalSince(sessionStartTime)
        return max(0, total - accumulatedPauseSeconds)
    }

    private func loadActivities(for request: SessionShellModels.StartSession.Request) async -> [SessionActivity] {
        switch request.sessionType {
        case .adaptive:
            do {
                let route = try await adaptivePlannerService.buildDailyRoute(for: request.childId)
                return route.steps.enumerated().map { idx, step in
                    SessionActivity(
                        id: "\(request.childId)-adaptive-\(idx)",
                        gameType: Self.gameType(from: step.templateType),
                        lessonId: "\(step.targetSound)-\(step.stage.rawValue)-\(idx)",
                        soundTarget: step.targetSound,
                        difficulty: step.difficulty,
                        isCompleted: false
                    )
                }
            } catch {
                logger.error("Adaptive route failed: \(error.localizedDescription). Falling back to default.")
                return Self.defaultActivities(for: request)
            }
        case .quickPractice, .screening, .homeworkTask:
            return Self.defaultActivities(for: request)
        }
    }

    private static func defaultActivities(for request: SessionShellModels.StartSession.Request) -> [SessionActivity] {
        let templates: [GameType] = [.listenAndChoose, .repeatAfterModel, .minimalPairs, .sorting, .memory]
        return templates.enumerated().map { idx, type in
            SessionActivity(
                id: "\(request.childId)-\(request.sessionType.rawValue)-\(idx)",
                gameType: type,
                lessonId: "\(request.targetSoundId)-lesson-\(idx)",
                soundTarget: request.targetSoundId,
                difficulty: 1 + idx / 2,
                isCompleted: false
            )
        }
    }

    private static func gameType(from template: TemplateType) -> GameType {
        switch template {
        case .listenAndChoose:       return .listenAndChoose
        case .repeatAfterModel:      return .repeatAfterModel
        case .dragAndMatch:          return .dragAndMatch
        case .storyCompletion:       return .storyCompletion
        case .puzzleReveal:          return .puzzleReveal
        case .sorting:               return .sorting
        case .memory:                return .memory
        case .bingo:                 return .bingo
        case .soundHunter:           return .soundHunter
        case .articulationImitation: return .articulationImitation
        case .arActivity:            return .arActivity
        case .visualAcoustic:        return .visualAcoustic
        case .breathing:             return .breathing
        case .rhythm:                return .rhythm
        case .narrativeQuest:        return .narrativeQuest
        case .minimalPairs:          return .minimalPairs
        }
    }

    private func saveSession() async {
        let totalCompleted = activities.filter { $0.isCompleted }.count
        let avgScore = avgScoreValue()
        logger.info("Session saved: \(totalCompleted)/\(self.activities.count) avg=\(avgScore, format: .fixed(precision: 2))")
        // Production persistence via sessionRepository goes here (Sprint 12 follow-up).
    }

    private func avgScoreValue() -> Float {
        let scored = activities.compactMap { $0.score }
        guard !scored.isEmpty else { return 0 }
        return scored.reduce(0, +) / Float(scored.count)
    }
}
