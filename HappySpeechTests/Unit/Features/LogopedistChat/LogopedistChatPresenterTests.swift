import XCTest
@testable import HappySpeech

// MARK: - LogopedistChatPresenterTests
//
// Block AA v21 — Smoke tests для LogopedistChatPresenter.
// 3 теста: presentLoad (specialist online), presentLoad (no specialist), presentSend (success).

@MainActor
final class LogopedistChatPresenterTests: XCTestCase {

    private var sut: LogopedistChatPresenter!
    private var spyDisplay: SpyLogopedistChatDisplay!

    override func setUp() {
        super.setUp()
        spyDisplay = SpyLogopedistChatDisplay()
        sut = LogopedistChatPresenter(displayLogic: spyDisplay)
    }

    override func tearDown() {
        sut = nil
        spyDisplay = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_presentLoad_onlineSpecialist_setsOnlineTrue() async {
        // Arrange
        let specialist = SpecialistInfo(
            displayName: "Ирина Петрова",
            credentialsKey: "chat.specialist.seed.credentials",
            isOnline: true,
            lastSeenAt: nil
        )
        let response = LogopedistChatModels.Load.Response(
            specialist: specialist,
            messages: [],
            isConnected: true
        )
        // Act
        await sut.presentLoad(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displayLoadCalled)
        XCTAssertTrue(spyDisplay.lastLoadViewModel?.isOnline == true)
        XCTAssertTrue(spyDisplay.lastLoadViewModel?.composerEnabled == true)
    }

    func test_presentLoad_noSpecialist_disablesComposer() async {
        // Arrange
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: [],
            isConnected: false
        )
        // Act
        await sut.presentLoad(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displayLoadCalled)
        XCTAssertFalse(
            spyDisplay.lastLoadViewModel?.composerEnabled ?? true,
            "Без специалиста composer должен быть отключён"
        )
    }

    func test_presentSend_callsDisplay() async {
        // Arrange
        let message = ChatMessage(
            id: "msg-1",
            sender: .parent,
            text: "Тест",
            createdAt: Date(),
            status: .sent
        )
        let response = LogopedistChatModels.Send.Response(
            createdMessage: message,
            appendedMessages: [message]
        )
        // Act
        await sut.presentSend(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displaySendCalled)
    }
}

// MARK: - SpyLogopedistChatDisplay

@MainActor
private final class SpyLogopedistChatDisplay: LogopedistChatDisplayLogic {

    var displayLoadCalled = false
    var displaySendCalled = false
    var displayAttachAudioCalled = false

    var lastLoadViewModel: LogopedistChatModels.Load.ViewModel?

    func displayLoad(viewModel: LogopedistChatModels.Load.ViewModel) async {
        displayLoadCalled = true
        lastLoadViewModel = viewModel
    }

    func displaySend(viewModel: LogopedistChatModels.Send.ViewModel) async {
        displaySendCalled = true
    }

    func displayAttachAudio(viewModel: LogopedistChatModels.AttachAudio.ViewModel) async {
        displayAttachAudioCalled = true
    }
}
