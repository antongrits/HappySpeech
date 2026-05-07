import Foundation
import OSLog

// MARK: - DailyStreakBusinessLogic

@MainActor
protocol DailyStreakBusinessLogic: AnyObject {
    func load(request: DailyStreakModels.Load.Request) async
    func checkIn(request: DailyStreakModels.CheckIn.Request) async
    func useSaver(request: DailyStreakModels.UseSaver.Request) async
    func scheduleReminderIfNeeded(childName: String) async
}

// MARK: - DailyStreakDataStore

@MainActor
protocol DailyStreakDataStore: AnyObject {
    var childId: String { get set }
}

// MARK: - DailyStreakInteractor (Clean Swift: Interactor)
//
// Block S.1 v16 — Daily Streak Rewards (gamification).
//
// Бизнес-логика:
//   1. `load` — собрать текущий streak/longest/saver state для UI
//   2. `checkIn` — отметка о входе в приложение → пересчёт streak
//   3. `useSaver` — восстановить упущенный день (раз в месяц)
//   4. `scheduleReminderIfNeeded` — запланировать локальное напоминание
//
// Persistence: UserDefaults (proven pattern, без Realm миграций).
// Notifications: через NotificationService (sendable Sendable).
// Haptic: при milestone unlock — `.notification(.success)`.
//
// COPPA: вся логика on-device, никаких сетевых запросов из kid contour.

@MainActor
final class DailyStreakInteractor: DailyStreakBusinessLogic, DailyStreakDataStore {

    // MARK: - DataStore

    var childId: String

    // MARK: - VIP

