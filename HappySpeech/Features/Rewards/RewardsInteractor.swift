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
/// Все данные — РЕАЛЬНЫЕ, через `RewardsRepository`:
/// - стикеры разблокированы только если реально в инвентаре ребёнка
///   (`StickerInventoryObject`); новый ребёнок видит честный пустой альбом;
/// - достижения с прогрессом, посчитанным из реальных сессий/профиля, и
///   реальными датами разблокировки (`UnlockedAchievementObject`);
/// - кошелёк звёзд: заработано = число `RewardRecord`, потрачено = сумма
///   покупок стикеров;
/// - серия — из `ChildProfileDTO.currentStreak`.
///
/// Локально (UserDefaults) персистится только пользовательский выбор:
/// тема альбома и какие streak-награды уже забраны.
@MainActor
final class RewardsInteractor: RewardsBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any RewardsPresentationLogic)?

    /// Источник реальных данных альбома. Опционален: standalone/preview без
    /// контейнера показывает честный пустой альбом.
    private let repository: (any RewardsRepository)?
    /// Realm-actor для персистенции streak-награды (реальная покупка стикера).
    private let realmActor: RealmActor?

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
    private var currentStreak: Int = 0
    private var claimedStreaks: Set<Int> = []
    private var currentChildId: String = ""

    // MARK: - Init

    init(
        repository: (any RewardsRepository)? = nil,
        realmActor: RealmActor? = nil
    ) {
        self.repository = repository
        self.realmActor = realmActor
        loadPersistedState()
        // Стартовое состояние — честный пустой альбом до загрузки реальных
        // данных (loadRewards подставит реальные стикеры/достижения/кошелёк).
        allStickers = RewardsCatalog.lockedStickers()
        allAchievements = RewardsCatalog.lockedAchievements()
        wallet = .empty
    }

    // MARK: - BusinessLogic: LoadRewards

    func loadRewards(_ request: RewardsModels.LoadRewards.Request) {
        logger.info("loadRewards childId=\(request.childId, privacy: .public) force=\(request.forceReload, privacy: .public)")
        currentChildId = request.childId

        if request.forceReload {
            activeCollection = .all
            sortOrder = .byCollection
        }

        // Синхронно отдаём текущее (возможно ещё пустое) состояние, чтобы UI
        // не мигал. Реальные данные подгружаются ниже асинхронно.
        presentCurrentState()

        guard let repository else {
            // Нет репозитория (preview / standalone) — остаёмся на честном
            // пустом альбоме.
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await repository.loadSnapshot(childId: request.childId)
            self.allStickers = snapshot.stickers
            self.allAchievements = snapshot.achievements
            self.wallet = snapshot.wallet
            self.currentStreak = snapshot.currentStreak
            self.presentCurrentState()
        }
    }

    private func presentCurrentState() {
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

        let collectionComplete = isCollectionComplete(updated.collection)

        logger.info("claimReward id=\(updated.id, privacy: .public) rarity=\(updated.rarity.rawValue, privacy: .public)")
        presenter?.presentClaimReward(.init(sticker: updated))

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

        let reward = StreakReward(
            streakDays: request.streakDays,
            rewardDescription: streakRewardDescription(days: request.streakDays),
            isClaimed: true
        )

        // Реально выдаём (и персистим) стикер за серию: первый ещё не
        // полученный стикер подходящей редкости. Без random в проде —
        // детерминированный выбор первого подходящего.
        let rarity: StickerRarity = request.streakDays >= 30 ? .epic : .common
        if let template = allStickers.first(where: { !$0.isUnlocked && $0.rarity == rarity }) {
            grantStreakSticker(template: template, reward: reward)
        } else {
            logger.info("claimStreakReward days=\(request.streakDays, privacy: .public) sticker=none")
            presenter?.presentClaimStreakReward(.init(reward: reward, grantedSticker: nil))
        }
    }

    /// Помечает стикер разблокированным в локальном состоянии и персистит его
    /// как реальную «покупку» (цена 0 — награда за серию) в Realm.
    private func grantStreakSticker(template: Sticker, reward: StreakReward) {
        guard let index = allStickers.firstIndex(where: { $0.id == template.id }) else {
            presenter?.presentClaimStreakReward(.init(reward: reward, grantedSticker: nil))
            return
        }
        let unlocked = Sticker(
            id: template.id,
            emoji: template.emoji,
            name: template.name,
            collection: template.collection,
            rarity: template.rarity,
            linkedSoundId: template.linkedSoundId,
            isUnlocked: true,
            isNew: true,
            unlockCondition: template.unlockCondition,
            unlockedAt: Date()
        )
        allStickers[index] = unlocked
        logger.info("claimStreakReward days=\(reward.streakDays, privacy: .public) sticker=\(unlocked.id, privacy: .public)")

        let childId = currentChildId
        let stickerId = unlocked.id
        if let realmActor, !childId.isEmpty {
            Task {
                await realmActor.persistStickerPurchase(childId: childId, stickerId: stickerId, price: 0)
            }
        }

        presenter?.presentClaimStreakReward(.init(reward: reward, grantedSticker: unlocked))
        presenter?.presentFilterByCollection(.init(
            stickers: allStickers,
            activeCollection: activeCollection,
            sortOrder: sortOrder
        ))
    }
}

// MARK: - Private: Helpers

private extension RewardsInteractor {

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
}
