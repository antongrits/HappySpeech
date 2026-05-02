import Foundation
import OSLog

// MARK: - RewardsBusinessLogic

@MainActor
protocol RewardsBusinessLogic: AnyObject {
    func loadRewards(_ request: RewardsModels.LoadRewards.Request)
    func filterByCollection(_ request: RewardsModels.FilterByCollection.Request)
    func sortStickers(_ request: RewardsModels.SortStickers.Request)
    func searchStickers(_ request: RewardsModels.SearchStickers.Request)
    func openSticker(_ request: RewardsModels.OpenSticker.Request)
    func claimReward(_ request: RewardsModels.ClaimReward.Request)
    func changeAlbumTheme(_ request: RewardsModels.ChangeAlbumTheme.Request)
    func prepareShare(_ request: RewardsModels.PrepareShare.Request)
    func openAchievement(_ request: RewardsModels.OpenAchievement.Request)
    func claimStreakReward(_ request: RewardsModels.ClaimStreakReward.Request)
}

// MARK: - RewardsInteractor

/// Бизнес-логика «Мой альбом» (kid-контур).
///
/// Возможности:
/// - 6 коллекций стикеров (Animals, Space, Forest, Ocean, Halloween, NewYear)
/// - 72 стикера с редкостью (Common/Rare/Epic/Legendary)
/// - 32 достижения с медалями (Bronze/Silver/Gold) и прогрессом
/// - Кошелёк звёзд (totalEarned / spent / available)
/// - Тема альбома (Bright/Dark/Pastel/Neon), персистентна через UserDefaults
/// - Фильтр по коллекции, сортировка (по коллекции / дате / редкости)
/// - Поиск по имени стикера
/// - Streak-rewards (7 дней → common, 30 дней → epic)
/// - Подготовка ShareSheet (текст + эмодзи топ-стикеров)
/// - Голосовые строки «Ляли» при unlock/completecollection
/// - Reveal-анимация через флаг `isNew`
///
/// На M9 источник данных будет заменён на `RewardsRepository` поверх Realm
/// без изменения VIP-контракта.
@MainActor
final class RewardsInteractor: RewardsBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any RewardsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RewardsInteractor")

    // MARK: - Persistence Keys

    private enum UserDefaultsKey {
        static let albumTheme   = "rewards.albumTheme"
        static let spentStars   = "rewards.starsSpent"
        static let claimedStreaks = "rewards.claimedStreaks"
    }

    // MARK: - State

    private var allStickers: [Sticker] = []
    private var allAchievements: [RewardsAchievement] = []
    private var wallet: StarsWallet = .empty
    private var activeCollection: StickerCollection = .all
    private var sortOrder: RewardsSortOrder = .byCollection
    private var albumTheme: AlbumTheme = .bright
    private var currentStreak: Int = 7
    private var claimedStreaks: Set<Int> = []

    // MARK: - Init

    init() {
        loadPersistedState()
        allStickers = Self.buildStickerCatalog()
        allAchievements = Self.buildAchievementCatalog()
        wallet = Self.computeWallet(
            stickers: allStickers,
            spentStars: UserDefaults.standard.integer(forKey: UserDefaultsKey.spentStars)
        )
    }

    // MARK: - BusinessLogic: LoadRewards

    func loadRewards(_ request: RewardsModels.LoadRewards.Request) {
        logger.info("loadRewards childId=\(request.childId, privacy: .public) force=\(request.forceReload, privacy: .public)")

        if request.forceReload {
            allStickers = Self.buildStickerCatalog()
            allAchievements = Self.buildAchievementCatalog()
            wallet = Self.computeWallet(
                stickers: allStickers,
                spentStars: UserDefaults.standard.integer(forKey: UserDefaultsKey.spentStars)
            )
            activeCollection = .all
            sortOrder = .byCollection
        }

        let streakRewards = buildStreakRewards()
        presenter?.presentLoadRewards(.init(
            stickers: allStickers,
            achievements: allAchievements,
            wallet: wallet,
            activeCollection: activeCollection,
            sortOrder: sortOrder,
            albumTheme: albumTheme,
            streakRewards: streakRewards,
            currentStreak: currentStreak
        ))
    }

    // MARK: - BusinessLogic: FilterByCollection

    func filterByCollection(_ request: RewardsModels.FilterByCollection.Request) {
        activeCollection = request.collection
        logger.info("filterByCollection collection=\(request.collection.rawValue, privacy: .public)")
        presenter?.presentFilterByCollection(.init(
            stickers: allStickers,
            activeCollection: activeCollection,
            sortOrder: sortOrder
        ))
    }

    // MARK: - BusinessLogic: SortStickers

    func sortStickers(_ request: RewardsModels.SortStickers.Request) {
        sortOrder = request.sortOrder
        logger.info("sortStickers order=\(request.sortOrder.rawValue, privacy: .public)")
        presenter?.presentSortStickers(.init(
            stickers: allStickers,
            sortOrder: sortOrder,
            activeCollection: activeCollection
        ))
    }

    // MARK: - BusinessLogic: SearchStickers

    func searchStickers(_ request: RewardsModels.SearchStickers.Request) {
        let trimmed = request.query.trimmingCharacters(in: .whitespaces)
        logger.info("searchStickers query=\(trimmed, privacy: .public)")
        presenter?.presentSearchStickers(.init(
            stickers: allStickers,
            query: trimmed
        ))
    }

    // MARK: - BusinessLogic: OpenSticker

    func openSticker(_ request: RewardsModels.OpenSticker.Request) {
        guard let sticker = allStickers.first(where: { $0.id == request.id }) else {
            logger.warning("openSticker not found id=\(request.id, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "rewards.error.stickerNotFound")
            ))
            return
        }
        logger.info("openSticker id=\(sticker.id, privacy: .public) unlocked=\(sticker.isUnlocked, privacy: .public)")
        presenter?.presentOpenSticker(.init(sticker: sticker))
    }

    // MARK: - BusinessLogic: ClaimReward

    func claimReward(_ request: RewardsModels.ClaimReward.Request) {
        guard let index = allStickers.firstIndex(where: { $0.id == request.id }) else {
            logger.warning("claimReward not found id=\(request.id, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "rewards.error.stickerNotFound")
            ))
            return
        }
        var updated = allStickers[index]
        guard updated.isNew else {
            logger.info("claimReward already claimed id=\(updated.id, privacy: .public)")
            presenter?.presentOpenSticker(.init(sticker: updated))
            return
        }
        updated.isNew = false
        allStickers[index] = updated

        // Обновляем кошелёк — за новый стикер начисляем звёзды согласно редкости
        let earned = rarityStarGrant(rarity: updated.rarity)
        if earned > 0 {
            wallet = StarsWallet(
                totalEarned: wallet.totalEarned + earned,
                totalSpent: wallet.totalSpent
            )
            logger.info("claimReward stars earned=\(earned, privacy: .public) total=\(self.wallet.totalEarned, privacy: .public)")
        }

        // Проверяем, завершена ли коллекция
        let collectionComplete = isCollectionComplete(updated.collection)

        logger.info("claimReward id=\(updated.id, privacy: .public) rarity=\(updated.rarity.rawValue, privacy: .public)")
        presenter?.presentClaimReward(.init(sticker: updated))

        // Переотрисовка сетки после обновления
        presenter?.presentFilterByCollection(.init(
            stickers: allStickers,
            activeCollection: activeCollection,
            sortOrder: sortOrder
        ))

        if collectionComplete {
            logger.info("claimReward collectionComplete=\(updated.collection.rawValue, privacy: .public)")
            announceCollectionComplete(updated.collection)
        }
    }

    // MARK: - BusinessLogic: ChangeAlbumTheme

    func changeAlbumTheme(_ request: RewardsModels.ChangeAlbumTheme.Request) {
        albumTheme = request.theme
        UserDefaults.standard.set(request.theme.rawValue, forKey: UserDefaultsKey.albumTheme)
        logger.info("changeAlbumTheme theme=\(request.theme.rawValue, privacy: .public)")
        let message = String(
            format: String(localized: "rewards.theme.changed"),
            request.theme.displayName
        )
        presenter?.presentChangeAlbumTheme(.init(theme: request.theme))
        presenter?.presentFailure(.init(message: message))
    }

    // MARK: - BusinessLogic: PrepareShare

    func prepareShare(_ request: RewardsModels.PrepareShare.Request) {
        logger.info("prepareShare childId=\(request.childId, privacy: .public)")
        let unlocked = allStickers.filter(\.isUnlocked)
        let top = unlocked
            .sorted { $0.rarity > $1.rarity }
            .prefix(5)
        presenter?.presentPrepareShare(.init(
            unlockedCount: unlocked.count,
            totalCount: allStickers.count,
            topStickers: Array(top),
            childName: String(localized: "rewards.share.defaultChildName")
        ))
    }

    // MARK: - BusinessLogic: OpenAchievement

    func openAchievement(_ request: RewardsModels.OpenAchievement.Request) {
        guard let achievement = allAchievements.first(where: { $0.key == request.key }) else {
            logger.warning("openAchievement not found key=\(request.key, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "rewards.error.achievementNotFound")
            ))
            return
        }
        logger.info("openAchievement key=\(achievement.key, privacy: .public) unlocked=\(achievement.isUnlocked, privacy: .public)")
        presenter?.presentOpenAchievement(.init(achievement: achievement))
    }

    // MARK: - BusinessLogic: ClaimStreakReward

    func claimStreakReward(_ request: RewardsModels.ClaimStreakReward.Request) {
        guard !claimedStreaks.contains(request.streakDays) else {
            logger.info("claimStreakReward already claimed days=\(request.streakDays, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "rewards.streak.alreadyClaimed")
            ))
            return
        }
        guard currentStreak >= request.streakDays else {
            let cur = currentStreak
            let req = request.streakDays
            logger.warning(
                "claimStreakReward streak insufficient current=\(cur, privacy: .public) required=\(req, privacy: .public)"
            )
            presenter?.presentFailure(.init(
                message: String(localized: "rewards.streak.notReached")
            ))
            return
        }
        claimedStreaks.insert(request.streakDays)
        persistClaimedStreaks()

        let grantedSticker = grantStreakSticker(streakDays: request.streakDays)
        logger.info("claimStreakReward days=\(request.streakDays, privacy: .public) sticker=\(grantedSticker?.id ?? "none", privacy: .public)")

        let reward = StreakReward(
            streakDays: request.streakDays,
            rewardDescription: streakRewardDescription(days: request.streakDays),
            isClaimed: true
        )
        presenter?.presentClaimStreakReward(.init(reward: reward, grantedSticker: grantedSticker))

        // Обновляем badge-новинок
        presenter?.presentFilterByCollection(.init(
            stickers: allStickers,
            activeCollection: activeCollection,
            sortOrder: sortOrder
        ))
    }
}

