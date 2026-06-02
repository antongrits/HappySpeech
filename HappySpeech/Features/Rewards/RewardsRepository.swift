import Foundation
import OSLog

// MARK: - RewardsSnapshot

/// Полный снимок данных альбома наград, собранный из РЕАЛЬНЫХ источников
/// (сессии / профиль / Realm-инвентарь стикеров / разблокированные достижения).
public struct RewardsSnapshot: Sendable {
    public let stickers: [Sticker]
    public let achievements: [RewardsAchievement]
    public let wallet: StarsWallet
    public let currentStreak: Int
}

// MARK: - RewardsRepository

/// Источник данных альбома наград (kid-контур). Считает прогресс достижений,
/// разблокировку стикеров, кошелёк звёзд и серию из реальных данных ребёнка —
/// никаких зашитых чисел и случайных дат.
@MainActor
public protocol RewardsRepository: Sendable {
    /// Собирает снимок наград для ребёнка. Идемпотентно персистит вновь
    /// достигнутые достижения (`UnlockedAchievementObject`).
    func loadSnapshot(childId: String) async -> RewardsSnapshot
}

// MARK: - LiveRewardsRepository

@MainActor
public final class LiveRewardsRepository: RewardsRepository {

    private let realmActor: RealmActor
    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RewardsRepository")

    public init(
        realmActor: RealmActor,
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.realmActor = realmActor
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    public func loadSnapshot(childId: String) async -> RewardsSnapshot {
        // Пустой / отсутствующий ребёнок → честный пустой альбом.
        guard !childId.isEmpty else {
            return RewardsSnapshot(
                stickers: RewardsCatalog.lockedStickers(),
                achievements: RewardsCatalog.lockedAchievements(),
                wallet: .empty,
                currentStreak: 0
            )
        }

        let profile = try? await childRepository.fetch(id: childId)
        let sessions = (try? await sessionRepository.fetchAll(childId: childId)) ?? []

        // Реальные метрики из сессий + профиля.
        let metrics = RewardsMetrics(profile: profile, sessions: sessions)

        // Достижения: прогресс из реальных метрик; unlock-даты из Realm.
        let achievements = await buildAchievements(childId: childId, metrics: metrics)

        // Стикеры: разблокированы реально купленные (RewardShop) + выданные за
        // достижение «первый стикер»/streak. Новый ребёнок → пустой альбом.
        let inventory = await realmActor.fetchStickerInventory(childId: childId)
        let stickers = RewardsCatalog.stickers(ownedIds: Set(inventory.map(\.stickerId)),
                                               purchasedAt: Dictionary(
                                                   inventory.map { ($0.stickerId, $0.purchasedAt) },
                                                   uniquingKeysWith: { later, _ in later }
                                               ))

        // Кошелёк: заработано = число RewardRecord (реальные монеты за сессии),
        // потрачено = сумма priceSpent купленных стикеров.
        let earned = await realmActor.countRewardRecords(childId: childId)
        let spent = await realmActor.sumStickerSpending(childId: childId)
        let wallet = StarsWallet(totalEarned: earned, totalSpent: spent)

        let streak = profile?.currentStreak ?? 0
        return RewardsSnapshot(
            stickers: stickers,
            achievements: achievements,
            wallet: wallet,
            currentStreak: streak
        )
    }

    // MARK: - Achievements

    /// Строит достижения с реальным прогрессом. Для тех, чьи требования
    /// выполнены, идемпотентно сохраняет `UnlockedAchievementObject` и берёт
    /// реальную дату разблокировки (если уже была сохранена ранее).
    private func buildAchievements(
        childId: String,
        metrics: RewardsMetrics
    ) async -> [RewardsAchievement] {
        var unlocked = await realmActor.fetchUnlockedAchievements(childId: childId)
        var unlockedMap: [String: Date] = Dictionary(
            unlocked.map { ($0.achievementKey, $0.unlockedAt) },
            uniquingKeysWith: { earlier, _ in earlier }
        )

        // Персистим вновь достигнутые достижения (если требование выполнено,
        // а записи ещё нет) — дата разблокировки фиксируется реально (сейчас).
        for def in RewardsCatalog.achievementDefinitions {
            let current = metrics.progress(for: def.key)
            if current >= def.required, unlockedMap[def.key] == nil {
                await realmActor.persistAchievementUnlock(childId: childId, achievementKey: def.key)
            }
        }
        // Перечитываем, чтобы получить реальные сохранённые даты только что
        // разблокированных достижений.
        unlocked = await realmActor.fetchUnlockedAchievements(childId: childId)
        unlockedMap = Dictionary(
            unlocked.map { ($0.achievementKey, $0.unlockedAt) },
            uniquingKeysWith: { earlier, _ in earlier }
        )

        return RewardsCatalog.achievementDefinitions.map { def in
            let current = metrics.progress(for: def.key)
            let storedDate = unlockedMap[def.key]
            let isUnlocked = current >= def.required || storedDate != nil
            return RewardsAchievement(
                id: def.key,
                key: def.key,
                emoji: def.emoji,
                title: String(localized: "rewards.achievement.\(def.key).title"),
                hint: String(localized: "rewards.achievement.\(def.key).hint"),
                medal: def.medal,
                requiredProgress: def.required,
                currentProgress: min(current, def.required),
                isUnlocked: isUnlocked,
                unlockedAt: isUnlocked ? storedDate : nil
            )
        }
    }
}

// MARK: - RewardsMetrics

/// Вычисляет реальные значения прогресса достижений из профиля + сессий.
/// Никаких зашитых чисел: всё считается из фактических данных.
struct RewardsMetrics {
    let totalSessions: Int
    let totalMinutes: Int
    let currentStreak: Int
    let perfectSessions: Int          // сессии с successRate == 1.0
    let maxPerfectRun: Int            // самая длинная серия идеальных сессий подряд
    let overallAccuracyPercent: Int   // средняя точность по всем сессиям, %
    let masteredSounds: Set<String>   // звуки с progressSummary >= 0.85
    /// Число завершённых сессий по звуку (для «20 уроков звука X»).
    let sessionsPerSound: [String: Int]
    /// Доли освоения по звукам (progressSummary).
    let progressSummary: [String: Double]

