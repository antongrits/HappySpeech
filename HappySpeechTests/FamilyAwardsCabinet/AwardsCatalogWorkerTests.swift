@testable import HappySpeech
import XCTest

// MARK: - AwardsCatalogWorkerTests
//
// Покрывает: fetchUnlocked(parentId:) — группировка наград по AwardTier.

@MainActor
final class AwardsCatalogWorkerTests: XCTestCase {

    // MARK: - Пустой репозиторий

    func test_fetchUnlocked_whenNoChildren_returnsEmptyBuckets() async {
        let repo = SpyChildRepository(children: [])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")

        XCTAssertFalse(buckets.isEmpty, "Buckets должны содержать все тиры (даже пустые)")
        let allAwards = buckets.flatMap { $0.awards }
        XCTAssertTrue(allAwards.isEmpty, "Для детей без прогресса наград быть не должно")
    }

    // MARK: - Дети с прогрессом разблокируют награды

    func test_fetchUnlocked_childWith1SessionMinute_unlocksBronzeAward() async {
        let child = TestDataBuilder.childProfile(
            id: "child-001",
            parentId: "parent-001",
            totalSessionMinutes: 1
        )
        let repo = SpyChildRepository(children: [child])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")
        let bronzeBucket = buckets.first { $0.tier == AwardTier.bronze }

        XCTAssertNotNil(bronzeBucket, "Должен существовать bronze bucket")
        XCTAssertFalse(bronzeBucket?.awards.isEmpty ?? true,
                       "Дитя с 1+ минутой должно иметь bronze award")
    }

    func test_fetchUnlocked_childWithStreak7_includesSilverAward() async {
        let child = TestDataBuilder.childProfile(
            id: "child-001",
            parentId: "parent-001",
            currentStreak: 7
        )
        let repo = SpyChildRepository(children: [child])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")
        let silverBucket = buckets.first { $0.tier == AwardTier.silver }
        let allAwards = buckets.flatMap { $0.awards }

        XCTAssertNotNil(silverBucket, "Silver bucket должен существовать")
        XCTAssertFalse(allAwards.isEmpty, "Дитя с streak=7 должно иметь награды")
    }

    func test_fetchUnlocked_childWithStreak30_includesGoldAndPlatinum() async {
        let child = TestDataBuilder.childProfile(
            id: "child-001",
            parentId: "parent-001",
            totalSessionMinutes: 600,
            currentStreak: 30
        )
        let repo = SpyChildRepository(children: [child])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")
        let goldBucket = buckets.first { $0.tier == AwardTier.gold }
        let platinumBucket = buckets.first { $0.tier == AwardTier.platinum }

        XCTAssertFalse(goldBucket?.awards.isEmpty ?? true,
                       "Streak=30 должен давать gold award")
        XCTAssertFalse(platinumBucket?.awards.isEmpty ?? true,
                       "Streak=30 + 600 минут должны давать platinum award")
    }

    // MARK: - Фильтрация по parentId

    func test_fetchUnlocked_filtersChildrenByParentId() async {
        let childForParent = TestDataBuilder.childProfile(
            id: "child-001",
            parentId: "parent-001",
            totalSessionMinutes: 1,
            currentStreak: 0
        )
        let childForOtherParent = TestDataBuilder.childProfile(
            id: "child-002",
            parentId: "parent-002",
            totalSessionMinutes: 0
        )
        let repo = SpyChildRepository(children: [childForParent, childForOtherParent])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")
        let allAwards = buckets.flatMap { $0.awards }

        let awardChildIds = Set(allAwards.map { $0.childId })
        XCTAssertFalse(awardChildIds.contains("child-002"),
                       "Награды другого родителя не должны включаться")
    }

    // MARK: - Структура buckets

    func test_fetchUnlocked_returnsAllFourTiers() async {
        let repo = SpyChildRepository(children: [])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")

        let tiers = Set(buckets.map { $0.tier })
        XCTAssertTrue(tiers.contains(.platinum), "Должен быть platinum bucket")
        XCTAssertTrue(tiers.contains(.gold), "Должен быть gold bucket")
        XCTAssertTrue(tiers.contains(.silver), "Должен быть silver bucket")
        XCTAssertTrue(tiers.contains(.bronze), "Должен быть bronze bucket")
    }

    func test_fetchUnlocked_bucketsOrderedByRankDesc() async {
        let repo = SpyChildRepository(children: [])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")

        let ranks = buckets.map { $0.tier.rank }
        let sortedRanks = ranks.sorted(by: >)
        XCTAssertEqual(ranks, sortedRanks, "Buckets должны быть отсортированы по rank desc")
    }

    // MARK: - Ошибка репозитория

    func test_fetchUnlocked_whenRepositoryFails_returnsEmptyBuckets() async {
        let repo = SpyChildRepository(children: [])
        repo.shouldFail = true
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")
        let allAwards = buckets.flatMap { $0.awards }

        XCTAssertTrue(allAwards.isEmpty,
                      "При ошибке репозитория нет наград")
    }

    // MARK: - Несколько детей

    func test_fetchUnlocked_multipleChildren_aggregatesAwards() async {
        let child1 = TestDataBuilder.childProfile(
            id: "child-001",
            parentId: "parent-001",
            totalSessionMinutes: 1
        )
        let child2 = TestDataBuilder.childProfile(
            id: "child-002",
            parentId: "parent-001",
            totalSessionMinutes: 1
        )
        let repo = SpyChildRepository(children: [child1, child2])
        let sut = AwardsCatalogWorker(childRepository: repo)

        let buckets = await sut.fetchUnlocked(parentId: "parent-001")
        let allAwards = buckets.flatMap { $0.awards }

        let childIds = Set(allAwards.map { $0.childId })
        XCTAssertTrue(childIds.contains("child-001"))
        XCTAssertTrue(childIds.contains("child-002"))
    }
}
