import Foundation
import OSLog

// MARK: - FamilyAchievementsBusinessLogic

@MainActor
protocol FamilyAchievementsBusinessLogic: AnyObject {
    func load(request: FamilyAchievementsModels.Load.Request) async
    func recompute(request: FamilyAchievementsModels.Recompute.Request) async
}

// MARK: - FamilyAchievementsDataStore

@MainActor
protocol FamilyAchievementsDataStore: AnyObject {
    var familyId: String { get set }
}

// MARK: - FamilyAchievementsInteractor (Clean Swift: Interactor)
//
// Block R.4 v18 — общие достижения семьи (агрегаты по всем детям).
//
// Логика:
//   1. `load` — собрать всех детей из ChildRepository, последние сессии,
//      посчитать unlocked achievements + family streak
//   2. `recompute` — пересчитать после новой сессии, добавить unlocked
//
// Persistence: unlocked-list через UserDefaults (per-family).
// Family streak: вычисляется по lastSessionAt для всех детей.
// COPPA: дети представлены только агрегатами (имя + age + counts).

@MainActor
final class FamilyAchievementsInteractor: FamilyAchievementsBusinessLogic, FamilyAchievementsDataStore {

    // MARK: - DataStore

    var familyId: String

    // MARK: - VIP

    var presenter: (any FamilyAchievementsPresentationLogic)?

    // MARK: - Dependencies

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let userDefaults: UserDefaults
    private let hapticService: any HapticService
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyAchievements")

    // MARK: - UserDefaults keys

    private enum Keys {
        static let prefix = "happyspeech.familyAch."
        static func unlockedIds(_ familyId: String) -> String {
            "\(prefix)\(familyId).unlocked"
        }
    }

    // MARK: - Init

    init(
        familyId: String,
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard
    ) {
        self.familyId = familyId
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.hapticService = hapticService
        self.userDefaults = userDefaults
    }

    // MARK: - Load

    func load(request: FamilyAchievementsModels.Load.Request) async {
        let children: [ChildProfileDTO]
        do {
            children = try await childRepository.fetchAll()
        } catch {
            Self.logger.error("ChildRepository.fetchAll failed: \(error.localizedDescription)")
            // 3.D v23: ранее silent try? → возвращали [] → presentLoad с empty state;
            // если выше по стеку spinner всё-таки висит, гарантируем что present
            // вызовется даже на error path и не оставим View в loading.
            await emitEmptyState(for: request.familyId)
            return
        }

        // Собираем сводки по каждому ребёнку.
        var memberSummaries: [FamilyMemberSummary] = []
        var totalSessions = 0
        var totalMasteredSounds: Set<String> = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for child in children {
            let recentSessions = (try? await sessionRepository.fetchRecent(
                childId: child.id,
                limit: 100
            )) ?? []
            let childSessionsCount = recentSessions.count
            totalSessions += childSessionsCount

            let mastered = child.progressSummary
                .filter { $0.value >= 0.85 }
                .map { $0.key }
            totalMasteredSounds.formUnion(mastered)

            let lastSessionDay = child.lastSessionAt.map { calendar.startOfDay(for: $0) }
            let isActiveToday = lastSessionDay == today

            memberSummaries.append(
                FamilyMemberSummary(
                    id: child.id,
                    displayName: child.name,
                    age: child.age,
                    avatarSymbol: avatarSymbol(for: child.avatarStyle),
                    currentStreak: child.currentStreak,
                    totalSessions: childSessionsCount,
                    masteredSounds: mastered,
                    isActive: isActiveToday
                )
            )
        }

        // Считаем family streak.
        let activeTodayCount = memberSummaries.filter { $0.isActive }.count
        let allActiveToday = activeTodayCount == memberSummaries.count
            && !memberSummaries.isEmpty
        let combinedDays = memberSummaries
            .map { $0.currentStreak }
            .min() ?? 0

        let streakState = FamilyStreakState(
            combinedDays: allActiveToday ? combinedDays : 0,
            allActiveToday: allActiveToday,
            totalMembers: memberSummaries.count,
            activeTodayCount: activeTodayCount
        )

        // Считаем прогресс по достижениям.
        var progressById: [String: Int] = [:]
        for ach in FamilyAchievement.catalog {
            switch ach.category {
            case .streak:
                progressById[ach.id] = combinedDays
            case .sounds:
                progressById[ach.id] = totalMasteredSounds.count
            case .sessions:
                progressById[ach.id] = totalSessions
            case .milestone:
                progressById[ach.id] = totalSessions
            case .bonus:
                // bonus = есть хоть одна сессия, в семье ≥ 2 членов
                let unlock = memberSummaries.count >= 2 && totalSessions >= 1 ? 1 : 0
                progressById[ach.id] = unlock
            }
        }

        // Какие unlocked.
        var unlocked: Set<String> = readUnlocked(for: request.familyId)
        for ach in FamilyAchievement.catalog
        where (progressById[ach.id] ?? 0) >= ach.totalRequired {
            unlocked.insert(ach.id)
        }
        writeUnlocked(unlocked, for: request.familyId)

        let response = FamilyAchievementsModels.Load.Response(
            achievements: FamilyAchievement.catalog,
            unlockedIds: unlocked,
            progressById: progressById,
            members: memberSummaries,
            streakState: streakState
        )

        await presenter?.presentLoad(response: response)
    }

