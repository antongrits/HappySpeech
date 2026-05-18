import Foundation
import OSLog

// MARK: - WeeklyChallengeBusinessLogic

@MainActor
protocol WeeklyChallengeBusinessLogic: AnyObject {
    func load(request: WeeklyChallengeModels.Load.Request) async
    func markDay(request: WeeklyChallengeModels.MarkDay.Request) async
    func switchKind(request: WeeklyChallengeModels.SwitchKind.Request) async
}

// MARK: - WeeklyChallengeDataStore

@MainActor
protocol WeeklyChallengeDataStore: AnyObject {
    var childId: String { get set }
}

// MARK: - WeeklyChallengeInteractor (Clean Swift: Interactor)
//
// Block R.3 v18 — еженедельные challenge'ы для геймификации kid contour.
//
// Логика:
//   1. `load` — собрать прогресс на текущую неделю (Mon-Sun ISO calendar)
//   2. `markDay` — отметить день как completed (вызывается из LessonComplete)
//   3. `switchKind` — выбрать новый тип челленджа на следующую неделю
//
// Persistence: UserDefaults (per-child + per-week-iso key).
// Haptic: при unlock reward — `.notification(.success)`.
// COPPA: вся логика on-device, никаких сетевых запросов.
//
// Примечание: интегрируется с SessionRepository через ChildHomeInteractor —
// при completed сессии вызывается markDay(today). MVP: ручная отметка
// (для демонстрации в дипломе).

@MainActor
final class WeeklyChallengeInteractor: WeeklyChallengeBusinessLogic, WeeklyChallengeDataStore {

    // MARK: - DataStore

    var childId: String

    // MARK: - VIP

