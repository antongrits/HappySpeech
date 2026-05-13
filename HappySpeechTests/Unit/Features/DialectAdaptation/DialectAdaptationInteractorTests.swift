import XCTest
@testable import HappySpeech

// MARK: - DialectAdaptationInteractorTests
//
// Block AA v21 — Smoke tests для DialectAdaptationInteractor.
// 3 теста: load (happy path), select (valid dialectId), reset (default restored).

@MainActor
final class DialectAdaptationInteractorTests: XCTestCase {

    private var sut: DialectAdaptationInteractor!
    private var spyPresenter: SpyDialectAdaptationPresenter!
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() {
        super.setUp()
        testSuiteName = "test.dialect.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        spyPresenter = SpyDialectAdaptationPresenter()
        sut = DialectAdaptationInteractor(
            childId: "child-test-1",
            hapticService: MockHapticService(),
            userDefaults: testDefaults
        )
        sut.presenter = spyPresenter
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        sut = nil
        spyPresenter = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_load_callsPresenterWithAllDialects() async {
        // Act
        await sut.load(request: DialectAdaptationModels.Load.Request(childId: "child-test-1"))
        // Assert
        XCTAssertTrue(spyPresenter.presentLoadCalled, "presentLoad должен быть вызван")
        XCTAssertEqual(
            spyPresenter.lastLoadResponse?.availableDialects.count,
            RegionalDialect.all.count,
            "Должны вернуться все диалекты"
        )
    }

    func test_select_validDialectId_callsPresenter() async {
        // Arrange
        let dialectId = "moscow"
        // Act
        await sut.select(request: DialectAdaptationModels.Select.Request(
            childId: "child-test-1",
            dialectId: dialectId,
            now: Date()
        ))
        // Assert
        XCTAssertTrue(spyPresenter.presentSelectCalled, "presentSelect должен быть вызван")
        XCTAssertEqual(spyPresenter.lastSelectResponse?.appliedDialect.id, dialectId)
        XCTAssertTrue(spyPresenter.lastSelectResponse?.success == true)
    }

    func test_reset_restoresDefaultDialect() async {
        // Act
        await sut.reset(request: DialectAdaptationModels.Reset.Request(childId: "child-test-1"))
        // Assert
        XCTAssertTrue(spyPresenter.presentResetCalled, "presentReset должен быть вызван")
        XCTAssertEqual(
            spyPresenter.lastResetResponse?.restored.id,
            RegionalDialect.default.id,
            "После reset диалект должен стать дефолтным (central)"
        )
    }
}

// MARK: - SpyDialectAdaptationPresenter

@MainActor
private final class SpyDialectAdaptationPresenter: DialectAdaptationPresentationLogic, @unchecked Sendable {

    var presentLoadCalled = false
    var presentSelectCalled = false
    var presentResetCalled = false

    var lastLoadResponse: DialectAdaptationModels.Load.Response?
    var lastSelectResponse: DialectAdaptationModels.Select.Response?
    var lastResetResponse: DialectAdaptationModels.Reset.Response?

    func presentLoad(response: DialectAdaptationModels.Load.Response) async {
        presentLoadCalled = true
        lastLoadResponse = response
    }

    func presentSelect(response: DialectAdaptationModels.Select.Response) async {
        presentSelectCalled = true
        lastSelectResponse = response
    }

    func presentReset(response: DialectAdaptationModels.Reset.Response) async {
        presentResetCalled = true
        lastResetResponse = response
    }
}
