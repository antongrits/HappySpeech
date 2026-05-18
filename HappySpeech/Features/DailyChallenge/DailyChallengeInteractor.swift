import Foundation
import OSLog

// MARK: - DailyChallengeBusinessLogic

@MainActor
protocol DailyChallengeBusinessLogic: AnyObject {
    func load(request: DailyChallengeModels.Load.Request) async
    func startSession(request: DailyChallengeModels.StartSession.Request) async
    func shareCompletion(request: DailyChallengeModels.ShareCompletion.Request) async
}

// MARK: - DailyChallengeDataStore

@MainActor
protocol DailyChallengeDataStore: AnyObject {
    var currentChildId: String? { get set }
    var currentGoal: DailyGoalState? { get set }
}

// MARK: - DailyChallengeInteractor (Clean Swift: Interactor)
//
// Block AE batch 2 v21 — ежедневный челлендж.
//
// Ответственность:
//   • Собрать DailyGoalState через ``DailyChallengeBuilder``.
//   • Подсчитать прогресс сессий за день через ``DailyChallengeStatsWorker``.
//   • Подготовить RewardPreview и StreakState.
//   • Передать запрос на начало сессии и шаринг родителю в Presenter → Router.
//
// COPPA: всё on-device, никаких сетевых запросов.

@MainActor
final class DailyChallengeInteractor: DailyChallengeBusinessLogic, DailyChallengeDataStore {

    // MARK: - DataStore

    var currentChildId: String?
    var currentGoal: DailyGoalState?

    // MARK: - VIP

    var presenter: (any DailyChallengePresentationLogic)?

    // MARK: - Workers

    private let statsWorker: any DailyChallengeStatsWorkerProtocol
    private let childRepository: any ChildRepository
    private let hapticService: any HapticService

    // MARK: - Date dependencies (для тестов)

    private let now: () -> Date
    private let calendar: Calendar

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyChallenge.Interactor"
    )

    // MARK: - Init

    init(
        statsWorker: any DailyChallengeStatsWorkerProtocol,
        childRepository: any ChildRepository,
        hapticService: any HapticService,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.statsWorker = statsWorker
        self.childRepository = childRepository
        self.hapticService = hapticService
        self.now = now
        self.calendar = calendar
    }

    // MARK: - Load

    func load(request: DailyChallengeModels.Load.Request) async {
        currentChildId = request.childId
        let today = now()
        let weekday = calendar.component(.weekday, from: today)

        // Профиль ребёнка для возраста/имени/таргет-звуков
        let profile: ChildProfileDTO
        do {
            profile = try await childRepository.fetch(id: request.childId)
        } catch {
            Self.logger.error("load: failed to fetch child \(request.childId, privacy: .private): \(error.localizedDescription, privacy: .public)")
            return
        }

        // Сессии сегодня → прогресс
        let sessions = await statsWorker.fetchTodaySessions(childId: request.childId, day: today)
        let targetSound = profile.targetSounds.first ?? "С"
        let kind = DailyChallengeBuilder.kind(forWeekday: weekday)
        let currentProgress = statsWorker.progress(
            for: kind,
            targetSound: targetSound,
            sessions: sessions
        )

        let goal = DailyChallengeBuilder.makeGoal(
            childId: request.childId,
            day: today,
            weekday: weekday,
            age: profile.age,
            targetSound: targetSound,
            currentProgress: currentProgress
        )
        currentGoal = goal

        // Награда — детерминированно по дню (year*1000+dayOfYear)
        let daySeed = calendar.component(.year, from: today) * 1000
            + (calendar.ordinality(of: .day, in: .year, for: today) ?? 1)
        let reward = DailyChallengeBuilder.reward(forDaySeed: daySeed, kind: goal.kind)

        // Текущий streak
        let streak = await statsWorker.computeStreak(childId: request.childId)

        Self.logger.debug(
            "load goal=\(goal.kind.rawValue, privacy: .public) target=\(goal.target) cur=\(goal.current) streak=\(streak.current)"
        )

        let response = DailyChallengeModels.Load.Response(
            goal: goal,
            streak: streak,
            reward: reward,
            childDisplayName: profile.name
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - StartSession

    func startSession(request: DailyChallengeModels.StartSession.Request) async {
        Self.logger.info("startSession child=\(request.childId, privacy: .private) sound=\(request.targetSound, privacy: .public)")
        hapticService.impact(.medium)
        let response = DailyChallengeModels.StartSession.Response(
            childId: request.childId,
            targetSound: request.targetSound
        )
        await presenter?.presentStartSession(response: response)
    }

    // MARK: - ShareCompletion

    func shareCompletion(request: DailyChallengeModels.ShareCompletion.Request) async {
        guard let goal = currentGoal, goal.isCompleted else {
            Self.logger.debug("shareCompletion ignored: goal not completed")
            return
        }
        let snapshot = String(
            format: String(localized: "dailyChallenge.share.snapshot"),
            goal.current, goal.target
        )
        let response = DailyChallengeModels.ShareCompletion.Response(
            snapshotText: snapshot,
            toastKey: "dailyChallenge.share.toast"
        )
        hapticService.notification(.success)
        await presenter?.presentShareCompletion(response: response)
    }
}
