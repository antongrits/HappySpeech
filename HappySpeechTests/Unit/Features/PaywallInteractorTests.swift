@testable import HappySpeech
import XCTest

// MARK: - PaywallInteractorTests
//
// Покрытие PaywallInteractor через MockStoreService (без реального StoreKit).
// Реальные StoreKit.Product создать нельзя без подключённого .storekit-конфига,
// поэтому проверяем оркестрацию: загрузка офферингов, ветка «продукт не найден»
// при покупке, восстановление. Маппинг Product→VM проверяется в Presenter-тестах.

@MainActor
final class PaywallInteractorTests: XCTestCase {

    // MARK: - PresenterSpy

    private final class PresenterSpy: PaywallPresentationLogic {
        var loadResponse: PaywallModels.LoadOfferings.Response?
        var purchaseResponse: PaywallModels.Purchase.Response?
        var restoreResponse: PaywallModels.Restore.Response?

        func presentLoadOfferings(_ response: PaywallModels.LoadOfferings.Response) {
            loadResponse = response
        }
        func presentPurchase(_ response: PaywallModels.Purchase.Response) {
            purchaseResponse = response
        }
        func presentRestore(_ response: PaywallModels.Restore.Response) {
            restoreResponse = response
        }
    }

    private func makeSUT(
        store: MockStoreService
    ) -> (PaywallInteractor, PresenterSpy) {
        let spy = PresenterSpy()
        let interactor = PaywallInteractor(storeService: store)
        interactor.presenter = spy
        return (interactor, spy)
    }

    // MARK: - loadOfferings

    func test_loadOfferings_callsStoreAndPresentsResponse() async throws {
        let store = MockStoreService(premiumEntitlement: .none)
        let (sut, spy) = makeSUT(store: store)

        sut.loadOfferings(.init())
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(store.loadProductsCallCount, 1)
        let response = try XCTUnwrap(spy.loadResponse)
        // Mock не отдаёт реальные продукты — productsUnavailable истинно.
        XCTAssertTrue(response.productsUnavailable)
        XCTAssertEqual(response.entitlement, .none)
    }

    func test_loadOfferings_reflectsPremiumEntitlement() async throws {
        let store = MockStoreService(premiumEntitlement: .premium(expiresAt: nil))
        let (sut, spy) = makeSUT(store: store)

        sut.loadOfferings(.init())
        try await Task.sleep(for: .milliseconds(50))

        let response = try XCTUnwrap(spy.loadResponse)
        XCTAssertTrue(response.entitlement.isPremium)
    }

    // MARK: - purchase (product not found branch)

    func test_purchase_withUnknownProduct_presentsFailure() async throws {
        let store = MockStoreService(premiumEntitlement: .none)
        let (sut, spy) = makeSUT(store: store)

        sut.purchase(.init(productID: "ru.happyspeech.premium.monthly"))
        try await Task.sleep(for: .milliseconds(50))

        let response = try XCTUnwrap(spy.purchaseResponse)
        // Продукт не найден в пустом mock-каталоге → .failed(.purchaseFailed).
        if case .failed(let error) = response.outcome {
            XCTAssertEqual(error, .purchaseFailed)
        } else {
            XCTFail("Expected .failed outcome, got \(response.outcome)")
        }
        // Реальная покупка не вызывалась — продукта не было.
        XCTAssertEqual(store.purchaseCallCount, 0)
    }

    // MARK: - restore

    func test_restore_success_presentsRestoredPremium() async throws {
        let store = MockStoreService(
            premiumEntitlement: .none,
            entitlementAfterRestore: .premium(expiresAt: nil)
        )
        let (sut, spy) = makeSUT(store: store)

        sut.restore(.init())
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(store.restoreCallCount, 1)
        let response = try XCTUnwrap(spy.restoreResponse)
        XCTAssertTrue(response.didRestorePremium)
        XCTAssertTrue(response.entitlement.isPremium)
        XCTAssertNil(response.error)
    }

    func test_restore_failure_presentsError() async throws {
        let store = MockStoreService(
            premiumEntitlement: .none,
            entitlementAfterRestore: nil // → restoreFailed
        )
        let (sut, spy) = makeSUT(store: store)

        sut.restore(.init())
        try await Task.sleep(for: .milliseconds(50))

        let response = try XCTUnwrap(spy.restoreResponse)
        XCTAssertFalse(response.didRestorePremium)
        XCTAssertEqual(response.error, .restoreFailed)
    }
}