// MARK: - Private: Helpers

private extension RewardsInteractor {

    /// Кол-во звёзд за стикер в зависимости от редкости
    func rarityStarGrant(rarity: StickerRarity) -> Int {
        switch rarity {
        case .common:    return 1
        case .rare:      return 3
        case .epic:      return 8
        case .legendary: return 20
        }
    }

    /// Проверяет, все ли стикеры коллекции разблокированы
    func isCollectionComplete(_ collection: StickerCollection) -> Bool {
        guard collection != .all else { return false }
        let inCollection = allStickers.filter { $0.collection == collection }
        return !inCollection.isEmpty && inCollection.allSatisfy(\.isUnlocked)
    }

    /// Объявляет завершение коллекции через презентер (toast / голос Ляли)
    func announceCollectionComplete(_ collection: StickerCollection) {
        let message = String(
            format: String(localized: "rewards.collection.complete"),
            collection.displayName
        )
        presenter?.presentFailure(.init(message: message))
    }

    /// Выдаёт случайный стикер за streak с учётом редкости
    func grantStreakSticker(streakDays: Int) -> Sticker? {
        let rarity: StickerRarity = streakDays >= 30 ? .epic : .common
        let locked = allStickers.filter { !$0.isUnlocked && $0.rarity == rarity }
        guard let template = locked.randomElement() else { return nil }

        guard let index = allStickers.firstIndex(where: { $0.id == template.id }) else { return nil }
        var unlocked = allStickers[index]
        unlocked = Sticker(
            id: unlocked.id,
            emoji: unlocked.emoji,
            name: unlocked.name,
            collection: unlocked.collection,
            rarity: unlocked.rarity,
            linkedSoundId: unlocked.linkedSoundId,
            isUnlocked: true,
            isNew: true,
            unlockCondition: unlocked.unlockCondition,
            unlockedAt: Date()
        )
        allStickers[index] = unlocked
        return unlocked
    }

