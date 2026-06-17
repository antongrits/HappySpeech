@testable import HappySpeech
import Foundation
import RealmSwift
import XCTest

// MARK: - RealmActorWipeTests
//
// Покрывает полную локальную очистку `RealmActor.deleteAllData()` — строительный
// блок каскадного удаления аккаунта (COPPA / GDPR right-to-erasure): после
// облачного каскада нельзя оставлять осиротевшие данные ребёнка на устройстве.

final class RealmActorWipeTests: XCTestCase {

    private func inMemoryConfig(_ identifier: String) -> Realm.Configuration {
        var config = Realm.Configuration()
        config.inMemoryIdentifier = identifier
        return config
    }

    func test_deleteAllData_wipesAllObjects() async throws {
        let config = inMemoryConfig("wipe-\(UUID().uuidString)")
        let actor = RealmActor()
        try await actor.open(configuration: config)

        // Заполняем разными типами объектов.
        try await actor.writeVoid { realm in
            let reward = RewardRecord()
            reward.childId = "child-1"
            reward.type = "sticker"
            realm.add(reward)

            let profile = ChildProfile()
            profile.name = "Тест"
            realm.add(profile)
        }

        let rewardsBefore = try await actor.fetchAllMapped(RewardRecord.self) { $0.id }
        let profilesBefore = try await actor.fetchAllMapped(ChildProfile.self) { $0.id }
        XCTAssertFalse(rewardsBefore.isEmpty, "Перед очисткой должны быть награды")
        XCTAssertFalse(profilesBefore.isEmpty, "Перед очисткой должны быть профили")

        // Полная очистка.
        try await actor.deleteAllData()

        let rewardsAfter = try await actor.fetchAllMapped(RewardRecord.self) { $0.id }
        let profilesAfter = try await actor.fetchAllMapped(ChildProfile.self) { $0.id }
        XCTAssertTrue(rewardsAfter.isEmpty, "После deleteAllData награды должны быть стёрты")
        XCTAssertTrue(profilesAfter.isEmpty, "После deleteAllData профили должны быть стёрты")
    }

    func test_deleteAllData_onEmptyRealm_doesNotThrow() async throws {
        let config = inMemoryConfig("wipe-empty-\(UUID().uuidString)")
        let actor = RealmActor()
        try await actor.open(configuration: config)
        // Очистка пустой БД — безопасный no-op, не бросает.
        try await actor.deleteAllData()
        let rewards = try await actor.fetchAllMapped(RewardRecord.self) { $0.id }
        XCTAssertTrue(rewards.isEmpty)
    }
}
