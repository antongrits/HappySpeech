import XCTest
@testable import HappySpeech

// MARK: - LogopedistChatInteractorTests
//
// Block AA v21 — Smoke tests для LogopedistChatInteractor.
// 3 теста: load (seed данные), send (non-empty text), send (empty text — silent skip).

@MainActor
final class LogopedistChatInteractorTests: XCTestCase {

    private var sut: LogopedistChatInteractor!
    private var spyPresenter: SpyLogopedistChatPresenter!

    override func setUp() {
        super.setUp()
        spyPresenter = SpyLogopedistChatPresenter()
        sut = LogopedistChatInteractor(
            parentId: "parent-test-1",
            specialistId: "specialist-test-1",
            hapticService: MockHapticService(),
            userDefaults: UserDefaults(suiteName: "test.chat.\(UUID().uuidString)")!
        )
        sut.presenter = spyPresenter
    }

    override func tearDown() {
        sut = nil
        spyPresenter = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_load_callsPresenterWithSeedMessages() async {
        // Act
        await sut.load(request: LogopedistChatModels.Load.Request(
            parentId: "parent-test-1",
            specialistId: "specialist-test-1"
        ))
        // Assert
        XCTAssertTrue(spyPresenter.presentLoadCalled)
        XCTAssertNotNil(spyPresenter.lastLoadResponse?.specialist, "Специалист должен быть задан (seed)")
        XCTAssertFalse(
            spyPresenter.lastLoadResponse?.messages.isEmpty ?? true,
            "Seed сообщения должны присутствовать"
        )
    }

    func test_send_nonEmptyText_callsPresenter() async {
        // Arrange: предварительно загружаем (чтобы инициализировать seed)
        await sut.load(request: LogopedistChatModels.Load.Request(
            parentId: "parent-test-1",
            specialistId: "specialist-test-1"
        ))
        spyPresenter.presentSendCalled = false

        // Act
        await sut.send(request: LogopedistChatModels.Send.Request(
            parentId: "parent-test-1",
            specialistId: "specialist-test-1",
            text: "Привет, вопрос по занятию",
            now: Date()
        ))
        // Assert
        XCTAssertTrue(spyPresenter.presentSendCalled, "Непустое сообщение должно вызвать presentSend")
    }

    func test_send_emptyText_doesNotCallPresenter() async {
        // Act
        await sut.send(request: LogopedistChatModels.Send.Request(
            parentId: "parent-test-1",
            specialistId: "specialist-test-1",
            text: "   ",
            now: Date()
        ))
        // Assert
        XCTAssertFalse(
            spyPresenter.presentSendCalled,
            "Пустое (whitespace) сообщение не должно вызывать presentSend"
        )
    }
}

// MARK: - SpyLogopedistChatPresenter

@MainActor
private final class SpyLogopedistChatPresenter: LogopedistChatPresentationLogic, @unchecked Sendable {

    var presentLoadCalled = false
    var presentSendCalled = false
    var presentAttachAudioCalled = false

    var lastLoadResponse: LogopedistChatModels.Load.Response?

    func presentLoad(response: LogopedistChatModels.Load.Response) async {
        presentLoadCalled = true
        lastLoadResponse = response
    }

    func presentSend(response: LogopedistChatModels.Send.Response) async {
        presentSendCalled = true
    }

    func presentAttachAudio(response: LogopedistChatModels.AttachAudio.Response) async {
        presentAttachAudioCalled = true
    }
}
