import XCTest
@testable import HappySpeech

// MARK: - LogopedistChatInteractorTests
//
// Block AA v21 — Smoke tests для LogopedistChatInteractor.
// v28 Фаза 2 — этический рефактор: чат больше не имитирует живого логопеда.
// Пока реальный специалист не подключён, `load` отдаёт пустое состояние
// (specialist == nil, нет сообщений), а `send` молча игнорируется.

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

    func test_load_noConnectedSpecialist_returnsEmptyHonestState() async {
        // Act
        await sut.load(request: LogopedistChatModels.Load.Request(
            parentId: "parent-test-1",
            specialistId: "specialist-test-1"
        ))
        // Assert: пока реальный логопед не подключён — никакого фейкового
        // собеседника и никакой выдуманной переписки.
        XCTAssertTrue(spyPresenter.presentLoadCalled)
        XCTAssertNil(spyPresenter.lastLoadResponse?.specialist,
                     "Без реального специалиста собеседник не выдумывается")
        XCTAssertTrue(
            spyPresenter.lastLoadResponse?.messages.isEmpty ?? false,
            "Фейковых seed-сообщений быть не должно"
        )
        XCTAssertEqual(spyPresenter.lastLoadResponse?.isConnected, false)
    }

    func test_send_withoutConnectedSpecialist_isIgnored() async {
        // Arrange
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
        // Assert: без подключённого специалиста отправлять некому.
        XCTAssertFalse(spyPresenter.presentSendCalled,
                       "Без подключённого специалиста send не должен вызывать presenter")
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

    // MARK: - Batch 2.8.3 v25 / v28 Фаза 2: расширенное покрытие

    func test_load_noFakePresence() async {
        await sut.load(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1"
        ))
        // Никакого индикатора присутствия выдуманного логопеда.
        XCTAssertNil(spyPresenter.lastLoadResponse?.specialist?.isOnline)
        XCTAssertEqual(spyPresenter.lastLoadResponse?.isConnected, false)
    }

    func test_load_noSeedMessages() async {
        await sut.load(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1"
        ))
        XCTAssertTrue((spyPresenter.lastLoadResponse?.messages ?? []).isEmpty,
                      "Тред пуст, пока реальный специалист не ответит")
    }

    func test_send_emptyText_isIgnoredEvenWithoutSpecialist() async {
        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "   ", now: Date()
        ))
        XCTAssertNil(spyPresenter.lastSendResponse?.createdMessage)
    }

    func test_send_noAutoReply() async {
        // Отправка не порождает авто-ответа «специалиста».
        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "Вопрос?", now: Date()
        ))
        XCTAssertNil(spyPresenter.lastSendResponse,
                     "Авто-ответ логопеда не имитируется")
    }

    func test_attachAudio_createsMessageWithAttachment() async {
        await sut.attachAudio(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            attachmentTitle: "Запись занятия", durationSeconds: 12.5, now: Date()
        ))
        XCTAssertTrue(spyPresenter.presentAttachAudioCalled)
        let message = spyPresenter.lastAttachResponse?.createdMessage
        XCTAssertNotNil(message?.attachment)
        XCTAssertEqual(message?.attachment?.kind, .audioRecording)
        XCTAssertEqual(message?.attachment?.durationSeconds, 12.5)
        XCTAssertEqual(message?.sender, .parent)
    }

    func test_markAsRead_unknownIds_doesNotCrash() async {
        await sut.markAsRead(request: .init(
            parentId: "parent-test-1", messageIds: ["ghost-1", "ghost-2"]
        ))
        XCTAssertTrue(true)
    }

    func test_markAsRead_emptyThread_doesNotCrash() async {
        await sut.load(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1"
        ))
        await sut.markAsRead(request: .init(
            parentId: "parent-test-1", messageIds: []
        ))
        XCTAssertTrue(true)
    }

    func test_dataStore_idsSet() {
        XCTAssertEqual(sut.parentId, "parent-test-1")
        XCTAssertEqual(sut.specialistId, "specialist-test-1")
    }

    func test_chatMessage_construction() {
        let msg = ChatMessage(
            id: "m1", sender: .parent, text: "Тест",
            createdAt: Date(), status: .delivered
        )
        XCTAssertEqual(msg.sender, .parent)
        XCTAssertEqual(msg.status, .delivered)
        XCTAssertNil(msg.attachment)
        XCTAssertFalse(msg.isOptional)
    }

    func test_messageAttachment_symbolByKind() {
        let audio = MessageAttachment(id: "a", kind: .audioRecording,
                                      titleKey: "k", durationSeconds: 5)
        XCTAssertEqual(audio.symbolName, "waveform")
        let report = MessageAttachment(id: "b", kind: .progressReport,
                                       titleKey: "k", durationSeconds: nil)
        XCTAssertEqual(report.symbolName, "chart.line.uptrend.xyaxis")
    }
}

// MARK: - SpyLogopedistChatPresenter

@MainActor
private final class SpyLogopedistChatPresenter: LogopedistChatPresentationLogic, @unchecked Sendable {

    var presentLoadCalled = false
    var presentSendCalled = false
    var presentAttachAudioCalled = false

    var lastLoadResponse: LogopedistChatModels.Load.Response?
    var lastSendResponse: LogopedistChatModels.Send.Response?
    var lastAttachResponse: LogopedistChatModels.AttachAudio.Response?

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
}