    /// 3.D v23: гарантирует что View никогда не остаётся в loading state
    /// даже если childRepository упал. Presenter покажет empty family stub.
    private func emitEmptyState(for familyId: String) async {
        let streakState = FamilyStreakState(
            combinedDays: 0,
            allActiveToday: false,
            totalMembers: 0,
            activeTodayCount: 0
        )
        let unlocked = readUnlocked(for: familyId)
        var progressById: [String: Int] = [:]
        for ach in FamilyAchievement.catalog {
            progressById[ach.id] = 0
        }
        let response = FamilyAchievementsModels.Load.Response(
            achievements: FamilyAchievement.catalog,
            unlockedIds: unlocked,
            progressById: progressById,
            members: [],
            streakState: streakState
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - Recompute

    func recompute(request: FamilyAchievementsModels.Recompute.Request) async {
        // Запоминаем prev unlocked.
        let prevUnlocked = readUnlocked(for: request.familyId)
        // Перезагружаем — load() сам перезапишет unlocked.
        await load(request: .init(familyId: request.familyId))
        let newUnlocked = readUnlocked(for: request.familyId)
        let delta = newUnlocked.subtracting(prevUnlocked)
        if !delta.isEmpty {
            hapticService.notification(.success)
            Self.logger.info("Family achievements unlocked: \(delta.count)")
        }
        let response = FamilyAchievementsModels.Recompute.Response(newUnlockedIds: delta)
        await presenter?.presentRecompute(response: response)
    }

    // MARK: - Persistence

    private func readUnlocked(for familyId: String) -> Set<String> {
        let joined = userDefaults.string(forKey: Keys.unlockedIds(familyId)) ?? ""
        return Set(
            joined.split(separator: ",")
                .map { String($0) }
                .filter { !$0.isEmpty }
        )
    }

    private func writeUnlocked(_ ids: Set<String>, for familyId: String) {
        let joined = ids.sorted().joined(separator: ",")
        userDefaults.set(joined, forKey: Keys.unlockedIds(familyId))
    }

    // MARK: - Helpers

    private func avatarSymbol(for style: String) -> String {
        switch style.lowercased() {
        case "butterfly": return "ant.fill"
        case "fox":       return "pawprint.fill"
        case "rabbit":    return "hare.fill"
        case "owl":       return "bird.fill"
        case "cat":       return "cat.fill"
        case "bear":      return "teddybear.fill"
        case "panda":     return "pawprint.circle.fill"
        default:          return "person.crop.circle.fill"
        }
    }
}