    /// Строит список streak-rewards с флагом isClaimed
    func buildStreakRewards() -> [StreakReward] {
        let milestones = [7, 14, 30]
        return milestones.map { days in
            StreakReward(
                streakDays: days,
                rewardDescription: streakRewardDescription(days: days),
                isClaimed: claimedStreaks.contains(days)
            )
        }
    }

    func streakRewardDescription(days: Int) -> String {
        switch days {
        case 7:  return String(localized: "rewards.streak.7days.desc")
        case 14: return String(localized: "rewards.streak.14days.desc")
        case 30: return String(localized: "rewards.streak.30days.desc")
        default: return String(format: String(localized: "rewards.streak.generic.desc"), days)
        }
    }

    // MARK: - Persist

    func loadPersistedState() {
        if let raw = UserDefaults.standard.string(forKey: UserDefaultsKey.albumTheme),
           let theme = AlbumTheme(rawValue: raw) {
            albumTheme = theme
        }
        let claimedArray = UserDefaults.standard.array(forKey: UserDefaultsKey.claimedStreaks) as? [Int] ?? []
        claimedStreaks = Set(claimedArray)
    }

    func persistClaimedStreaks() {
        UserDefaults.standard.set(Array(claimedStreaks), forKey: UserDefaultsKey.claimedStreaks)
    }

