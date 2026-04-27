@testable import HappySpeech
import XCTest

// MARK: - OfflineStateInteractorTests
//
// M10.1 — 5 тестов для OfflineStateInteractor.
// Покрывает: fetch с детьми, fetch без детей, update connected/disconnected,
// ActiveChildStore сохранение.

@MainActor
final class OfflineStateInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: OfflineStatePresentationLogic {
        var fetchCalled = false
        var updateCalled = false

        var lastFetchResponse: OfflineStateModels.Fetch.Response?
        var lastUpdateResponse: OfflineStateModels.Update.Response?

        func presentFetch(_ response: OfflineStateModels.Fetch.Response) {
            fetchCalled = true
            lastFetchResponse = response
        }
        func presentUpdate(_ response: OfflineStateModels.Update.Response) {
            updateCalled = true
            lastUpdateResponse = response
        }
    }

    private func makeSUT(
        children: [ChildProfileDTO] = [.preview],
        isConnected: Bool = true,
        preferredChildId: String? = nil
    ) -> (OfflineStateInteractor, SpyPresenter) {
        let mockChild = MockChildRepository(children: children)
        let mockSync = MockSyncService()
        let mockNetwork = MockNetworkMonitor()
        mockNetwork.isConnected = isConnected
        let sut = OfflineStateInteractor(
            childRepository: mockChild,
            syncService: mockSync,
            networkMonitor: mockNetwork,
            preferredChildIdProvider: { preferredChildId }
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. fetch с детьми → activeChildId не nil

    func test_fetch_withChildren_activeChildIdNotNil() async {
        let (sut, spy) = makeSUT(children: [.preview])
        await sut.fetch(.init())
        XCTAssertTrue(spy.fetchCalled)
        XCTAssertNotNil(spy.lastFetchResponse?.activeChildId)
    }

    // MARK: - 2. fetch без детей → activeChildId = nil

    func test_fetch_withNoChildren_activeChildIdIsNil() async {
        let (sut, spy) = makeSUT(children: [])
        await sut.fetch(.init())
        XCTAssertTrue(spy.fetchCalled)
        XCTAssertNil(spy.lastFetchResponse?.activeChildId)
    }

    // MARK: - 3. update → isConnected = true передаётся в presenter

    func test_update_connectedTrue_propagated() async {
        let (sut, spy) = makeSUT(isConnected: true)
        await sut.update(.init(kind: .retryConnection))
        XCTAssertTrue(spy.updateCalled)
        XCTAssertTrue(spy.lastUpdateResponse?.isConnected ?? false)
    }

    // MARK: - 4. update → isConnected = false передаётся в presenter

    func test_update_connectedFalse_propagated() async {
        let (sut, spy) = makeSUT(isConnected: false)
        await sut.update(.init(kind: .continueOffline))
        XCTAssertTrue(spy.updateCalled)
        XCTAssertFalse(spy.lastUpdateResponse?.isConnected ?? true)
    }

    // MARK: - 5. ActiveChildStore сохраняет и читает ID

    func test_activeChildStore_setAndGet_roundtrip() {
        let store = ActiveChildStore(
            defaults: UserDefaults(suiteName: "test-offline-\(UUID().uuidString)")!
        )
        store.set("child-roundtrip-42")
        // Небольшая задержка для barrier-async завершения — используем sync очередь.
        XCTAssertEqual(store.id, "child-roundtrip-42")
    }
}