    var presenter: (any DailyStreakPresentationLogic)?

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let notificationService: any NotificationService
    private let hapticService: any HapticService
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "DailyStreak")

    // MARK: - UserDefaults keys (per-child)

    private enum Keys {
        static let prefix = "happyspeech.dailyStreak."
        static func currentStreak(_ childId: String) -> String { "\(prefix)\(childId).current" }
        static func longestStreak(_ childId: String) -> String { "\(prefix)\(childId).longest" }
        static func lastActiveISO(_ childId: String) -> String { "\(prefix)\(childId).lastActive" }
        static func unlockedMilestones(_ childId: String) -> String { "\(prefix)\(childId).unlocked" }
        static func saverLastUsedISO(_ childId: String) -> String { "\(prefix)\(childId).saverUsed" }
        static func reminderScheduled(_ childId: String) -> String { "\(prefix)\(childId).reminderOn" }
    }

    // MARK: - Init

    init(
        childId: String,
        notificationService: any NotificationService,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.childId = childId
        self.notificationService = notificationService
        self.hapticService = hapticService
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    // MARK: - Load

    func load(request: DailyStreakModels.Load.Request) async {
        let snapshot = readSnapshot(for: request.childId)

        let response = DailyStreakModels.Load.Response(
            currentStreak: snapshot.currentStreak,
            longestStreak: snapshot.longestStreak,
            status: snapshot.status(now: Date(), calendar: calendar),
            saver: snapshot.saverState(now: Date(), calendar: calendar),
            unlockedMilestones: DailyStreakMilestone.unlocked(for: snapshot.currentStreak),
            nextMilestone: DailyStreakMilestone.next(after: snapshot.currentStreak),
            lastActiveAt: snapshot.lastActiveAt
        )

        await presenter?.presentLoad(response: response)
    }

    // MARK: - CheckIn

    func checkIn(request: DailyStreakModels.CheckIn.Request) async {
        var snapshot = readSnapshot(for: request.childId)
        let previousStreak = snapshot.currentStreak

        let result = computeCheckIn(snapshot: snapshot, now: request.now)
        snapshot.currentStreak = result.newStreak
        snapshot.longestStreak = max(snapshot.longestStreak, result.newStreak)
        snapshot.lastActiveAt  = request.now
        writeSnapshot(snapshot, for: request.childId)

        // Определяем — новый milestone или нет.
        var unlockedMilestone: DailyStreakMilestone?
        if previousStreak < result.newStreak,
           let milestone = DailyStreakMilestone.all.first(where: { $0.days == result.newStreak }),
           !snapshot.unlockedMilestoneIDs.contains(milestone.id) {
            unlockedMilestone = milestone
            var ids = snapshot.unlockedMilestoneIDs
            ids.insert(milestone.id)
            snapshot.unlockedMilestoneIDs = ids
            writeSnapshot(snapshot, for: request.childId)

            // Haptic: успех
            hapticService.notification(.success)
            Self.logger.info("DailyStreak milestone unlocked: \(milestone.id, privacy: .public)")
        }

        let response = DailyStreakModels.CheckIn.Response(
            newStreak: result.newStreak,
            unlockedMilestone: unlockedMilestone,
            status: result.status
        )
        await presenter?.presentCheckIn(response: response)
    }

    // MARK: - UseSaver

    func useSaver(request: DailyStreakModels.UseSaver.Request) async {
        var snapshot = readSnapshot(for: request.childId)
        let saver = snapshot.saverState(now: request.now, calendar: calendar)

        guard saver.availableThisMonth else {
            let response = DailyStreakModels.UseSaver.Response(
                success: false,
                restoredStreak: snapshot.currentStreak,
                nextSaverAvailableAt: nextMonthStart(from: request.now)
            )
            await presenter?.presentUseSaver(response: response)
            return
        }

        // Восстановим стрик до previousStreak + 1.
        snapshot.currentStreak = max(snapshot.currentStreak, snapshot.currentStreak + 1)
        snapshot.longestStreak = max(snapshot.longestStreak, snapshot.currentStreak)
        snapshot.lastActiveAt  = request.now
        snapshot.saverLastUsedAt = request.now
        writeSnapshot(snapshot, for: request.childId)

        hapticService.notification(.success)
        Self.logger.info("DailyStreak saver activated for child \(request.childId, privacy: .private)")

        let response = DailyStreakModels.UseSaver.Response(
            success: true,
            restoredStreak: snapshot.currentStreak,
            nextSaverAvailableAt: nextMonthStart(from: request.now)
        )
        await presenter?.presentUseSaver(response: response)
    }

    // MARK: - Reminders

    /// Планируем ежедневное напоминание ребёнку (kid-friendly, 17:00 фиксировано).
    /// При первом вызове запрашиваем permission. Идемпотентно — не дублирует.
    func scheduleReminderIfNeeded(childName: String) async {
        let key = Keys.reminderScheduled(childId)
        guard !userDefaults.bool(forKey: key) else { return }

        let granted = await notificationService.requestPermission()
        guard granted else {
            Self.logger.info("Notification permission denied; skip reminder for child")
            return
        }

        await notificationService.scheduleDailyKidReminder(childName: childName)
        userDefaults.set(true, forKey: key)
        Self.logger.info("Daily streak reminder scheduled")
    }

    // MARK: - Pure compute (testable)

    private func computeCheckIn(
        snapshot: DailyStreakSnapshot,
        now: Date
    ) -> (newStreak: Int, status: DailyStreakStatus) {
        guard let last = snapshot.lastActiveAt else {
            return (1, .active)
        }
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: now)
        let diffComponents = calendar.dateComponents([.day], from: lastDay, to: today)
        let diff = diffComponents.day ?? 0
        switch diff {
        case 0:
            return (snapshot.currentStreak, .active)
        case 1:
            return (snapshot.currentStreak + 1, .active)
        default:
            return (1, .broken)
        }
    }

    private func nextMonthStart(from date: Date) -> Date? {
        guard let firstOfMonth = calendar.dateInterval(of: .month, for: date)?.start,
              let nextStart = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) else {
            return nil
        }
        return nextStart
    }

    // MARK: - Snapshot persistence

    private struct DailyStreakSnapshot {

        var currentStreak: Int
        var longestStreak: Int
        var lastActiveAt: Date?
        var unlockedMilestoneIDs: Set<String>
        var saverLastUsedAt: Date?

        func status(now: Date, calendar: Calendar) -> DailyStreakStatus {
            guard let last = lastActiveAt else { return .fresh }
            let lastDay = calendar.startOfDay(for: last)
            let today = calendar.startOfDay(for: now)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            switch diff {
            case 0: return .active
            case 1: return .pendingToday
            default: return .broken
            }
        }

        func saverState(now: Date, calendar: Calendar) -> StreakSaverState {
            guard let used = saverLastUsedAt else {
                return StreakSaverState(lastUsedAt: nil, availableThisMonth: true)
            }
            let usedMonth = calendar.dateInterval(of: .month, for: used)
            let nowMonth = calendar.dateInterval(of: .month, for: now)
            let inSameMonth = usedMonth?.start == nowMonth?.start
            return StreakSaverState(
                lastUsedAt: used,
                availableThisMonth: !inSameMonth
            )
        }
    }

    private func readSnapshot(for childId: String) -> DailyStreakSnapshot {
        let current = userDefaults.integer(forKey: Keys.currentStreak(childId))
        let longest = userDefaults.integer(forKey: Keys.longestStreak(childId))
        let lastIso = userDefaults.string(forKey: Keys.lastActiveISO(childId))
        let unlockedJoined = userDefaults.string(forKey: Keys.unlockedMilestones(childId)) ?? ""
        let unlocked = Set(unlockedJoined
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
        )
        let saverIso = userDefaults.string(forKey: Keys.saverLastUsedISO(childId))
        let isoFormatter = ISO8601DateFormatter()

        return DailyStreakSnapshot(
            currentStreak: current,
            longestStreak: longest,
            lastActiveAt: lastIso.flatMap { isoFormatter.date(from: $0) },
            unlockedMilestoneIDs: unlocked,
            saverLastUsedAt: saverIso.flatMap { isoFormatter.date(from: $0) }
        )
    }

    private func writeSnapshot(_ snapshot: DailyStreakSnapshot, for childId: String) {
        let isoFormatter = ISO8601DateFormatter()
        userDefaults.set(snapshot.currentStreak, forKey: Keys.currentStreak(childId))
        userDefaults.set(snapshot.longestStreak, forKey: Keys.longestStreak(childId))
        if let last = snapshot.lastActiveAt {
            userDefaults.set(isoFormatter.string(from: last), forKey: Keys.lastActiveISO(childId))
        }
        let joined = snapshot.unlockedMilestoneIDs.sorted().joined(separator: ",")
        userDefaults.set(joined, forKey: Keys.unlockedMilestones(childId))
        if let saver = snapshot.saverLastUsedAt {
            userDefaults.set(isoFormatter.string(from: saver), forKey: Keys.saverLastUsedISO(childId))
        }
    }
}

// NOTE deferred to Block Q (test coverage): unit tests for computeCheckIn,
// useSaver gating, snapshot persistence round-trip, scheduleReminderIfNeeded.
