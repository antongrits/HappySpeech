@testable import HappySpeech
import XCTest

// MARK: - PaywallPresenterTests
//
// Покрытие PaywallPresenter: формирование ViewModel из Response.
// StoreKit.Product создать без .storekit-конфига нельзя, поэтому маппинг
// Product→PlanVM проверяется опосредованно: с пустым списком продуктов
// (plans пуст), а ветвления тостов/статуса — детерминированно по entitlement
// и PurchaseOutcome.

@MainActor
final class PaywallPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    private final class DisplaySpy: PaywallDisplayLogic {
        var loadVM: PaywallModels.LoadOfferings.ViewModel?
        var purchaseVM: PaywallModels.Purchase.ViewModel?
        var restoreVM: PaywallModels.Restore.ViewModel?

        func displayLoadOfferings(_ viewModel: PaywallModels.LoadOfferings.ViewModel) { loadVM = viewModel }
        func displayPurchase(_ viewModel: PaywallModels.Purchase.ViewModel) { purchaseVM = viewModel }
        func displayRestore(_ viewModel: PaywallModels.Restore.ViewModel) { restoreVM = viewModel }
    }

    private func makeSUT() -> (PaywallPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = PaywallPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    // MARK: - presentLoadOfferings

    func test_loadOfferings_buildsAllFeatures() {
        let (sut, spy) = makeSUT()
        sut.presentLoadOfferings(.init(products: [], entitlement: .none, productsUnavailable: true))

        let vm = spy.loadVM
        XCTAssertNotNil(vm)
        // Все PremiumFeature отображаются в перечне преимуществ.
        XCTAssertEqual(vm?.features.count, PremiumFeature.allCases.count)
        XCTAssertTrue(vm?.plans.isEmpty ?? false, "Empty product list → no plan cards")
        XCTAssertTrue(vm?.productsUnavailable ?? false)
        XCTAssertFalse(vm?.isPremium ?? true)
    }

    func test_loadOfferings_premiumStatusLine() {
        let (sut, spy) = makeSUT()
        sut.presentLoadOfferings(.init(products: [], entitlement: .premium(expiresAt: nil), productsUnavailable: false))
        XCTAssertTrue(spy.loadVM?.isPremium ?? false)
        XCTAssertFalse(spy.loadVM?.statusLine.isEmpty ?? true)
    }

    func test_loadOfferings_freeStatusForContentPack() {
        let (sut, spy) = makeSUT()
        sut.presentLoadOfferings(.init(
            products: [],
            entitlement: .contentPack(id: StoreProductID.contentPackAdvanced),
            productsUnavailable: false
        ))
        // Контент-пак не делает пользователя premium.
        XCTAssertFalse(spy.loadVM?.isPremium ?? true)
    }

    // MARK: - presentPurchase

    func test_purchase_success_dismissesAndShowsToast() {
        let (sut, spy) = makeSUT()
        sut.presentPurchase(.init(outcome: .success, entitlement: .premium(expiresAt: nil)))
        let vm = spy.purchaseVM
        XCTAssertNotNil(vm?.toastMessage)
        XCTAssertFalse(vm?.toastIsError ?? true)
        XCTAssertTrue(vm?.shouldDismiss ?? false)
        XCTAssertTrue(vm?.isPremium ?? false)
    }

    func test_purchase_pending_showsToastNoDismiss() {
        let (sut, spy) = makeSUT()
        sut.presentPurchase(.init(outcome: .pending, entitlement: .none))
        let vm = spy.purchaseVM
        XCTAssertNotNil(vm?.toastMessage, "Ask to Buy must show an explanatory toast")
        XCTAssertFalse(vm?.toastIsError ?? true)
        XCTAssertFalse(vm?.shouldDismiss ?? true)
    }

    func test_purchase_userCancelled_noToastNoDismiss() {
        let (sut, spy) = makeSUT()
        sut.presentPurchase(.init(outcome: .userCancelled, entitlement: .none))
        let vm = spy.purchaseVM
        XCTAssertNil(vm?.toastMessage, "Cancellation must not surface an error toast")
        XCTAssertFalse(vm?.shouldDismiss ?? true)
    }

    func test_purchase_failed_showsErrorToast() {
        let (sut, spy) = makeSUT()
        sut.presentPurchase(.init(outcome: .failed(.verificationFailed), entitlement: .none))
        let vm = spy.purchaseVM
        XCTAssertTrue(vm?.toastIsError ?? false)
        XCTAssertFalse(vm?.shouldDismiss ?? true)
        XCTAssertEqual(vm?.toastMessage, StoreError.verificationFailed.errorDescription)
    }

    // MARK: - presentRestore

    func test_restore_success_dismisses() {
        let (sut, spy) = makeSUT()
        sut.presentRestore(.init(entitlement: .premium(expiresAt: nil), didRestorePremium: true, error: nil))
        let vm = spy.restoreVM
        XCTAssertTrue(vm?.shouldDismiss ?? false)
        XCTAssertTrue(vm?.isPremium ?? false)
        XCTAssertFalse(vm?.toastIsError ?? true)
    }

    func test_restore_nothingFound_infoToast() {
        let (sut, spy) = makeSUT()
        sut.presentRestore(.init(entitlement: .none, didRestorePremium: false, error: nil))
        let vm = spy.restoreVM
        XCTAssertFalse(vm?.shouldDismiss ?? true)
        XCTAssertFalse(vm?.toastIsError ?? true)
    }

    func test_restore_error_showsErrorToast() {
        let (sut, spy) = makeSUT()
        sut.presentRestore(.init(entitlement: .none, didRestorePremium: false, error: .restoreFailed))
        let vm = spy.restoreVM
        XCTAssertTrue(vm?.toastIsError ?? false)
        XCTAssertFalse(vm?.shouldDismiss ?? true)
    }

    // MARK: - Display store mutation

    func test_display_purchaseSuccess_setsShouldDismiss() {
        let display = PaywallDisplay()
        display.displayPurchase(.init(toastMessage: "ok", toastIsError: false, shouldDismiss: true, isPremium: true))
        XCTAssertTrue(display.shouldDismiss)
        XCTAssertEqual(display.toastMessage, "ok")
        XCTAssertTrue(display.isPremium)
    }
}
