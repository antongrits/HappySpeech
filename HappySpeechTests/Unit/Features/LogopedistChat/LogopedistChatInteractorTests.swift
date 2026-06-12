import XCTest
@testable import HappySpeech

// MARK: - LogopedistChatInteractorTests
//
// Block R.2 v32 — реальный чат «родитель ↔ логопед» поверх `ChatRepository`.
//
// Покрытие:
//   • honest-empty: без подключённого логопеда — пустое состояние, send/attach
//     игнорируются (project guide §11);
//   • connect: успех / неверный код / несуществующий код;
//   • send online (.sent) и offline (.sending → outbox);
//   • attachAudio при подключённом специалисте;
//   • markAsRead обновляет входящие;
//   • unread / outbox счётчики прокидываются в Response.

@MainActor
final class LogopedistChatInteractorTests: XCTestCase {

    private var spyPresenter: SpyLogopedistChatPresenter!

    override func setUp() async throws {
        try await super.setUp()
        spyPresenter = SpyLogopedistChatPresenter()
    }

    override func tearDown() async throws {
        spyPresenter = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSUT(repository: any ChatRepository) -> LogopedistChatInteractor {
        let sut = LogopedistChatInteractor(
            parentId: "parent-test-1",
            specialistId: "specialist-test-1",
            repository: repository,
            hapticService: MockHapticService()
        )
        sut.presenter = spyPresenter
        return sut
    }

    private func loadRequest() -> LogopedistChatModels.Load.Request {
        .init(parentId: "parent-test-1", specialistId: "specialist-test-1")
    }

    // MARK: - Honest empty state (no connected specialist)

    func test_load_noConnectedSpecialist_returnsEmptyHonestState() async {
        let sut = makeSUT(repository: MockChatRepository())
        await sut.load(request: loadRequest())

        XCTAssertTrue(spyPresenter.presentLoadCalled)
        XCTAssertNil(spyPresenter.lastLoadResponse?.specialist,
                     "Без реального специалиста собеседник не выдумывается")
        XCTAssertTrue(spyPresenter.lastLoadResponse?.messages.isEmpty ?? false,
                      "Фейковых seed-сообщений быть не должно")
        XCTAssertEqual(spyPresenter.lastLoadResponse?.isConnected, false)
    }

    func test_send_withoutConnectedSpecialist_isIgnored() async {
        let sut = makeSUT(repository: MockChatRepository())
        await sut.load(request: loadRequest())
        spyPresenter.presentSendCalled = false

        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "Привет, вопрос по занятию", now: Date()
        ))
        XCTAssertFalse(spyPresenter.presentSendCalled,
                       "Без подключённого специалиста send не должен вызывать presenter")
    }

    func test_send_emptyText_doesNotCallPresenter() async {
        let sut = makeSUT(repository: connectedRepository())
        await sut.load(request: loadRequest())
        spyPresenter.presentSendCalled = false

        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "   ", now: Date()
        ))
        XCTAssertFalse(spyPresenter.presentSendCalled,
                       "Пустое (whitespace) сообщение не должно вызывать presentSend")
    }

    func test_attachAudio_withoutSpecialist_isIgnored() async {
        let sut = makeSUT(repository: MockChatRepository())
        await sut.load(request: loadRequest())
        await sut.attachAudio(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            attachmentTitle: "Запись", durationSeconds: 5,
            localAudioPath: "/tmp/test.m4a", now: Date()
        ))
        XCTAssertFalse(spyPresenter.presentAttachAudioCalled,
                       "Без подключённого специалиста аудио отправлять некому")
    }

    // MARK: - Connect

    func test_connect_validCode_connectsAndReloads() async {
        let repo = MockChatRepository(validCode: "ABC123")
        let sut = makeSUT(repository: repo)
        await sut.load(request: loadRequest())
        XCTAssertEqual(spyPresenter.lastLoadResponse?.isConnected, false)

        await sut.connect(request: .init(familyId: "parent-test-1", code: "ABC123"))

        XCTAssertTrue(spyPresenter.presentConnectCalled)
        if case .connected = spyPresenter.lastConnectResponse?.resultState {
            // success
        } else {
            XCTFail("Ожидалось .connected при валидном коде")
        }
    }

    func test_connect_wrongLength_returnsInvalidCode() async {
        let sut = makeSUT(repository: MockChatRepository(validCode: "ABC123"))
        await sut.connect(request: .init(familyId: "parent-test-1", code: "AB"))
        XCTAssertEqual(spyPresenter.lastConnectResponse?.resultState, .failed(.invalidCode))
    }

    func test_connect_unknownCode_returnsNotFound() async {
        let sut = makeSUT(repository: MockChatRepository(validCode: "ABC123"))
        await sut.connect(request: .init(familyId: "parent-test-1", code: "ZZZ999"))
        XCTAssertEqual(spyPresenter.lastConnectResponse?.resultState, .failed(.codeNotFound))
    }

    func test_connect_emptyCode_returnsInvalidCode() async {
        let sut = makeSUT(repository: MockChatRepository())
        await sut.connect(request: .init(familyId: "parent-test-1", code: "   "))
        XCTAssertEqual(spyPresenter.lastConnectResponse?.resultState, .failed(.invalidCode))
    }

    // MARK: - Send (connected, online/offline)

    func test_send_connectedOnline_marksSent() async {
        let repo = connectedRepository(isOnline: true)
        let sut = makeSUT(repository: repo)
        await sut.load(request: loadRequest())

        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "Здравствуйте!", now: Date()
        ))
        XCTAssertTrue(spyPresenter.presentSendCalled)
        XCTAssertEqual(spyPresenter.lastSendResponse?.createdMessage.status, .sent)
        XCTAssertEqual(spyPresenter.lastSendResponse?.createdMessage.sender, .parent)
    }

    func test_send_connectedOffline_queuesAsSending() async {
        let repo = connectedRepository(isOnline: false)
        let sut = makeSUT(repository: repo)
        await sut.load(request: loadRequest())

        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "Вопрос в оффлайне", now: Date()
        ))
        XCTAssertEqual(spyPresenter.lastSendResponse?.createdMessage.status, .sending,
                       "Оффлайн-сообщение должно иметь статус .sending (в очереди)")
        // Последующий load показывает pending outbox.
        XCTAssertEqual(spyPresenter.lastLoadResponse?.pendingOutboxCount, 1)
    }

    func test_attachAudio_connected_createsAudioMessage() async {
        let sut = makeSUT(repository: connectedRepository())
        await sut.load(request: loadRequest())
        await sut.attachAudio(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            attachmentTitle: "Запись занятия", durationSeconds: 12.5,
            localAudioPath: "/tmp/lesson.m4a", now: Date()
        ))
        XCTAssertTrue(spyPresenter.presentAttachAudioCalled)
        let message = spyPresenter.lastAttachResponse?.createdMessage
        XCTAssertNotNil(message?.attachment)
        XCTAssertEqual(message?.attachment?.kind, .audioRecording)
        XCTAssertEqual(message?.attachment?.durationSeconds, 12.5)
        XCTAssertEqual(message?.sender, .parent)
    }

    // MARK: - MarkAsRead / unread

    func test_load_connectedWithUnread_reportsUnreadCount() async {
        let now = Date()
        let messages = [
            ChatMessage(id: "in-1", sender: .specialist, text: "Привет", createdAt: now, status: .delivered),
            ChatMessage(id: "in-2", sender: .specialist, text: "Как дела?", createdAt: now, status: .delivered)
        ]
        let identity = ChatIdentity(familyId: "parent-test-1", specialistId: "specialist-test-1")
        let repo = MockChatRepository(seededMessages: [identity: messages])
        let sut = makeSUT(repository: repo)

        await sut.load(request: loadRequest())
        XCTAssertEqual(spyPresenter.lastLoadResponse?.unreadCount, 2)
    }

    func test_markAsRead_updatesIncoming() async {
        let now = Date()
        let messages = [
            ChatMessage(id: "in-1", sender: .specialist, text: "Привет", createdAt: now, status: .delivered)
        ]
        let identity = ChatIdentity(familyId: "parent-test-1", specialistId: "specialist-test-1")
        let repo = MockChatRepository(seededMessages: [identity: messages])
        let sut = makeSUT(repository: repo)
        await sut.load(request: loadRequest())
        XCTAssertEqual(spyPresenter.lastLoadResponse?.unreadCount, 1)

        await sut.markAsRead(request: .init(parentId: "parent-test-1", messageIds: ["in-1"]))
        XCTAssertEqual(spyPresenter.lastLoadResponse?.unreadCount, 0,
                       "После markAsRead непрочитанных не остаётся")
    }

    func test_markAsRead_unknownIds_doesNotCrash() async {
        let sut = makeSUT(repository: connectedRepository())
        await sut.load(request: loadRequest())
        await sut.markAsRead(request: .init(
            parentId: "parent-test-1", messageIds: ["ghost-1", "ghost-2"]
        ))
        XCTAssertTrue(true)
    }

    func test_markAsRead_emptyThread_doesNotCrash() async {
        let sut = makeSUT(repository: MockChatRepository())
        await sut.load(request: loadRequest())
        await sut.markAsRead(request: .init(parentId: "parent-test-1", messageIds: []))
        XCTAssertTrue(true)
    }

    // MARK: - DataStore / domain

    func test_dataStore_idsSet() {
        let sut = makeSUT(repository: MockChatRepository())
        XCTAssertEqual(sut.parentId, "parent-test-1")
        XCTAssertEqual(sut.specialistId, "specialist-test-1")
    }

    func test_chatMessage_construction() {
        let msg = ChatMessage(
            id: "m1", sender: .parent, text: "Тест", createdAt: Date(), status: .delivered
        )
        XCTAssertEqual(msg.sender, .parent)
        XCTAssertEqual(msg.status, .delivered)
        XCTAssertNil(msg.attachment)
        XCTAssertFalse(msg.isOptional)
    }

    func test_messageAttachment_symbolByKind() {
        let audio = MessageAttachment(id: "a", kind: .audioRecording, titleKey: "k", durationSeconds: 5)
        XCTAssertEqual(audio.symbolName, "waveform")
        let report = MessageAttachment(id: "b", kind: .progressReport, titleKey: "k", durationSeconds: nil)
        XCTAssertEqual(report.symbolName, "chart.line.uptrend.xyaxis")
    }

    func test_chatIdentity_deterministicChatId() {
        let a = ChatIdentity(familyId: "parent", specialistId: "spec")
        let b = ChatIdentity(familyId: "spec", specialistId: "parent")
        XCTAssertEqual(a.chatId, b.chatId,
                       "chatId должен быть детерминированным независимо от порядка")
    }

    // MARK: - Seeded repository helper

    private func connectedRepository(isOnline: Bool = true) -> MockChatRepository {
        let identity = ChatIdentity(familyId: "parent-test-1", specialistId: "specialist-test-1")
        let specialist = SpecialistInfo(
            displayName: "Ирина Петрова",
            credentialsKey: "specialist.credentials.logopedist",
            isOnline: true,
            lastSeenAt: nil
        )
        return MockChatRepository(
            connectedSpecialist: specialist,
            isOnline: isOnline,
            seededLinks: [identity: .connected(specialist)]
        )
    }
}

// MARK: - SpyLogopedistChatPresenter

@MainActor
private final class SpyLogopedistChatPresenter: LogopedistChatPresentationLogic, @unchecked Sendable {

    var presentLoadCalled = false
    var presentSendCalled = false
    var presentAttachAudioCalled = false
    var presentConnectCalled = false

    var lastLoadResponse: LogopedistChatModels.Load.Response?
    var lastSendResponse: LogopedistChatModels.Send.Response?
    var lastAttachResponse: LogopedistChatModels.AttachAudio.Response?
    var lastConnectResponse: LogopedistChatModels.Connect.Response?

    func presentLoad(response: LogopedistChatModels.Load.Response) async {
        presentLoadCalled = true
        lastLoadResponse = response
    }

    func presentSend(response: LogopedistChatModels.Send.Response) async {
        presentSendCalled = true
        lastSendResponse = response
    }

    func presentAttachAudio(response: LogopedistChatModels.AttachAudio.Response) async {
        presentAttachAudioCalled = true
        lastAttachResponse = response
    }

    func presentConnect(response: LogopedistChatModels.Connect.Response) async {
        presentConnectCalled = true
        lastConnectResponse = response
    }
}
