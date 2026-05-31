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

    override func setUp() async throws {
        try await super.setUp()
        spyDisplay = SpyLogopedistChatDisplay()
        sut = LogopedistChatPresenter(displayLogic: spyDisplay)
    }

    override func tearDown() async throws {
        sut = nil
        spyDisplay = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_presentLoad_onlineSpecialist_setsOnlineTrue() async {
        // Arrange
        let specialist = SpecialistInfo(
            displayName: "Ирина Петрова",
            credentialsKey: "chat.specialist.unknown.credentials",
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

    func test_presentLoad_noSpecialist_setsEmptyStateHint_andNoPresence() async {
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: [],
            isConnected: false
        )
        await sut.presentLoad(response: response)
        // Честное пустое состояние вместо фейковой переписки.
        XCTAssertNotNil(spyDisplay.lastLoadViewModel?.emptyStateHint,
                        "Без специалиста должна показываться честная подсказка")
        // Никакого индикатора присутствия выдуманного логопеда.
        XCTAssertNil(spyDisplay.lastLoadViewModel?.onlineStatusLabel,
                     "Без специалиста presence-подпись не показывается")
        XCTAssertFalse(spyDisplay.lastLoadViewModel?.isOnline ?? true)
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

    // MARK: - Block R.2 v32: connect / grouping / unread / outbox / connect form

    func test_presentLoad_notConnected_showsConnectForm() async {
        let response = LogopedistChatModels.Load.Response(
            specialist: nil, messages: [], isConnected: false
        )
        await sut.presentLoad(response: response)
        XCTAssertTrue(spyDisplay.lastLoadViewModel?.showConnectForm ?? false,
                      "Без подключённого логопеда показываем форму ввода кода")
    }

    func test_presentLoad_connected_hidesConnectForm() async {
        let specialist = SpecialistInfo(
            displayName: "Ирина", credentialsKey: "specialist.credentials.logopedist",
            isOnline: true, lastSeenAt: nil
        )
        let response = LogopedistChatModels.Load.Response(
            specialist: specialist, messages: [], isConnected: true
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spyDisplay.lastLoadViewModel?.showConnectForm ?? true)
    }

    func test_presentLoad_groupsMessagesByDay() async {
        let cal = Calendar.current
        let today = Date()
        // swiftlint:disable:next force_unwrapping
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        let messages = [
            ChatMessage(id: "m1", sender: .parent, text: "Старое", createdAt: twoDaysAgo, status: .sent),
            ChatMessage(id: "m2", sender: .specialist, text: "Сегодня 1", createdAt: today, status: .delivered),
            ChatMessage(id: "m3", sender: .parent, text: "Сегодня 2", createdAt: today, status: .sent)
        ]
        let response = LogopedistChatModels.Load.Response(
            specialist: nil, messages: messages, isConnected: true
        )
        await sut.presentLoad(response: response)
        let sections = spyDisplay.lastLoadViewModel?.sections ?? []
        XCTAssertEqual(sections.count, 2, "Сообщения двух разных дней → 2 секции")
        XCTAssertEqual(sections.last?.dateLabel, "Сегодня")
        XCTAssertEqual(sections.last?.messages.count, 2, "В сегодняшней секции — 2 сообщения")
    }

    func test_presentLoad_unreadBadge_reflectsCount() async {
        let response = LogopedistChatModels.Load.Response(
            specialist: nil, messages: [], isConnected: true,
            unreadCount: 3, pendingOutboxCount: 0
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spyDisplay.lastLoadViewModel?.unreadBadge, "3")
    }

    func test_presentLoad_noUnread_noBadge() async {
        let response = LogopedistChatModels.Load.Response(
            specialist: nil, messages: [], isConnected: true,
            unreadCount: 0, pendingOutboxCount: 0
        )
        await sut.presentLoad(response: response)
        XCTAssertNil(spyDisplay.lastLoadViewModel?.unreadBadge)
    }

    func test_presentLoad_pendingOutbox_setsLabel() async {
        let response = LogopedistChatModels.Load.Response(
            specialist: nil, messages: [], isConnected: true,
            unreadCount: 0, pendingOutboxCount: 2
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spyDisplay.lastLoadViewModel?.outboxLabel,
                        "При непустой offline-очереди показываем индикатор")
    }

    func test_presentConnect_success_setsConnectedAndSuccessMessage() async {
        let specialist = SpecialistInfo(
            displayName: "Ирина", credentialsKey: "k", isOnline: true, lastSeenAt: nil
        )
        await sut.presentConnect(response: .init(resultState: .connected(specialist)))
        XCTAssertTrue(spyDisplay.lastConnectViewModel?.isConnected ?? false)
        XCTAssertNotNil(spyDisplay.lastConnectViewModel?.successMessage)
        XCTAssertNil(spyDisplay.lastConnectViewModel?.errorMessage)
    }

    func test_presentConnect_failure_setsErrorMessage() async {
        await sut.presentConnect(response: .init(resultState: .failed(.codeNotFound)))
        XCTAssertFalse(spyDisplay.lastConnectViewModel?.isConnected ?? true)
        XCTAssertNotNil(spyDisplay.lastConnectViewModel?.errorMessage)
        XCTAssertNil(spyDisplay.lastConnectViewModel?.successMessage)
    }
}

// MARK: - SpyLogopedistChatDisplay

@MainActor
private final class SpyLogopedistChatDisplay: LogopedistChatDisplayLogic {

    var displayLoadCalled = false
    var displaySendCalled = false
    var displayAttachAudioCalled = false
    var displayConnectCalled = false

    var lastLoadViewModel: LogopedistChatModels.Load.ViewModel?
    var lastConnectViewModel: LogopedistChatModels.Connect.ViewModel?

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

    func displayConnect(viewModel: LogopedistChatModels.Connect.ViewModel) async {
        displayConnectCalled = true
        lastConnectViewModel = viewModel
    }
}
