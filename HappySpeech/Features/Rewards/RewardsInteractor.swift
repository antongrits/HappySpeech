import Foundation
import OSLog

// MARK: - RewardsBusinessLogic

@MainActor
protocol RewardsBusinessLogic: AnyObject {
    func loadRewards(_ request: RewardsModels.LoadRewards.Request)
    func filterByCollection(_ request: RewardsModels.FilterByCollection.Request)
    func openSticker(_ request: RewardsModels.OpenSticker.Request)
    func claimReward(_ request: RewardsModels.ClaimReward.Request)
}

// MARK: - RewardsInteractor

/// Бизнес-логика «Мои награды».
///
/// В M7.2 источник данных — in-memory seed (24 стикера в 4 коллекциях,
/// 5 unlocked, на двух стоит флаг `isNew`). На M8 будет подключён
/// `RewardsRepository` поверх Realm + Firestore — без изменений контракта.
@MainActor
final class RewardsInteractor: RewardsBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any RewardsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Rewards")

    // MARK: - State

    private var allStickers: [Sticker] = []
    private var activeCollection: StickerCollection = .all

    // MARK: - Init

    init() {
        allStickers = Self.makeSeed()
    }

    // MARK: - BusinessLogic

    func loadRewards(_ request: RewardsModels.LoadRewards.Request) {
        logger.info("loadRewards childId=\(request.childId, privacy: .public) force=\(request.forceReload, privacy: .public)")
        if request.forceReload {
            allStickers = Self.makeSeed()
            activeCollection = .all
        }
        presenter?.presentLoadRewards(.init(
            stickers: allStickers,
            activeCollection: activeCollection
        ))
    }

    func filterByCollection(_ request: RewardsModels.FilterByCollection.Request) {
        activeCollection = request.collection
        logger.info("filterByCollection collection=\(request.collection.rawValue, privacy: .public)")
        presenter?.presentFilterByCollection(.init(
            stickers: allStickers,
            activeCollection: activeCollection
        ))
    }

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

    func claimReward(_ request: RewardsModels.ClaimReward.Request) {
        guard let index = allStickers.firstIndex(where: { $0.id == request.id }) else {
            logger.warning("claimReward not found id=\(request.id, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "rewards.error.stickerNotFound")
            ))
            return
        }
        // Mark as seen (consume `isNew`).
        var updated = allStickers[index]
        if updated.isNew {
            updated.isNew = false
            allStickers[index] = updated
        }
        logger.info("claimReward id=\(updated.id, privacy: .public)")
        presenter?.presentClaimReward(.init(sticker: updated))
        presenter?.presentFilterByCollection(.init(
            stickers: allStickers,
            activeCollection: activeCollection
        ))
    }
}

// MARK: - Seed

private extension RewardsInteractor {

