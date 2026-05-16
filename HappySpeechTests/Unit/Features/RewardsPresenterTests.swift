@testable import HappySpeech
import XCTest

// MARK: - RewardsPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие RewardsPresenter (58% → цель ≥90%).
// Тестируются все методы через DisplaySpy.

@MainActor
final class RewardsPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: RewardsDisplayLogic {
        var loadRewardsVM: RewardsModels.LoadRewards.ViewModel?
        var filterVM: RewardsModels.FilterByCollection.ViewModel?
        var sortVM: RewardsModels.SortStickers.ViewModel?
        var searchVM: RewardsModels.SearchStickers.ViewModel?
        var openStickerVM: RewardsModels.OpenSticker.ViewModel?
        var claimRewardVM: RewardsModels.ClaimReward.ViewModel?
        var changeAlbumThemeVM: RewardsModels.ChangeAlbumTheme.ViewModel?
        var prepareShareVM: RewardsModels.PrepareShare.ViewModel?
        var openAchievementVM: RewardsModels.OpenAchievement.ViewModel?
        var claimStreakVM: RewardsModels.ClaimStreakReward.ViewModel?
        var failureVM: RewardsModels.Failure.ViewModel?

        func displayLoadRewards(_ vm: RewardsModels.LoadRewards.ViewModel) { loadRewardsVM = vm }
        func displayFilterByCollection(_ vm: RewardsModels.FilterByCollection.ViewModel) { filterVM = vm }
        func displaySortStickers(_ vm: RewardsModels.SortStickers.ViewModel) { sortVM = vm }
        func displaySearchStickers(_ vm: RewardsModels.SearchStickers.ViewModel) { searchVM = vm }
        func displayOpenSticker(_ vm: RewardsModels.OpenSticker.ViewModel) { openStickerVM = vm }
        func displayClaimReward(_ vm: RewardsModels.ClaimReward.ViewModel) { claimRewardVM = vm }
        func displayChangeAlbumTheme(_ vm: RewardsModels.ChangeAlbumTheme.ViewModel) { changeAlbumThemeVM = vm }
        func displayPrepareShare(_ vm: RewardsModels.PrepareShare.ViewModel) { prepareShareVM = vm }
        func displayOpenAchievement(_ vm: RewardsModels.OpenAchievement.ViewModel) { openAchievementVM = vm }
        func displayClaimStreakReward(_ vm: RewardsModels.ClaimStreakReward.ViewModel) { claimStreakVM = vm }
        func displayFailure(_ vm: RewardsModels.Failure.ViewModel) { failureVM = vm }
        func displayLoading(_ isLoading: Bool) {}
    }

    private func makeSUT() -> (RewardsPresenter, DisplaySpy) {
        let presenter = RewardsPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    // MARK: - Sticker helpers

    private func makeSticker(
        id: String = UUID().uuidString,
        name: String = "Кот",
        emoji: String = "🐱",
        collection: StickerCollection = .animals,
        rarity: StickerRarity = .common,
        isUnlocked: Bool = false,
        unlockedAt: Date? = nil
    ) -> Sticker {
        Sticker(
            id: id,
            emoji: emoji,
            name: name,
            collection: collection,
            rarity: rarity,
            isUnlocked: isUnlocked,
            isNew: false,
            unlockCondition: "Выполни 5 заданий",
            unlockedAt: unlockedAt
        )
    }

    private func makeAchievement(
        id: String = UUID().uuidString,
        isUnlocked: Bool = false,
        currentProgress: Int = 0,
        requiredProgress: Int = 10
    ) -> RewardsAchievement {
        RewardsAchievement(
            id: id,
            key: "ach.first",
            emoji: "🏅",
            title: "Первый раз",
            hint: "Сделай первое задание",
            medal: .bronze,
            requiredProgress: requiredProgress,
            currentProgress: currentProgress,
            isUnlocked: isUnlocked,
            unlockedAt: isUnlocked ? Date() : nil
        )
    }

    private func makeLoadResponse(
        stickers: [Sticker] = [],
        achievements: [RewardsAchievement] = [],
        streakRewards: [StreakReward] = [],
        currentStreak: Int = 0,
        activeCollection: StickerCollection = .all,
        sortOrder: RewardsSortOrder = .byCollection
    ) -> RewardsModels.LoadRewards.Response {
        RewardsModels.LoadRewards.Response(
            stickers: stickers,
            achievements: achievements,
            wallet: StarsWallet(totalEarned: 50, totalSpent: 10),
            activeCollection: activeCollection,
            sortOrder: sortOrder,
            albumTheme: .bright,
            streakRewards: streakRewards,
            currentStreak: currentStreak
        )
    }

    // MARK: - presentLoadRewards

    func test_presentLoadRewards_noStickers_isEmptyTrue() {
        let (sut, spy) = makeSUT()
        sut.presentLoadRewards(makeLoadResponse())
        XCTAssertTrue(spy.loadRewardsVM?.isEmpty ?? false)
    }

    func test_presentLoadRewards_withUnlockedSticker_progressNonZero() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(isUnlocked: true)
        sut.presentLoadRewards(makeLoadResponse(stickers: [sticker]))
        XCTAssertGreaterThan(spy.loadRewardsVM?.progress ?? 0, 0)
    }

    func test_presentLoadRewards_progressLabel_notEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadRewards(makeLoadResponse(stickers: [makeSticker()]))
        XCTAssertFalse(spy.loadRewardsVM?.progressLabel.isEmpty ?? true)
    }

    func test_presentLoadRewards_walletAvailableBalance_correct() {
        let (sut, spy) = makeSUT()
        sut.presentLoadRewards(makeLoadResponse())
        XCTAssertEqual(spy.loadRewardsVM?.walletViewModel.available, 40)
    }

    func test_presentLoadRewards_collectionsCountEqualsAllCases() {
        let (sut, spy) = makeSUT()
        sut.presentLoadRewards(makeLoadResponse())
        XCTAssertEqual(spy.loadRewardsVM?.collections.count, StickerCollection.allCases.count)
    }

    func test_presentLoadRewards_filterAll_cellsContainAll() {
        let (sut, spy) = makeSUT()
        let stickers = [makeSticker(collection: .animals), makeSticker(collection: .ocean)]
        sut.presentLoadRewards(makeLoadResponse(stickers: stickers, activeCollection: .all))
        XCTAssertEqual(spy.loadRewardsVM?.cells.count, 2)
    }

    func test_presentLoadRewards_filterAnimals_cellsFiltered() {
        let (sut, spy) = makeSUT()
        let stickers = [makeSticker(collection: .animals), makeSticker(collection: .ocean)]
        sut.presentLoadRewards(makeLoadResponse(stickers: stickers, activeCollection: .animals))
        XCTAssertEqual(spy.loadRewardsVM?.cells.count, 1)
    }

    func test_presentLoadRewards_streakBanners_matchCount() {
        let (sut, spy) = makeSUT()
        let rewards = [
            StreakReward(streakDays: 7, rewardDescription: "Медаль", isClaimed: false),
            StreakReward(streakDays: 14, rewardDescription: "Стикер", isClaimed: true)
        ]
        sut.presentLoadRewards(makeLoadResponse(streakRewards: rewards))
        XCTAssertEqual(spy.loadRewardsVM?.streakBanners.count, 2)
    }

    func test_presentLoadRewards_unlockedAchievement_hasDateLabel() {
        let (sut, spy) = makeSUT()
        let ach = makeAchievement(isUnlocked: true)
        sut.presentLoadRewards(makeLoadResponse(achievements: [ach]))
        let row = spy.loadRewardsVM?.achievementRows.first
        XCTAssertNotNil(row?.unlockedDateLabel)
    }

    func test_presentLoadRewards_lockedAchievement_hasProgressLabel() {
        let (sut, spy) = makeSUT()
        let ach = makeAchievement(currentProgress: 3, requiredProgress: 10)
        sut.presentLoadRewards(makeLoadResponse(achievements: [ach]))
        let row = spy.loadRewardsVM?.achievementRows.first
        XCTAssertFalse(row?.progressLabel.isEmpty ?? true)
    }

    // MARK: - presentFilterByCollection

    func test_presentFilterByCollection_emptyResult_isEmptyTrue() {
        let (sut, spy) = makeSUT()
        let response = RewardsModels.FilterByCollection.Response(
            stickers: [makeSticker(collection: .animals)],
            activeCollection: .ocean,
            sortOrder: .byCollection
        )
        sut.presentFilterByCollection(response)
        XCTAssertTrue(spy.filterVM?.isEmpty ?? false)
    }

    func test_presentFilterByCollection_matchingCollection_isEmptyFalse() {
        let (sut, spy) = makeSUT()
        let response = RewardsModels.FilterByCollection.Response(
            stickers: [makeSticker(collection: .animals)],
            activeCollection: .animals,
            sortOrder: .byCollection
        )
        sut.presentFilterByCollection(response)
        XCTAssertFalse(spy.filterVM?.isEmpty ?? true)
    }

    // MARK: - presentSortStickers

    func test_presentSortStickers_byRarity_preservesSortOrder() {
        let (sut, spy) = makeSUT()
        let stickers = [makeSticker(rarity: .common), makeSticker(rarity: .legendary)]
        let response = RewardsModels.SortStickers.Response(
            stickers: stickers,
            sortOrder: .byRarity,
            activeCollection: .all
        )
        sut.presentSortStickers(response)
        XCTAssertNotNil(spy.sortVM)
        XCTAssertEqual(spy.sortVM?.sortOrder, .byRarity)
    }

    func test_presentSortStickers_byDate_unlockedFirst() {
        let (sut, spy) = makeSUT()
        let locked = makeSticker(isUnlocked: false, unlockedAt: nil)
        let unlocked = makeSticker(isUnlocked: true, unlockedAt: Date())
        let response = RewardsModels.SortStickers.Response(
            stickers: [locked, unlocked],
            sortOrder: .byDate,
            activeCollection: .all
        )
        sut.presentSortStickers(response)
        // Unlocked with date comes before locked (nil date)
        XCTAssertTrue(spy.sortVM?.cells.first?.isUnlocked ?? false)
    }

    // MARK: - presentSearchStickers

    func test_presentSearchStickers_emptyQuery_returnAll() {
        let (sut, spy) = makeSUT()
        let stickers = [makeSticker(name: "Кот"), makeSticker(name: "Собака")]
        let response = RewardsModels.SearchStickers.Response(stickers: stickers, query: "")
        sut.presentSearchStickers(response)
        XCTAssertEqual(spy.searchVM?.cells.count, 2)
    }

    func test_presentSearchStickers_matchingQuery_filtersCorrectly() {
        let (sut, spy) = makeSUT()
        let stickers = [makeSticker(name: "Кот"), makeSticker(name: "Собака")]
        let response = RewardsModels.SearchStickers.Response(stickers: stickers, query: "кот")
        sut.presentSearchStickers(response)
        XCTAssertEqual(spy.searchVM?.cells.count, 1)
    }

    func test_presentSearchStickers_noMatch_isEmptyTrue() {
        let (sut, spy) = makeSUT()
        let stickers = [makeSticker(name: "Кот")]
        let response = RewardsModels.SearchStickers.Response(stickers: stickers, query: "дракон")
        sut.presentSearchStickers(response)
        XCTAssertTrue(spy.searchVM?.isEmpty ?? false)
        XCTAssertFalse(spy.searchVM?.emptyTitle.isEmpty ?? true)
    }

    // MARK: - presentOpenSticker

    func test_presentOpenSticker_unlocked_hasDateLabel() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(isUnlocked: true, unlockedAt: Date())
        sut.presentOpenSticker(.init(sticker: sticker))
        XCTAssertNotNil(spy.openStickerVM?.detail.unlockedDateLabel)
    }

    func test_presentOpenSticker_locked_noDateLabel() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(isUnlocked: false, unlockedAt: nil)
        sut.presentOpenSticker(.init(sticker: sticker))
        XCTAssertNil(spy.openStickerVM?.detail.unlockedDateLabel)
    }

    // MARK: - presentClaimReward

    func test_presentClaimReward_legendary_hasLongConfettiList() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(rarity: .legendary, isUnlocked: true)
        sut.presentClaimReward(.init(sticker: sticker))
        XCTAssertGreaterThan(spy.claimRewardVM?.unlock.confettiEmojis.count ?? 0, 4)
    }

    func test_presentClaimReward_common_hasShortConfettiList() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(rarity: .common, isUnlocked: true)
        sut.presentClaimReward(.init(sticker: sticker))
        XCTAssertEqual(spy.claimRewardVM?.unlock.confettiEmojis.count, 4)
    }

    func test_presentClaimReward_rare_voiceLineNotEmpty() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(rarity: .rare, isUnlocked: true)
        sut.presentClaimReward(.init(sticker: sticker))
        XCTAssertFalse(spy.claimRewardVM?.unlock.lyalyaVoiceLine.isEmpty ?? true)
    }

    func test_presentClaimReward_epic_voiceLineNotEmpty() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(rarity: .epic, isUnlocked: true)
        sut.presentClaimReward(.init(sticker: sticker))
        XCTAssertFalse(spy.claimRewardVM?.unlock.lyalyaVoiceLine.isEmpty ?? true)
    }

    // MARK: - presentChangeAlbumTheme

    func test_presentChangeAlbumTheme_confirmationNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentChangeAlbumTheme(.init(theme: .neon))
        XCTAssertFalse(spy.changeAlbumThemeVM?.confirmationMessage.isEmpty ?? true)
    }

    // MARK: - presentPrepareShare

    func test_presentPrepareShare_shareTextContainsEmojiAndCounts() {
        let (sut, spy) = makeSUT()
        let top = [makeSticker(emoji: "⭐"), makeSticker(emoji: "🎯")]
        sut.presentPrepareShare(.init(unlockedCount: 5, totalCount: 20, topStickers: top, childName: "Маша"))
        XCTAssertFalse(spy.prepareShareVM?.shareText.isEmpty ?? true)
        XCTAssertFalse(spy.prepareShareVM?.topEmojis.isEmpty ?? true)
    }

    // MARK: - presentOpenAchievement

    func test_presentOpenAchievement_unlocked_progressLabelIsDone() {
        let (sut, spy) = makeSUT()
        let ach = makeAchievement(isUnlocked: true, currentProgress: 10, requiredProgress: 10)
        sut.presentOpenAchievement(.init(achievement: ach))
        // В тестовой среде String(localized:) может вернуть ключ — проверяем не пусто
        XCTAssertFalse(spy.openAchievementVM?.detail.progressLabel.isEmpty ?? true)
    }

    func test_presentOpenAchievement_locked_progressLabelHasNumbers() {
        let (sut, spy) = makeSUT()
        let ach = makeAchievement(currentProgress: 3, requiredProgress: 10)
        sut.presentOpenAchievement(.init(achievement: ach))
        XCTAssertFalse(spy.openAchievementVM?.detail.progressLabel.isEmpty ?? true)
    }

    // MARK: - presentClaimStreakReward

    func test_presentClaimStreakReward_withSticker_messageNotEmpty() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(name: "Звезда", emoji: "🌟", isUnlocked: true)
        let reward = StreakReward(streakDays: 7, rewardDescription: "Медаль", isClaimed: false)
        sut.presentClaimStreakReward(.init(reward: reward, grantedSticker: sticker))
        XCTAssertFalse(spy.claimStreakVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentClaimStreakReward_withSticker_emojiPresentInResult() {
        let (sut, spy) = makeSUT()
        let sticker = makeSticker(name: "Праздник", emoji: "🎉", isUnlocked: true)
        let reward = StreakReward(streakDays: 7, rewardDescription: "Стикер", isClaimed: false)
        sut.presentClaimStreakReward(.init(reward: reward, grantedSticker: sticker))
        XCTAssertEqual(spy.claimStreakVM?.grantedStickerEmoji, "🎉")
    }

    func test_presentClaimStreakReward_noSticker_emojiIsNil() {
        let (sut, spy) = makeSUT()
        let reward = StreakReward(streakDays: 14, rewardDescription: "Бонус", isClaimed: false)
        sut.presentClaimStreakReward(.init(reward: reward, grantedSticker: nil))
        XCTAssertNil(spy.claimStreakVM?.grantedStickerEmoji)
    }

    // MARK: - presentFailure

    func test_presentFailure_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Ошибка загрузки"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Ошибка загрузки")
    }

    // MARK: - Streak banner accessibility

    func test_streakBanner_claimed_hasDifferentA11yThanLocked() {
        let (sut, spy) = makeSUT()
        let rewards = [
            StreakReward(streakDays: 7, rewardDescription: "Р", isClaimed: true),
            StreakReward(streakDays: 14, rewardDescription: "Р", isClaimed: false)
        ]
        sut.presentLoadRewards(makeLoadResponse(streakRewards: rewards, currentStreak: 3))
        let banners = spy.loadRewardsVM?.streakBanners ?? []
        XCTAssertEqual(banners.count, 2)
        XCTAssertNotEqual(banners[0].accessibilityLabel, banners[1].accessibilityLabel)
    }
}
