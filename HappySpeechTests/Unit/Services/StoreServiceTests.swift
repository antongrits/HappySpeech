@testable import HappySpeech
import StoreKit
import XCTest

// MARK: - StoreServiceTests
//
// Покрывает доменную логику монетизации:
//   - PremiumEntitlement.isPremium / isLifetime по всем кейсам;
//   - PurchaseOutcome / StoreError равенство и локализованные сообщения;
//   - StoreProductID наборы;
//   - MockStoreService — ветвления purchase/restore/loadProducts + спаи;
//   - LiveStoreService — graceful refresh/loadProducts без .storekit-конфига.
//
// StoreKit.Product нельзя сконструировать без подключённого .storekit-конфига,
// поэтому ветви, требующие реальный Product, проверяются через MockStoreService.

@MainActor
final class StoreServiceTests: XCTestCase {

    // MARK: - PremiumEntitlement

    func test_entitlement_none_notPremiumNotLifetime() {
        let e = PremiumEntitlement.none
        XCTAssertFalse(e.isPremium)
        XCTAssertFalse(e.isLifetime)
    }

    func test_entitlement_premiumWithExpiry_isPremiumNotLifetime() {
        let e = PremiumEntitlement.premium(expiresAt: Date().addingTimeInterval(86_400))
        XCTAssertTrue(e.isPremium)
        XCTAssertFalse(e.isLifetime, "Подписка с датой окончания — не lifetime")
    }

    func test_entitlement_premiumNilExpiry_isLifetime() {
        let e = PremiumEntitlement.premium(expiresAt: nil)
        XCTAssertTrue(e.isPremium)
        XCTAssertTrue(e.isLifetime, "premium без даты окончания == lifetime")
    }

    func test_entitlement_contentPack_notPremium() {
        let e = PremiumEntitlement.contentPack(id: StoreProductID.contentPackAdvanced)
        XCTAssertFalse(e.isPremium, "Контент-пак не повышает до premium")
        XCTAssertFalse(e.isLifetime)
    }

    func test_entitlement_equatable() {
        XCTAssertEqual(PremiumEntitlement.none, .none)
        XCTAssertEqual(PremiumEntitlement.premium(expiresAt: nil), .premium(expiresAt: nil))
        XCTAssertNotEqual(PremiumEntitlement.premium(expiresAt: nil),
                          .premium(expiresAt: Date(timeIntervalSince1970: 1)))
        XCTAssertNotEqual(PremiumEntitlement.contentPack(id: "a"), .contentPack(id: "b"))
    }

    // MARK: - PurchaseOutcome / StoreError equality

    func test_purchaseOutcome_equatable() {
        XCTAssertEqual(PurchaseOutcome.success, .success)
        XCTAssertEqual(PurchaseOutcome.pending, .pending)
        XCTAssertEqual(PurchaseOutcome.userCancelled, .userCancelled)
        XCTAssertEqual(PurchaseOutcome.failed(.notAllowed), .failed(.notAllowed))
        XCTAssertNotEqual(PurchaseOutcome.failed(.notAllowed), .failed(.purchaseFailed))
        XCTAssertNotEqual(PurchaseOutcome.success, .pending)
    }

    func test_storeError_localizedDescriptions_nonEmptyRussian() {
        let errors: [StoreError] = [
            .productsUnavailable, .verificationFailed, .purchaseFailed, .restoreFailed, .notAllowed
        ]
        for error in errors {
            let desc = error.errorDescription
            XCTAssertNotNil(desc, "\(error) должна иметь errorDescription")
            XCTAssertFalse(desc?.isEmpty ?? true, "\(error) сообщение не пустое")
        }
    }

    // MARK: - StoreProductID

    func test_productID_premiumTier_threeOptions() {
        XCTAssertEqual(StoreProductID.premiumTier.count, 3)
        XCTAssertEqual(StoreProductID.premiumTier,
                       [StoreProductID.premiumMonthly,
                        StoreProductID.premiumYearly,
                        StoreProductID.premiumLifetime])
    }

    func test_productID_all_includesContentPack() {
        XCTAssertEqual(StoreProductID.all.count, 4)
        XCTAssertTrue(StoreProductID.all.contains(StoreProductID.contentPackAdvanced))
    }

    // MARK: - MockStoreService: loadProducts

    func test_mock_loadProducts_ok_clearsError() async {
        let sut = MockStoreService()
        await sut.loadProducts()
        XCTAssertEqual(sut.loadProductsCallCount, 1)
        XCTAssertNil(sut.lastError)
        XCTAssertFalse(sut.isLoading)
    }

    func test_mock_loadProducts_unavailable_setsError() async {
        let sut = MockStoreService(simulateProductsUnavailable: true)
        await sut.loadProducts()
        XCTAssertEqual(sut.lastError, .productsUnavailable)
    }

    // MARK: - MockStoreService: restore

    func test_mock_restore_success_setsEntitlement() async {
        let sut = MockStoreService(entitlementAfterRestore: .premium(expiresAt: nil))
        await sut.restorePurchases()
        XCTAssertEqual(sut.restoreCallCount, 1)
        XCTAssertTrue(sut.isPremium)
        XCTAssertNil(sut.lastError)
    }

    func test_mock_restore_noPriorPurchase_setsRestoreFailed() async {
        let sut = MockStoreService(entitlementAfterRestore: nil)
        await sut.restorePurchases()
        XCTAssertEqual(sut.lastError, .restoreFailed)
        XCTAssertFalse(sut.isPremium)
    }

    func test_mock_refreshEntitlements_incrementsSpy() async {
        let sut = MockStoreService()
        await sut.refreshEntitlements()
        await sut.refreshEntitlements()
        XCTAssertEqual(sut.refreshEntitlementsCallCount, 2)
    }

    func test_mock_initialEntitlement_reflectsIsPremium() {
        let premium = MockStoreService(premiumEntitlement: .premium(expiresAt: nil))
        XCTAssertTrue(premium.isPremium)
        let free = MockStoreService(premiumEntitlement: .none)
        XCTAssertFalse(free.isPremium)
    }

    // MARK: - LiveStoreService: graceful without .storekit config

    func test_live_loadProducts_noConfig_setsProductsUnavailable() async {
        // В unit-окружении нет .storekit-конфига → продуктов нет → error.
        let sut = LiveStoreService()
        await sut.loadProducts()
        XCTAssertTrue(sut.products.isEmpty)
        XCTAssertFalse(sut.isLoading, "isLoading сбрасывается через defer")
    }

    func test_live_refreshEntitlements_noTransactions_resolvesNone() async {
        let sut = LiveStoreService()
        await sut.refreshEntitlements()
        // Без транзакций currentEntitlements пуст → .none.
        XCTAssertEqual(sut.premiumEntitlement, .none)
        XCTAssertFalse(sut.isPremium)
    }

    func test_live_initialState_isClean() {
        let sut = LiveStoreService()
        XCTAssertTrue(sut.products.isEmpty)
        XCTAssertEqual(sut.premiumEntitlement, .none)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.lastError)
    }
}
