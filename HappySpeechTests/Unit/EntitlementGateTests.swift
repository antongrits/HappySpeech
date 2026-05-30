@testable import HappySpeech
import XCTest

// MARK: - EntitlementGateTests
//
// Покрытие EntitlementGate.canAccess / requiresUpgrade для всех PremiumFeature
// при каждом состоянии PremiumEntitlement (none / premium / contentPack).

final class EntitlementGateTests: XCTestCase {

    // MARK: - none → всё закрыто

    func test_none_locksAllFeatures() {
        let gate = EntitlementGate(entitlement: .none)
        for feature in PremiumFeature.allCases {
            XCTAssertFalse(gate.canAccess(feature), "\(feature) should be locked for .none")
            XCTAssertTrue(gate.requiresUpgrade(for: feature), "\(feature) should require upgrade for .none")
        }
    }

    // MARK: - premium (subscription) → всё открыто

    func test_premiumSubscription_unlocksAllFeatures() {
        let gate = EntitlementGate(entitlement: .premium(expiresAt: Date().addingTimeInterval(86_400)))
        for feature in PremiumFeature.allCases {
            XCTAssertTrue(gate.canAccess(feature), "\(feature) should be unlocked for premium subscription")
            XCTAssertFalse(gate.requiresUpgrade(for: feature))
        }
    }

    // MARK: - premium (lifetime) → всё открыто

    func test_premiumLifetime_unlocksAllFeatures() {
        let gate = EntitlementGate(entitlement: .premium(expiresAt: nil))
        for feature in PremiumFeature.allCases {
            XCTAssertTrue(gate.canAccess(feature), "\(feature) should be unlocked for lifetime")
        }
    }

    // MARK: - contentPack(advanced) → только advancedContentPack

    func test_advancedContentPack_unlocksOnlyContentPackFeature() {
        let gate = EntitlementGate(entitlement: .contentPack(id: StoreProductID.contentPackAdvanced))

        XCTAssertTrue(gate.canAccess(.advancedContentPack),
                      "advancedContentPack must be accessible via its own purchase")

        let othersLocked: [PremiumFeature] = [
            .extendedAnalytics, .pdfExport, .multipleChildren, .weeklyLLMInsights, .specialistTools
        ]
        for feature in othersLocked {
            XCTAssertFalse(gate.canAccess(feature), "\(feature) must stay locked with only content pack")
            XCTAssertTrue(gate.requiresUpgrade(for: feature))
        }
    }

    // MARK: - contentPack with unknown id → advancedContentPack locked

    func test_unknownContentPackId_doesNotUnlockAdvancedPack() {
        let gate = EntitlementGate(entitlement: .contentPack(id: "ru.happyspeech.contentpack.unknown"))
        XCTAssertFalse(gate.canAccess(.advancedContentPack),
                       "Different content pack id must not unlock advancedContentPack")
    }

    // MARK: - PremiumEntitlement helpers

    func test_entitlement_isPremiumFlag() {
        XCTAssertFalse(PremiumEntitlement.none.isPremium)
        XCTAssertFalse(PremiumEntitlement.contentPack(id: "x").isPremium)
        XCTAssertTrue(PremiumEntitlement.premium(expiresAt: nil).isPremium)
        XCTAssertTrue(PremiumEntitlement.premium(expiresAt: Date()).isPremium)
    }

    func test_entitlement_isLifetimeFlag() {
        XCTAssertTrue(PremiumEntitlement.premium(expiresAt: nil).isLifetime)
        XCTAssertFalse(PremiumEntitlement.premium(expiresAt: Date()).isLifetime)
        XCTAssertFalse(PremiumEntitlement.none.isLifetime)
        XCTAssertFalse(PremiumEntitlement.contentPack(id: "x").isLifetime)
    }

    // MARK: - Feature metadata is non-empty (used in paywall UI)

    func test_everyFeature_hasTitleSubtitleIcon() {
        for feature in PremiumFeature.allCases {
            XCTAssertFalse(feature.title.isEmpty)
            XCTAssertFalse(feature.subtitle.isEmpty)
            XCTAssertFalse(feature.iconName.isEmpty)
        }
    }
}