    static func makeSeed() -> [Sticker] {
        let now = Date()
        let calendar = Calendar.current
        func daysAgo(_ d: Int) -> Date? {
            calendar.date(byAdding: .day, value: -d, to: now)
        }

        return [
            // Stars (6)
            Sticker(id: "star.first",     emoji: "⭐",  name: String(localized: "rewards.sticker.firstStar"),
                    collection: .stars, isUnlocked: true, isNew: true,
                    unlockCondition: String(localized: "rewards.cond.firstStar"),
                    unlockedAt: daysAgo(0)),
            Sticker(id: "star.streak3",   emoji: "🌟",  name: String(localized: "rewards.sticker.streak3"),
                    collection: .stars, isUnlocked: true, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.streak3"),
                    unlockedAt: daysAgo(2)),
            Sticker(id: "star.streak7",   emoji: "💫",  name: String(localized: "rewards.sticker.streak7"),
                    collection: .stars, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.streak7"),
                    unlockedAt: nil),
            Sticker(id: "star.streak30",  emoji: "✨",  name: String(localized: "rewards.sticker.streak30"),
                    collection: .stars, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.streak30"),
                    unlockedAt: nil),
            Sticker(id: "star.perfect",   emoji: "🌠",  name: String(localized: "rewards.sticker.perfect"),
                    collection: .stars, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.perfect"),
                    unlockedAt: nil),
            Sticker(id: "star.shine",     emoji: "🪐",  name: String(localized: "rewards.sticker.shine"),
                    collection: .stars, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.shine"),
                    unlockedAt: nil),

            // Animals (8)
            Sticker(id: "animal.cat",     emoji: "🐱",  name: String(localized: "rewards.sticker.cat"),
                    collection: .animals, isUnlocked: true, isNew: true,
                    unlockCondition: String(localized: "rewards.cond.cat"),
                    unlockedAt: daysAgo(1)),
            Sticker(id: "animal.dog",     emoji: "🐶",  name: String(localized: "rewards.sticker.dog"),
                    collection: .animals, isUnlocked: true, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.dog"),
                    unlockedAt: daysAgo(4)),
            Sticker(id: "animal.fox",     emoji: "🦊",  name: String(localized: "rewards.sticker.fox"),
                    collection: .animals, isUnlocked: true, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.fox"),
                    unlockedAt: daysAgo(8)),
            Sticker(id: "animal.bear",    emoji: "🐻",  name: String(localized: "rewards.sticker.bear"),
                    collection: .animals, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.bear"),
                    unlockedAt: nil),
            Sticker(id: "animal.panda",   emoji: "🐼",  name: String(localized: "rewards.sticker.panda"),
                    collection: .animals, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.panda"),
                    unlockedAt: nil),
            Sticker(id: "animal.lion",    emoji: "🦁",  name: String(localized: "rewards.sticker.lion"),
                    collection: .animals, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.lion"),
                    unlockedAt: nil),
            Sticker(id: "animal.tiger",   emoji: "🐯",  name: String(localized: "rewards.sticker.tiger"),
                    collection: .animals, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.tiger"),
                    unlockedAt: nil),
            Sticker(id: "animal.frog",    emoji: "🐸",  name: String(localized: "rewards.sticker.frog"),
                    collection: .animals, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.frog"),
                    unlockedAt: nil),

            // Letters (6)
            Sticker(id: "letter.s",       emoji: "🅂",  name: String(localized: "rewards.sticker.letterS"),
                    collection: .letters, isUnlocked: true, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.letterS"),
                    unlockedAt: daysAgo(10)),
            Sticker(id: "letter.r",       emoji: "🆁",  name: String(localized: "rewards.sticker.letterR"),
                    collection: .letters, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.letterR"),
                    unlockedAt: nil),
            Sticker(id: "letter.l",       emoji: "🅻",  name: String(localized: "rewards.sticker.letterL"),
                    collection: .letters, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.letterL"),
                    unlockedAt: nil),
            Sticker(id: "letter.sh",      emoji: "Ш",  name: String(localized: "rewards.sticker.letterSh"),
                    collection: .letters, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.letterSh"),
                    unlockedAt: nil),
            Sticker(id: "letter.zh",      emoji: "Ж",  name: String(localized: "rewards.sticker.letterZh"),
                    collection: .letters, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.letterZh"),
                    unlockedAt: nil),
            Sticker(id: "letter.k",       emoji: "К",  name: String(localized: "rewards.sticker.letterK"),
                    collection: .letters, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.letterK"),
                    unlockedAt: nil),

            // Holidays (4)
            Sticker(id: "holiday.gift",   emoji: "🎁", name: String(localized: "rewards.sticker.gift"),
                    collection: .holidays, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.gift"),
                    unlockedAt: nil),
            Sticker(id: "holiday.cake",   emoji: "🎂", name: String(localized: "rewards.sticker.cake"),
                    collection: .holidays, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.cake"),
                    unlockedAt: nil),
            Sticker(id: "holiday.party",  emoji: "🎉", name: String(localized: "rewards.sticker.party"),
                    collection: .holidays, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.party"),
                    unlockedAt: nil),
            Sticker(id: "holiday.balloon", emoji: "🎈", name: String(localized: "rewards.sticker.balloon"),
                    collection: .holidays, isUnlocked: false, isNew: false,
                    unlockCondition: String(localized: "rewards.cond.balloon"),
                    unlockedAt: nil)
        ]
    }
}
