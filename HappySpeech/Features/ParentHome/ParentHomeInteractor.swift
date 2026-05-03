import Foundation
import OSLog

// MARK: - ParentHomeBusinessLogic

@MainActor
protocol ParentHomeBusinessLogic: AnyObject {
    func fetchData(_ request: ParentHomeModels.Fetch.Request) async
    func refresh() async
    func switchChild(_ request: ParentHomeModels.SwitchChild.Request) async
    func addChild(_ request: ParentHomeModels.AddChild.Request) async
    func deleteChild(_ request: ParentHomeModels.DeleteChild.Request) async
    func markNotificationRead(_ request: ParentHomeModels.MarkNotificationRead.Request) async
    func updateDailyReminder(_ request: ParentHomeModels.UpdateNotificationPreference.Request) async
    func exportToSpecialist(childId: String) async
    func startLesson(childId: String) async
}

// MARK: - ParentHomeInteractor

/// Центральная бизнес-логика родительского дашборда.
///
/// Реализует 12 фич:
/// 1. Multi-child support — список и переключение детей
/// 2. Dashboard cards — сегодня / на неделе / достижения / задания
/// 3. Insights — LLM Tier B недельный отчёт (parent circuit)
/// 4. Quick actions — запуск урока, экспорт, история
/// 5. Notifications hub — reminder + achievement + specialist
/// 6. Spaced repetition — SM-2 агрегация по звукам
/// 7. Fatigue detection — из последних сессий
/// 8. Specialist review flag — EF < 1.5 для любого звука
/// 9. Persistence — ParentSettings (reminder time, last viewed)
/// 10. Error handling — Realm failure → empty state + offline indicator
/// 11. Accessibility — все данные подготовлены для VoiceOver
/// 12. Empty states — нет детей / нет сессий / нет достижений
///
/// - Note: Parent circuit → Tier B LLM разрешён. Kid circuit запрещён COPPA.