    var presenter: (any WeeklyChallengePresentationLogic)?

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let hapticService: any HapticService
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "WeeklyChallenge")

    // MARK: - UserDefaults keys

    private enum Keys {
        static let prefix = "happyspeech.weeklyChallenge."
        static func kind(_ childId: String, _ weekISO: String) -> String {
            "\(prefix)\(childId).\(weekISO).kind"
        }
        static func dayState(_ childId: String, _ weekISO: String) -> String {
            "\(prefix)\(childId).\(weekISO).days"
        }
        static func rewardUnlocked(_ childId: String, _ weekISO: String) -> String {
            "\(prefix)\(childId).\(weekISO).rewardUnlocked"
        }
    }

    // MARK: - Init

    init(
        childId: String,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.hapticService = hapticService
        self.userDefaults = userDefaults

        // Неделя считается строго по ISO-8601 (Mon–Sun) — challenge привязан
        // к неделе, поэтому календарь фиксирован и не инъектируется.
        var iso = Calendar(identifier: .iso8601)
        iso.firstWeekday = 2 // Monday
        iso.locale = Locale(identifier: "ru_RU")
        self.calendar = iso
    }

    // MARK: - Load

    func load(request: WeeklyChallengeModels.Load.Request) async {
        let weekISO = weekISOKey(for: request.now)
        let kind = readKind(for: request.childId, weekISO: weekISO) ?? .soundStreak
        let dayStates = readDayStates(
            for: request.childId,
            weekISO: weekISO,
            now: request.now,
            kind: kind
        )

        let completed = dayStates.filter { $0 == .completed }.count
        let totalRequired = requiredDays(for: kind)
        let weekStart = startOfWeek(for: request.now)

        let state = WeeklyChallengeState(
            kind: kind,
            weekStart: weekStart,
            dayStates: dayStates,
            completed: completed,
            totalRequired: totalRequired
        )

        let rewardUnlocked = userDefaults.bool(
            forKey: Keys.rewardUnlocked(request.childId, weekISO)
        )
        let reward = WeeklyChallengeReward(
            id: "weekly.\(weekISO).\(kind.rawValue)",
            titleKey: rewardTitleKey(for: kind),
            symbolName: rewardSymbolName(for: kind),
            isUnlocked: rewardUnlocked || state.isCompleted
        )

        let response = WeeklyChallengeModels.Load.Response(
            state: state,
            reward: reward,
            daysUntilEndOfWeek: daysUntilEndOfWeek(from: request.now)
        )

        await presenter?.presentLoad(response: response)
    }

    // MARK: - MarkDay

    func markDay(request: WeeklyChallengeModels.MarkDay.Request) async {
        guard request.dayIndex >= 0 && request.dayIndex < 7 else {
            Self.logger.error("Invalid dayIndex: \(request.dayIndex)")
            return
        }

        let weekISO = weekISOKey(for: request.now)
        let kind = readKind(for: request.childId, weekISO: weekISO) ?? .soundStreak
        var dayStates = readDayStates(
            for: request.childId,
            weekISO: weekISO,
            now: request.now,
            kind: kind
        )

        // Только если день не locked.
        guard dayStates[request.dayIndex] != .locked else {
            Self.logger.info("Cannot mark locked day: \(request.dayIndex)")
            return
        }

        dayStates[request.dayIndex] = .completed
        writeDayStates(
            dayStates,
            for: request.childId,
            weekISO: weekISO
        )

        let completed = dayStates.filter { $0 == .completed }.count
        let totalRequired = requiredDays(for: kind)
        let isCompleted = completed >= totalRequired

        var unlockedReward = false
        if isCompleted {
            let alreadyUnlocked = userDefaults.bool(
                forKey: Keys.rewardUnlocked(request.childId, weekISO)
            )
            if !alreadyUnlocked {
                userDefaults.set(true, forKey: Keys.rewardUnlocked(request.childId, weekISO))
                unlockedReward = true
                hapticService.notification(.success)
                Self.logger.info("Weekly challenge reward unlocked for \(kind.rawValue, privacy: .public)")
            }
        }

        let weekStart = startOfWeek(for: request.now)
        let updatedState = WeeklyChallengeState(
            kind: kind,
            weekStart: weekStart,
            dayStates: dayStates,
            completed: completed,
            totalRequired: totalRequired
        )

        let response = WeeklyChallengeModels.MarkDay.Response(
            updatedState: updatedState,
            unlockedReward: unlockedReward
        )

        await presenter?.presentMarkDay(response: response)
    }

    // MARK: - SwitchKind

    func switchKind(request: WeeklyChallengeModels.SwitchKind.Request) async {
        let weekISO = weekISOKey(for: request.now)
        userDefaults.set(request.kind.rawValue, forKey: Keys.kind(request.childId, weekISO))

        // Сбрасываем дни и reward при смене типа в текущей неделе.
        userDefaults.removeObject(forKey: Keys.dayState(request.childId, weekISO))
        userDefaults.removeObject(forKey: Keys.rewardUnlocked(request.childId, weekISO))

        Self.logger.info("Weekly challenge kind switched: \(request.kind.rawValue, privacy: .public)")

        let dayStates = readDayStates(
            for: request.childId,
            weekISO: weekISO,
            now: request.now,
            kind: request.kind
        )
        let totalRequired = requiredDays(for: request.kind)
        let weekStart = startOfWeek(for: request.now)

        let newState = WeeklyChallengeState(
            kind: request.kind,
            weekStart: weekStart,
            dayStates: dayStates,
            completed: 0,
            totalRequired: totalRequired
        )

        let response = WeeklyChallengeModels.SwitchKind.Response(newState: newState)
        await presenter?.presentSwitchKind(response: response)
    }

    // MARK: - Helpers (date math)

    /// ISO week key — «2026-W19» формат, годо-нейтральный.
    private func weekISOKey(for date: Date) -> String {
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    private func startOfWeek(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func daysUntilEndOfWeek(from date: Date) -> Int {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return 0
        }
        let days = calendar.dateComponents([.day], from: date, to: weekInterval.end).day ?? 0
        return max(days, 0)
    }

    /// Индекс текущего дня в неделе: 0 = понедельник, 6 = воскресенье.
    private func currentDayIndex(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1=вс, 2=пн, 3=вт... 7=сб
        // переводим в 0=пн ... 6=вс
        return (weekday + 5) % 7
    }

    private func requiredDays(for kind: WeeklyChallengeKind) -> Int {
        switch kind {
        case .soundStreak:    return 7
        case .lessonCount:    return 5
        case .mixedTemplates: return 4
        case .bingo:          return 5
        case .storyteller:    return 3
        }
    }

    private func rewardTitleKey(for kind: WeeklyChallengeKind) -> String {
        switch kind {
        case .soundStreak:    return "weekly.reward.streak.title"
        case .lessonCount:    return "weekly.reward.count.title"
        case .mixedTemplates: return "weekly.reward.mixed.title"
        case .bingo:          return "weekly.reward.bingo.title"
        case .storyteller:    return "weekly.reward.storyteller.title"
        }
    }

    private func rewardSymbolName(for kind: WeeklyChallengeKind) -> String {
        switch kind {
        case .soundStreak:    return "flame.fill"
        case .lessonCount:    return "rosette"
        case .mixedTemplates: return "wand.and.stars"
        case .bingo:          return "trophy.fill"
        case .storyteller:    return "books.vertical.fill"
        }
    }

    // MARK: - Persistence

    private func readKind(for childId: String, weekISO: String) -> WeeklyChallengeKind? {
        let raw = userDefaults.string(forKey: Keys.kind(childId, weekISO))
        return raw.flatMap { WeeklyChallengeKind(rawValue: $0) }
    }

    private func readDayStates(
        for childId: String,
        weekISO: String,
        now: Date,
        kind: WeeklyChallengeKind
    ) -> [DayProgress] {
        let stored = userDefaults.string(forKey: Keys.dayState(childId, weekISO)) ?? ""
        let parts = stored.split(separator: ",").map { String($0) }

        let todayIdx = currentDayIndex(for: now)
        var states: [DayProgress] = (0..<7).map { idx in
            // если есть стор, парсим
            if idx < parts.count, let parsed = DayProgress(rawValue: parts[idx]) {
                return parsed
            }
            // иначе по дате: будущее = locked, сегодня = pending, прошлое = missed
            if idx > todayIdx {
                return .locked
            } else if idx == todayIdx {
                return .pending
            } else {
                return .missed
            }
        }

        // Auto-update locked → pending → missed transitions, если день стал текущим.
        for idx in 0..<states.count where idx <= todayIdx {
            if states[idx] == .locked {
                states[idx] = idx == todayIdx ? .pending : .missed
            }
        }

        return states
    }

    private func writeDayStates(
        _ states: [DayProgress],
        for childId: String,
        weekISO: String
    ) {
        let joined = states.map { $0.rawValue }.joined(separator: ",")
        userDefaults.set(joined, forKey: Keys.dayState(childId, weekISO))
    }
}
