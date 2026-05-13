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

    // MARK: - Тесты из v18 (уникальное покрытие)

    func test_presentLoad_withSpecialist_setsSpecialistName() async {
        let specialist = SpecialistInfo(
            displayName: "Иванова Мария",
            credentialsKey: "specialist.credentials.logopedist",
            isOnline: true,
            lastSeenAt: nil
        )
        let response = LogopedistChatModels.Load.Response(
            specialist: specialist,
            messages: [],
            isConnected: true
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spyDisplay.lastLoadViewModel?.specialistName, "Иванова Мария")
        XCTAssertTrue(spyDisplay.lastLoadViewModel?.isOnline ?? false)
    }

    func test_presentLoad_offline_setsConnectionHint() async {
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: [],
            isConnected: false
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spyDisplay.lastLoadViewModel?.connectionHint,
                        "Оффлайн-состояние должно устанавливать connectionHint")
    }

    func test_presentLoad_withMessages_mapsAllRows() async {
        let messages = [
            ChatMessage(id: UUID().uuidString, sender: .parent,  text: "Добрый день", createdAt: Date(), status: .sent),
            ChatMessage(id: UUID().uuidString, sender: .specialist, text: "Здравствуйте!", createdAt: Date(), status: .delivered)
        ]
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: messages,
            isConnected: true
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spyDisplay.lastLoadViewModel?.messages.count, 2,
                       "Presenter должен отображать все сообщения")
    }

    func test_presentLoad_parentMessage_isFromParentTrue() async {
        let messages = [
            ChatMessage(id: "m1", sender: .parent, text: "Привет", createdAt: Date(), status: .sent)
        ]
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: messages,
            isConnected: true
        )
        await sut.presentLoad(response: response)
        XCTAssertTrue(spyDisplay.lastLoadViewModel?.messages.first?.isFromParent ?? false,
                      "Сообщение от parent должно иметь isFromParent=true")
    }

    func test_presentAttachAudio_callsDisplayAttachAudio() async {
        let message = ChatMessage(
            id: "audio-msg",
            sender: .parent,
            text: "",
            createdAt: Date(),
            status: .sending
        )
        let response = LogopedistChatModels.AttachAudio.Response(createdMessage: message)
        await sut.presentAttachAudio(response: response)
        XCTAssertTrue(spyDisplay.displayAttachAudioCalled)
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