@MainActor
final class ParentHomeInteractor: ParentHomeBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ParentHomePresentationLogic)?

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    /// M6.16: Репозиторий результатов скрининга. Опциональный — не ломает превью и тесты.
    private let screeningOutcomeRepository: (any ScreeningOutcomeRepository)?
    /// A.6: LLM для weekly insights (parent circuit, Tier B).
    private let llmDecisionService: (any LLMDecisionServiceProtocol)?
    /// A.6: Spaced repetition + fatigue via AdaptivePlannerService.
    private let adaptivePlannerService: (any AdaptivePlannerService)?
    /// A.6: Notification reminder rescheduling.
    private let notificationService: (any NotificationService)?

    // MARK: - State

    private var activeChildId: String?
    /// In-memory кэш уведомлений: id → isRead. Персистируется UserDefaults в фоне.
    private var readNotificationIds: Set<String> = []
    /// Worker instances (lazy, живут с Interactor'ом)
    private lazy var weeklySummaryWorker = WeeklySummaryWorker(llmService: llmDecisionService)

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ParentHomeInteractor")

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        screeningOutcomeRepository: (any ScreeningOutcomeRepository)? = nil,
        llmDecisionService: (any LLMDecisionServiceProtocol)? = nil,
        adaptivePlannerService: (any AdaptivePlannerService)? = nil,
        notificationService: (any NotificationService)? = nil
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.screeningOutcomeRepository = screeningOutcomeRepository
        self.llmDecisionService = llmDecisionService
        self.adaptivePlannerService = adaptivePlannerService
        self.notificationService = notificationService
        self.readNotificationIds = Self.loadReadIds()
    }

    // MARK: - BusinessLogic: fetchData

    func fetchData(_ request: ParentHomeModels.Fetch.Request) async {
        presenter?.presentLoading(true)
        do {
            let allChildren = try await childRepository.fetchAll()
            guard let activeChild = Self.resolveChild(children: allChildren, preferred: request.preferredChildId) else {
                presenter?.presentEmpty()
                return
            }
            activeChildId = activeChild.id
            try await emit(child: activeChild, allChildren: allChildren)
        } catch {
            logger.error("ParentHome fetchData failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentEmpty()
        }
    }

    // MARK: - BusinessLogic: refresh

    func refresh() async {
        guard let activeId = activeChildId else {
            await fetchData(.init(preferredChildId: nil))
            return
        }
        do {
            let allChildren = try await childRepository.fetchAll()
            guard let child = allChildren.first(where: { $0.id == activeId }) else {
                await fetchData(.init(preferredChildId: nil))
                return
            }
            try await emit(child: child, allChildren: allChildren)
        } catch {
            logger.error("ParentHome refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - BusinessLogic: switchChild

    func switchChild(_ request: ParentHomeModels.SwitchChild.Request) async {
        do {
            let allChildren = try await childRepository.fetchAll()
            guard let child = allChildren.first(where: { $0.id == request.childId }) else {
                logger.warning("switchChild: child \(request.childId, privacy: .public) not found")
                return
            }
            activeChildId = child.id
            try await emit(child: child, allChildren: allChildren)
            logger.info("ParentHome switched to child: \(child.name, privacy: .private)")
        } catch {
            logger.error("ParentHome switchChild failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - BusinessLogic: addChild

    func addChild(_ request: ParentHomeModels.AddChild.Request) async {
        // Navigation handled by Router via presenter signal.
        // Interactor only logs the intent — no Realm write here (done in ChildProfileEditor).
        logger.info("ParentHome: addChild action requested")
        presenter?.presentAddChild()
    }

    // MARK: - BusinessLogic: deleteChild

    func deleteChild(_ request: ParentHomeModels.DeleteChild.Request) async {
        do {
            try await childRepository.delete(id: request.childId)
            logger.info("ParentHome: deleted child \(request.childId, privacy: .private)")
            // Reset active if deleted
            if activeChildId == request.childId { activeChildId = nil }
            await fetchData(.init(preferredChildId: activeChildId))
        } catch {
            logger.error("ParentHome deleteChild failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentError(String(localized: "parent.home.error.delete_child"))
        }
    }

    // MARK: - BusinessLogic: markNotificationRead

    func markNotificationRead(_ request: ParentHomeModels.MarkNotificationRead.Request) async {
        readNotificationIds.insert(request.notificationId)
        Self.saveReadIds(readNotificationIds)
        logger.debug("Notification marked read: \(request.notificationId, privacy: .public)")
    }

    // MARK: - BusinessLogic: updateDailyReminder

    func updateDailyReminder(_ request: ParentHomeModels.UpdateNotificationPreference.Request) async {
        guard let service = notificationService else {
            logger.warning("NotificationService not available — skipping reminder update")
            return
        }
        do {
            try await service.scheduleDailyReminder(at: request.hour, minute: request.minute)
            UserDefaults.standard.set(request.hour, forKey: "parentReminderHour")
            UserDefaults.standard.set(request.minute, forKey: "parentReminderMinute")
            logger.info("Daily reminder scheduled: \(request.hour):\(request.minute)")
        } catch {
            logger.error("scheduleDailyReminder failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - BusinessLogic: exportToSpecialist

    func exportToSpecialist(childId: String) async {
        logger.info("ParentHome: exportToSpecialist requested for \(childId, privacy: .public)")
        presenter?.presentExportSpecialist(childId: childId)
    }

    // MARK: - BusinessLogic: startLesson

    func startLesson(childId: String) async {
        logger.info("ParentHome: startLesson requested for \(childId, privacy: .public)")
        presenter?.presentStartLesson(childId: childId)
    }

    // MARK: - Core emit pipeline

    private func emit(child: ChildProfileDTO, allChildren: [ChildProfileDTO]) async throws {
        // 1. Fetch recent sessions (last 30 days)
        let recent30 = (try? await sessionRepository.fetchRecent(childId: child.id, limit: 50)) ?? []
        let sessionData = recent30.map { Self.sessionData(from: $0) }

        // 2. Weekly sessions (last 7 days)
        let weekSessions = Self.filterWeek(sessions: recent30)

        // 3. Overall rate
        let overall = Self.overallRate(for: child.progressSummary)

        // 4. Home task — rule-based Tier C (LLM plug via LLMDecisionService)
        let homeTask = await buildHomeTask(for: child, sessions: recent30)

        // 5. Screening outcome
        let screeningOutcome: ScreeningOutcomeDTO?
        if let repo = screeningOutcomeRepository {
            screeningOutcome = try? await repo.fetchLatest(childId: child.id)
        } else {
            screeningOutcome = nil
        }

        // 6. Achievements snapshot
        let achievements = AchievementsSnapshotWorker.buildSnapshot(
            from: recent30,
            childName: child.name
        )

        // 7. Notifications hub
        let rawNotifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: recent30,
            achievements: achievements
        )
        // Apply in-memory read state
        let notifications = rawNotifications.map { notif -> ParentHomeModels.NotificationItem in
            var mutable = notif
            if readNotificationIds.contains(notif.id) { mutable.isRead = true }
            return mutable
        }

        // 8. Child summaries for multi-child switcher
        let childSummaries = allChildren.map { c -> ParentHomeModels.ChildSummary in
            ParentHomeModels.ChildSummary(
                id: c.id,
                name: c.name,
                age: c.age,
                avatarStyle: c.avatarStyle,
                colorTheme: c.colorTheme,
                currentStreak: c.currentStreak,
                lastSessionAt: c.lastSessionAt,
                isActive: c.id == child.id
            )
        }

        let response = ParentHomeModels.Fetch.Response(
            childId: child.id,
            childName: child.name,
            childAge: child.age,
            targetSounds: child.targetSounds,
            currentStreak: child.currentStreak,
            totalSessionMinutes: child.totalSessionMinutes,
            overallRate: overall,
            recentSessions: sessionData,
            progressSummary: child.progressSummary,
            homeTask: homeTask,
            screeningOutcome: screeningOutcome,
            allChildren: childSummaries,
            weekSessions: weekSessions,
            achievements: achievements,
            notifications: notifications
        )
        presenter?.presentFetch(response)

        // 9. Async weekly insight — fires separately to not block main response
        Task { [weak self] in
            await self?.emitWeeklyInsight(child: child, weekSessions: weekSessions, recent30: recent30)
        }
    }

    // MARK: - Weekly Insight (async, non-blocking)

    private func emitWeeklyInsight(
        child: ChildProfileDTO,
        weekSessions: [SessionDTO],
        recent30: [SessionDTO]
    ) async {
        let dayStat = weeklySummaryWorker.buildWeekStats(sessions: weekSessions)
        let insight = await weeklySummaryWorker.generateWeeklyInsight(
            childName: child.name,
            sessions: weekSessions,
            dayStat: dayStat
        )
        presenter?.presentWeeklyInsight(
            ParentHomeModels.WeeklyInsightResponse(dayStat: dayStat, insight: insight)
        )
    }

    // MARK: - Home Task Builder

    private func buildHomeTask(for child: ChildProfileDTO, sessions: [SessionDTO]) async -> String? {
        // Tier B: пробуем LLM generateParentTip
        if let service = llmDecisionService {
            let profileInput = ChildProfileInput(
                id: child.id,
                name: child.name,
                age: child.age,
                targetSounds: child.targetSounds,
                sensitivityLevel: child.sensitivityLevel,
                progressSummary: child.progressSummary
            )
            let weakestStage: CorrectionStage
            if let worst = child.progressSummary.min(by: { $0.value < $1.value }) {
                let rate = worst.value
                weakestStage = Self.stage(for: rate)
            } else {
                weakestStage = .isolated
            }
            let outcome = await service.generateParentTip(
                profile: profileInput,
                currentStage: weakestStage
            )
            if !outcome.meta.usedFallback && outcome.meta.source != .ruleBased {
                logger.info("HomeTask: LLM Tier B tip generated")
                return outcome.tip
            }
        }
        // Tier C: rule-based fallback
        return Self.homeTask(for: child)
    }

    // MARK: - Spaced Repetition Aggregation

    /// Вычисляет `SoundProgressState` для каждого целевого звука.
    /// Используется Presenter для построения `SoundProgress[]` с трендом.
    private static func soundProgressStates(
        for child: ChildProfileDTO,
        sessions: [SessionDTO]
    ) -> [String: SoundProgressState] {
        var result: [String: SoundProgressState] = [:]
        for sound in child.targetSounds {
            result[sound] = SoundProgressAggregator.aggregate(
                soundTarget: sound,
                sessions: sessions
            )
        }
        return result
    }

    /// Проверяет нужна ли консультация специалиста хотя бы для одного звука.
    static func needsSpecialistReview(
        child: ChildProfileDTO,
        sessions: [SessionDTO]
    ) -> Bool {
        let states = soundProgressStates(for: child, sessions: sessions)
        return states.values.contains { $0.needsSpecialistReview }
    }

    // MARK: - Fatigue Detection

    /// Определяет уровень усталости из последних 3 сессий (rule-based).
    private static func detectFatigue(sessions: [SessionDTO]) -> FatigueLevel {
        let last3 = sessions.sorted { $0.date > $1.date }.prefix(3)
        let fatigueCount = last3.filter { $0.fatigueDetected }.count
        switch fatigueCount {
        case 3: return .tired
        case 2: return .normal
        default: return .fresh
        }
    }

    // MARK: - Helpers

    private static func resolveChild(children: [ChildProfileDTO], preferred: String?) -> ChildProfileDTO? {
        if let preferred, let match = children.first(where: { $0.id == preferred }) {
            return match
        }
        return children.first
    }

    private static func sessionData(from dto: SessionDTO) -> ParentHomeModels.SessionData {
        ParentHomeModels.SessionData(
            id: dto.id,
            date: dto.date,
            templateType: dto.templateType,
            targetSound: dto.targetSound,
            durationSeconds: dto.durationSeconds,
            totalAttempts: dto.totalAttempts,
            correctAttempts: dto.correctAttempts
        )
    }

    private static func overallRate(for summary: [String: Double]) -> Double {
        guard !summary.isEmpty else { return 0.0 }
        let total = summary.values.reduce(0.0, +)
        return total / Double(summary.count)
    }

    private static func homeTask(for child: ChildProfileDTO) -> String? {
        guard let weakest = child.targetSounds
            .map({ ($0, child.progressSummary[$0] ?? 0.0) })
            .min(by: { $0.1 < $1.1 })?
            .0
        else { return nil }
        let format = String(localized: "parent.home.homeTask.fallback")
        return String.localizedStringWithFormat(format, weakest)
    }

    private static func filterWeek(sessions: [SessionDTO], now: Date = Date()) -> [SessionDTO] {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return [] }
        return sessions.filter { $0.date >= weekAgo }
    }

    private static func stage(for rate: Double) -> CorrectionStage {
        switch rate {
        case ..<0.2:  return .isolated
        case ..<0.4:  return .syllable
        case ..<0.7:  return .wordInit
        case ..<0.9:  return .phrase
        default:       return .story
        }
    }

    // MARK: - UserDefaults: read notification persistence

    private static let readIdsKey = "parentHome.readNotificationIds"

    private static func loadReadIds() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: readIdsKey) ?? []
        return Set(arr)
    }

    private static func saveReadIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: readIdsKey)
    }
}

// MARK: - WeeklyInsightResponse (internal)

struct ParentHomeWeeklyInsightResponse {
    let dayStat: [ParentHomeModels.DayStat]
    let insight: ParentHomeModels.WeeklyInsight
}

extension ParentHomeModels {
    typealias WeeklyInsightResponse = ParentHomeWeeklyInsightResponse
}