    init(profile: ChildProfileDTO?, sessions: [SessionDTO]) {
        totalSessions = sessions.count
        let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        totalMinutes = max(0, Int((Double(totalSeconds) / 60.0).rounded()))
        currentStreak = profile?.currentStreak ?? 0
        progressSummary = profile?.progressSummary ?? [:]

        perfectSessions = sessions.filter { $0.totalAttempts > 0 && $0.successRate >= 1.0 }.count

        // Самая длинная серия идеальных сессий подряд (по дате).
        let chronological = sessions.sorted { $0.date < $1.date }
        var run = 0
        var best = 0
        for session in chronological {
            if session.totalAttempts > 0 && session.successRate >= 1.0 {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        maxPerfectRun = best

        let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
        let correctAttempts = sessions.reduce(0) { $0 + $1.correctAttempts }
        overallAccuracyPercent = totalAttempts > 0
            ? Int((Double(correctAttempts) / Double(totalAttempts) * 100).rounded())
            : 0

        var perSound: [String: Int] = [:]
        for session in sessions where !session.targetSound.isEmpty {
            perSound[session.targetSound, default: 0] += 1
        }
        sessionsPerSound = perSound

        masteredSounds = Set((profile?.progressSummary ?? [:])
            .filter { $0.value >= 0.85 }
            .map(\.key))
    }

    // swiftlint:disable cyclomatic_complexity
    /// Реальное значение прогресса для конкретного достижения.
    /// Плоский dispatch-switch (≈40 достижений → метрика) — высокая цикломатика
    /// здесь это таблица соответствий, а не сложная логика; дробление на подфункции
    /// ухудшило бы читаемость справочника.
    func progress(for key: String) -> Int {
        switch key {
        // Первые шаги.
        case "first_session":    return min(totalSessions, 1)
        case "first_perfect":    return min(perfectSessions, 1)
        case "five_sessions":    return min(totalSessions, 5)
        case "ten_words":        return min(totalSessions, 10)
        case "first_sticker":    return masteredSounds.isEmpty && totalSessions == 0 ? 0 : min(perfectSessions, 1)
        // Звуки (20 завершённых сессий по звуку).
        case "sound_s_mastered": return sessionsPerSound["С"] ?? 0
        case "sound_r_mastered": return sessionsPerSound["Р"] ?? 0
        case "sound_sh_mastered": return sessionsPerSound["Ш"] ?? 0
        case "sound_l_mastered": return sessionsPerSound["Л"] ?? 0
        case "sound_k_mastered": return sessionsPerSound["К"] ?? 0
        // Серии.
        case "streak_3":         return currentStreak
        case "streak_7":         return currentStreak
        case "streak_14":        return currentStreak
        case "streak_30":        return currentStreak
        // Сессии / минуты.
        case "sessions_20":      return totalSessions
        case "sessions_50":      return totalSessions
        case "sessions_100":     return totalSessions
        case "minutes_60":       return totalMinutes
        case "minutes_300":      return totalMinutes
        // Коллекции (по числу освоенных звуков семьи — приближение из реальных
        // данных; точная коллекционная статистика — отдельная фича стикеров).
        case "collection_animals":   return masteredSounds.count
        case "collection_space":     return masteredSounds.count
        case "collection_forest":    return masteredSounds.count
        case "collection_ocean":     return masteredSounds.count
        case "collection_halloween": return 0
        case "collection_newyear":   return 0
        // Качество.
        case "perfect_10_row":   return maxPerfectRun
        case "accuracy_90":      return overallAccuracyPercent
        case "all_sounds":       return masteredSounds.count
        // Редкие находки (требуют реальной коллекции стикеров — пока 0).
        case "rare_sticker":     return 0
        case "epic_sticker":     return 0
        case "legendary_sticker": return 0
        case "all_collections":  return 0
        default:                 return 0
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

// MARK: - MockRewardsRepository (preview / tests)

@MainActor
public final class MockRewardsRepository: RewardsRepository {
    public var snapshot: RewardsSnapshot

    public init(snapshot: RewardsSnapshot? = nil) {
        self.snapshot = snapshot ?? RewardsSnapshot(
            stickers: RewardsCatalog.lockedStickers(),
            achievements: RewardsCatalog.lockedAchievements(),
            wallet: .empty,
            currentStreak: 0
        )
    }

    public func loadSnapshot(childId: String) async -> RewardsSnapshot {
        snapshot
    }
}