    // MARK: - Wallet

    static func computeWallet(stickers: [Sticker], spentStars: Int) -> StarsWallet {
        let earned = stickers.filter(\.isUnlocked).reduce(0) { acc, s in
            switch s.rarity {
            case .common:    return acc + 1
            case .rare:      return acc + 3
            case .epic:      return acc + 8
            case .legendary: return acc + 20
            }
        }
        return StarsWallet(totalEarned: earned, totalSpent: spentStars)
    }
}

// MARK: - Seed: Sticker Catalog (72 стикера, 6 коллекций × 12)

private extension RewardsInteractor {

    static func buildStickerCatalog() -> [Sticker] {
        let now = Date()
        return animalsStickers(now: now)
            + spaceStickers(now: now)
            + forestStickers(now: now)
            + oceanStickers(now: now)
            + halloweenStickers()
            + newYearStickers()
    }

    // MARK: - Animals (12)

    static func animalsStickers(now: Date) -> [Sticker] {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date? { cal.date(byAdding: .day, value: -n, to: now) }
        return [
            Sticker(id: "animals.cat",    emoji: "🐱", name: String(localized: "rewards.sticker.cat"),
                    collection: .animals, rarity: .common,
                    isUnlocked: true,  isNew: false,
                    unlockCondition: String(localized: "rewards.cond.cat"),    unlockedAt: daysAgo(4)),
            Sticker(id: "animals.dog",    emoji: "🐶", name: String(localized: "rewards.sticker.dog"),
                    collection: .animals, rarity: .common,
                    isUnlocked: true,  isNew: true,
                    unlockCondition: String(localized: "rewards.cond.dog"),    unlockedAt: daysAgo(1)),
            Sticker(id: "animals.fox",    emoji: "🦊", name: String(localized: "rewards.sticker.fox"),
                    collection: .animals, rarity: .rare,
                    isUnlocked: true,  isNew: false,
                    unlockCondition: String(localized: "rewards.cond.fox"),    unlockedAt: daysAgo(8)),
            Sticker(id: "animals.bear",   emoji: "🐻", name: String(localized: "rewards.sticker.bear"),
                    collection: .animals, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.bear"),   unlockedAt: nil),
            Sticker(id: "animals.panda",  emoji: "🐼", name: String(localized: "rewards.sticker.panda"),
                    collection: .animals, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.panda"),  unlockedAt: nil),
            Sticker(id: "animals.lion",   emoji: "🦁", name: String(localized: "rewards.sticker.lion"),
                    collection: .animals, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.lion"),   unlockedAt: nil),
            Sticker(id: "animals.tiger",  emoji: "🐯", name: String(localized: "rewards.sticker.tiger"),
                    collection: .animals, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.tiger"),  unlockedAt: nil),
            Sticker(id: "animals.frog",   emoji: "🐸", name: String(localized: "rewards.sticker.frog"),
                    collection: .animals, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.frog"),   unlockedAt: nil),
            Sticker(id: "animals.bunny",  emoji: "🐰", name: String(localized: "rewards.sticker.bunny"),
                    collection: .animals, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.bunny"),  unlockedAt: nil),
            Sticker(id: "animals.horse",  emoji: "🐴", name: String(localized: "rewards.sticker.horse"),
                    collection: .animals, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.horse"),  unlockedAt: nil),
            Sticker(id: "animals.owl",    emoji: "🦉", name: String(localized: "rewards.sticker.owl"),
                    collection: .animals, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.owl"),    unlockedAt: nil),
            Sticker(id: "animals.dragon", emoji: "🐲", name: String(localized: "rewards.sticker.dragon"),
                    collection: .animals, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.dragon"), unlockedAt: nil)
        ]
    }

    // MARK: - Space (12)

    static func spaceStickers(now: Date) -> [Sticker] {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date? { cal.date(byAdding: .day, value: -n, to: now) }
        return [
            Sticker(id: "space.rocket",   emoji: "🚀", name: String(localized: "rewards.sticker.rocket"),
                    collection: .space, rarity: .common,
                    isUnlocked: true,  isNew: false,
                    unlockCondition: String(localized: "rewards.cond.rocket"),  unlockedAt: daysAgo(3)),
            Sticker(id: "space.star",     emoji: "⭐", name: String(localized: "rewards.sticker.star"),
                    collection: .space, rarity: .common,
                    isUnlocked: true,  isNew: false,
                    unlockCondition: String(localized: "rewards.cond.star"),    unlockedAt: daysAgo(5)),
            Sticker(id: "space.planet",   emoji: "🪐", name: String(localized: "rewards.sticker.planet"),
                    collection: .space, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.planet"),  unlockedAt: nil),
            Sticker(id: "space.moon",     emoji: "🌙", name: String(localized: "rewards.sticker.moon"),
                    collection: .space, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.moon"),    unlockedAt: nil),
            Sticker(id: "space.comet",    emoji: "☄️", name: String(localized: "rewards.sticker.comet"),
                    collection: .space, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.comet"),   unlockedAt: nil),
            Sticker(id: "space.alien",    emoji: "👽", name: String(localized: "rewards.sticker.alien"),
                    collection: .space, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.alien"),   unlockedAt: nil),
            Sticker(id: "space.ufo",      emoji: "🛸", name: String(localized: "rewards.sticker.ufo"),
                    collection: .space, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.ufo"),     unlockedAt: nil),
            Sticker(id: "space.sun",      emoji: "☀️", name: String(localized: "rewards.sticker.sun"),
                    collection: .space, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.sun"),     unlockedAt: nil),
            Sticker(id: "space.galaxy",   emoji: "🌌", name: String(localized: "rewards.sticker.galaxy"),
                    collection: .space, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.galaxy"),  unlockedAt: nil),
            Sticker(id: "space.satellite",emoji: "🛰️", name: String(localized: "rewards.sticker.satellite"),
                    collection: .space, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.satellite"),unlockedAt: nil),
            Sticker(id: "space.astronaut",emoji: "👨‍🚀", name: String(localized: "rewards.sticker.astronaut"),
                    collection: .space, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.astronaut"),unlockedAt: nil),
            Sticker(id: "space.blackhole",emoji: "🕳️", name: String(localized: "rewards.sticker.blackhole"),
                    collection: .space, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.blackhole"),unlockedAt: nil)
        ]
    }

    // MARK: - Forest (12)

    static func forestStickers(now: Date) -> [Sticker] {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date? { cal.date(byAdding: .day, value: -n, to: now) }
        return [
            Sticker(id: "forest.mushroom",emoji: "🍄", name: String(localized: "rewards.sticker.mushroom"),
                    collection: .forest, rarity: .common,
                    isUnlocked: true,  isNew: false,
                    unlockCondition: String(localized: "rewards.cond.mushroom"), unlockedAt: daysAgo(6)),
            Sticker(id: "forest.tree",    emoji: "🌲", name: String(localized: "rewards.sticker.tree"),
                    collection: .forest, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.tree"),    unlockedAt: nil),
            Sticker(id: "forest.leaf",    emoji: "🍃", name: String(localized: "rewards.sticker.leaf"),
                    collection: .forest, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.leaf"),    unlockedAt: nil),
            Sticker(id: "forest.snail",   emoji: "🐌", name: String(localized: "rewards.sticker.snail"),
                    collection: .forest, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.snail"),   unlockedAt: nil),
            Sticker(id: "forest.hedgehog",emoji: "🦔", name: String(localized: "rewards.sticker.hedgehog"),
                    collection: .forest, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.hedgehog"),unlockedAt: nil),
            Sticker(id: "forest.butterfly",emoji:"🦋", name: String(localized: "rewards.sticker.butterfly"),
                    collection: .forest, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.butterfly"),unlockedAt: nil),
            Sticker(id: "forest.deer",    emoji: "🦌", name: String(localized: "rewards.sticker.deer"),
                    collection: .forest, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.deer"),    unlockedAt: nil),
            Sticker(id: "forest.acorn",   emoji: "🌰", name: String(localized: "rewards.sticker.acorn"),
                    collection: .forest, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.acorn"),   unlockedAt: nil),
            Sticker(id: "forest.fern",    emoji: "🌿", name: String(localized: "rewards.sticker.fern"),
                    collection: .forest, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.fern"),    unlockedAt: nil),
            Sticker(id: "forest.squirrel",emoji: "🐿️", name: String(localized: "rewards.sticker.squirrel"),
                    collection: .forest, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.squirrel"),unlockedAt: nil),
            Sticker(id: "forest.wolf",    emoji: "🐺", name: String(localized: "rewards.sticker.wolf"),
                    collection: .forest, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.wolf"),    unlockedAt: nil),
            Sticker(id: "forest.phoenix", emoji: "🦚", name: String(localized: "rewards.sticker.phoenix"),
                    collection: .forest, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.phoenix"), unlockedAt: nil)
        ]
    }

    // MARK: - Ocean (12)

    static func oceanStickers(now: Date) -> [Sticker] {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date? { cal.date(byAdding: .day, value: -n, to: now) }
        return [
            Sticker(id: "ocean.wave",     emoji: "🌊", name: String(localized: "rewards.sticker.wave"),
                    collection: .ocean, rarity: .common,
                    isUnlocked: true,  isNew: false,
                    unlockCondition: String(localized: "rewards.cond.wave"),    unlockedAt: daysAgo(2)),
            Sticker(id: "ocean.fish",     emoji: "🐟", name: String(localized: "rewards.sticker.fish"),
                    collection: .ocean, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.fish"),    unlockedAt: nil),
            Sticker(id: "ocean.crab",     emoji: "🦀", name: String(localized: "rewards.sticker.crab"),
                    collection: .ocean, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.crab"),    unlockedAt: nil),
            Sticker(id: "ocean.dolphin",  emoji: "🐬", name: String(localized: "rewards.sticker.dolphin"),
                    collection: .ocean, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.dolphin"), unlockedAt: nil),
            Sticker(id: "ocean.turtle",   emoji: "🐢", name: String(localized: "rewards.sticker.turtle"),
                    collection: .ocean, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.turtle"),  unlockedAt: nil),
            Sticker(id: "ocean.shark",    emoji: "🦈", name: String(localized: "rewards.sticker.shark"),
                    collection: .ocean, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.shark"),   unlockedAt: nil),
            Sticker(id: "ocean.octopus",  emoji: "🐙", name: String(localized: "rewards.sticker.octopus"),
                    collection: .ocean, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.octopus"), unlockedAt: nil),
            Sticker(id: "ocean.seahorse", emoji: "🦄", name: String(localized: "rewards.sticker.seahorse"),
                    collection: .ocean, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.seahorse"),unlockedAt: nil),
            Sticker(id: "ocean.jellyfish",emoji: "🪼", name: String(localized: "rewards.sticker.jellyfish"),
                    collection: .ocean, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.jellyfish"),unlockedAt: nil),
            Sticker(id: "ocean.whale",    emoji: "🐋", name: String(localized: "rewards.sticker.whale"),
                    collection: .ocean, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.whale"),   unlockedAt: nil),
            Sticker(id: "ocean.lobster",  emoji: "🦞", name: String(localized: "rewards.sticker.lobster"),
                    collection: .ocean, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.lobster"), unlockedAt: nil),
            Sticker(id: "ocean.mermaid",  emoji: "🧜", name: String(localized: "rewards.sticker.mermaid"),
                    collection: .ocean, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.mermaid"), unlockedAt: nil)
        ]
    }

    // MARK: - Halloween (12)

    static func halloweenStickers() -> [Sticker] {
        return [
            Sticker(id: "halloween.pumpkin", emoji: "🎃", name: String(localized: "rewards.sticker.pumpkin"),
                    collection: .halloween, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.pumpkin"), unlockedAt: nil),
            Sticker(id: "halloween.ghost",   emoji: "👻", name: String(localized: "rewards.sticker.ghost"),
                    collection: .halloween, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.ghost"),   unlockedAt: nil),
            Sticker(id: "halloween.bat",     emoji: "🦇", name: String(localized: "rewards.sticker.bat"),
                    collection: .halloween, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.bat"),     unlockedAt: nil),
            Sticker(id: "halloween.spider",  emoji: "🕷️", name: String(localized: "rewards.sticker.spider"),
                    collection: .halloween, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.spider"),  unlockedAt: nil),
            Sticker(id: "halloween.witch",   emoji: "🧙", name: String(localized: "rewards.sticker.witch"),
                    collection: .halloween, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.witch"),   unlockedAt: nil),
            Sticker(id: "halloween.skeleton",emoji: "💀", name: String(localized: "rewards.sticker.skeleton"),
                    collection: .halloween, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.skeleton"),unlockedAt: nil),
            Sticker(id: "halloween.vampire", emoji: "🧛", name: String(localized: "rewards.sticker.vampire"),
                    collection: .halloween, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.vampire"), unlockedAt: nil),
            Sticker(id: "halloween.zombie",  emoji: "🧟", name: String(localized: "rewards.sticker.zombie"),
                    collection: .halloween, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.zombie"),  unlockedAt: nil),
            Sticker(id: "halloween.cauldron",emoji: "🪄", name: String(localized: "rewards.sticker.cauldron"),
                    collection: .halloween, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.cauldron"),unlockedAt: nil),
            Sticker(id: "halloween.moon",    emoji: "🌕", name: String(localized: "rewards.sticker.fullmoon"),
                    collection: .halloween, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.fullmoon"),unlockedAt: nil),
            Sticker(id: "halloween.potion",  emoji: "🧪", name: String(localized: "rewards.sticker.potion"),
                    collection: .halloween, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.potion"),  unlockedAt: nil),
            Sticker(id: "halloween.demon",   emoji: "😈", name: String(localized: "rewards.sticker.demon"),
                    collection: .halloween, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.demon"),   unlockedAt: nil)
        ]
    }

    // MARK: - New Year (12)

    static func newYearStickers() -> [Sticker] {
        return [
            Sticker(id: "newyear.fireworks",emoji: "🎆", name: String(localized: "rewards.sticker.fireworks"),
                    collection: .newYear, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.fireworks"),unlockedAt: nil),
            Sticker(id: "newyear.gift",     emoji: "🎁", name: String(localized: "rewards.sticker.gift"),
                    collection: .newYear, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.gift"),    unlockedAt: nil),
            Sticker(id: "newyear.tree",     emoji: "🎄", name: String(localized: "rewards.sticker.xmastree"),
                    collection: .newYear, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.xmastree"),unlockedAt: nil),
            Sticker(id: "newyear.bell",     emoji: "🔔", name: String(localized: "rewards.sticker.bell"),
                    collection: .newYear, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.bell"),    unlockedAt: nil),
            Sticker(id: "newyear.candy",    emoji: "🍬", name: String(localized: "rewards.sticker.candy"),
                    collection: .newYear, rarity: .common,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.candy"),   unlockedAt: nil),
            Sticker(id: "newyear.snowflake",emoji: "❄️", name: String(localized: "rewards.sticker.snowflake"),
                    collection: .newYear, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.snowflake"),unlockedAt: nil),
            Sticker(id: "newyear.snowman",  emoji: "⛄", name: String(localized: "rewards.sticker.snowman"),
                    collection: .newYear, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.snowman"), unlockedAt: nil),
            Sticker(id: "newyear.champagne",emoji: "🍾", name: String(localized: "rewards.sticker.champagne"),
                    collection: .newYear, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.champagne"),unlockedAt: nil),
            Sticker(id: "newyear.santahat", emoji: "🎅", name: String(localized: "rewards.sticker.santa"),
                    collection: .newYear, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.santa"),   unlockedAt: nil),
            Sticker(id: "newyear.reindeer", emoji: "🦌", name: String(localized: "rewards.sticker.reindeer"),
                    collection: .newYear, rarity: .epic,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.reindeer"),unlockedAt: nil),
            Sticker(id: "newyear.elf",      emoji: "🧝", name: String(localized: "rewards.sticker.elf"),
                    collection: .newYear, rarity: .rare,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.elf"),     unlockedAt: nil),
            Sticker(id: "newyear.unicorn",  emoji: "🦄", name: String(localized: "rewards.sticker.unicorn"),
                    collection: .newYear, rarity: .legendary,
                    isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.unicorn"), unlockedAt: nil)
        ]
    }
}

// MARK: - Seed: Achievement Catalog (32 достижения)

private extension RewardsInteractor {

    struct AchievementDefinition {
        let key: String
        let emoji: String
        let medal: RewardsAchievement.Medal
        let required: Int
        let current: Int

        init(
            _ key: String,
            _ emoji: String,
            _ medal: RewardsAchievement.Medal,
            _ required: Int,
            _ current: Int
        ) {
            self.key = key
            self.emoji = emoji
            self.medal = medal
            self.required = required
            self.current = current
        }
    }

    static func buildAchievementCatalog() -> [RewardsAchievement] {
        let definitions: [AchievementDefinition] = [
            // Первые шаги (Bronze)
            .init("first_session",       "🎉",  .bronze,  1,   1),
            .init("first_perfect",       "⭐",  .bronze,  1,   1),
            .init("five_sessions",       "🔢",  .bronze,  5,   5),
            .init("ten_words",           "📝",  .bronze, 10,  10),
            .init("first_sticker",       "🏷️",  .bronze,  1,   1),
            // Звуки (Bronze / Silver)
            .init("sound_s_mastered",    "🐝",  .silver, 20,  12),
            .init("sound_r_mastered",    "🎸",  .silver, 20,   0),
            .init("sound_sh_mastered",   "🌊",  .silver, 20,   0),
            .init("sound_l_mastered",    "🌿",  .silver, 20,   0),
            .init("sound_k_mastered",    "🐸",  .bronze, 20,   0),
            // Серии (Silver)
            .init("streak_3",            "🔥",  .bronze,  3,   3),
            .init("streak_7",            "🌟",  .silver,  7,   7),
            .init("streak_14",           "💫",  .silver, 14,   7),
            .init("streak_30",           "🏆",  .gold,   30,   7),
            // Сессии (Silver / Gold)
            .init("sessions_20",         "📚",  .silver, 20,   7),
            .init("sessions_50",         "🎓",  .gold,   50,   7),
            .init("sessions_100",        "👑",  .gold,  100,   7),
            .init("minutes_60",          "⏱️",  .silver, 60,  35),
            .init("minutes_300",         "⏰",  .gold,  300,  35),
            // Коллекции (Silver / Gold)
            .init("collection_animals",  "🐾",  .silver, 12,   3),
            .init("collection_space",    "🚀",  .silver, 12,   2),
            .init("collection_forest",   "🌲",  .silver, 12,   1),
            .init("collection_ocean",    "🌊",  .silver, 12,   1),
            .init("collection_halloween","🎃",  .gold,   12,   0),
            .init("collection_newyear",  "🎆",  .gold,   12,   0),
            // Качество (Gold)
            .init("perfect_10_row",      "💎",  .gold,   10,   4),
            .init("accuracy_90",         "🎯",  .gold,  100,  35),
            .init("all_sounds",          "🎵",  .gold,    4,   1),
            // Редкие находки (Gold)
            .init("rare_sticker",        "🔮",  .gold,    1,   0),
            .init("epic_sticker",        "✨",  .gold,    1,   0),
            .init("legendary_sticker",   "🌈",  .gold,    1,   0),
            .init("all_collections",     "🏅",  .gold,    6,   0)
        ]

        return definitions.map { def in
            RewardsAchievement(
                id: def.key,
                key: def.key,
                emoji: def.emoji,
                title: String(localized: "rewards.achievement.\(def.key).title"),
                hint: String(localized: "rewards.achievement.\(def.key).hint"),
                medal: def.medal,
                requiredProgress: def.required,
                currentProgress: def.current,
                isUnlocked: def.current >= def.required,
                unlockedAt: def.current >= def.required ? Calendar.current.date(byAdding: .day, value: -Int.random(in: 0...10), to: Date()) : nil
            )
        }
    }
}
