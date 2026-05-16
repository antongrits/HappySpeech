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

    // MARK: - Batch 2.8.3 v25: расширенное покрытие

    func test_load_specialistIsOnline() async {
        await sut.load(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1"
        ))
        XCTAssertEqual(spyPresenter.lastLoadResponse?.specialist?.isOnline, true)
        XCTAssertEqual(spyPresenter.lastLoadResponse?.isConnected, true)
    }

    func test_load_seedMessagesFromSpecialist() async {
        await sut.load(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1"
        ))
        let messages = spyPresenter.lastLoadResponse?.messages ?? []
        XCTAssertTrue(messages.allSatisfy { $0.sender == .specialist },
                      "Все seed-сообщения — от специалиста")
        XCTAssertTrue(messages.allSatisfy { $0.isOptional },
                      "Seed-сообщения помечены isOptional")
    }

    func test_send_appendsParentMessage() async {
        await sut.load(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1"
        ))
        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "Здравствуйте", now: Date()
        ))
        XCTAssertEqual(spyPresenter.lastSendResponse?.createdMessage.sender, .parent)
        XCTAssertEqual(spyPresenter.lastSendResponse?.createdMessage.text, "Здравствуйте")
    }

    func test_send_messageStatusIsSent() async {
        await sut.send(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1",
            text: "Вопрос", now: Date()
        ))
        XCTAssertEqual(spyPresenter.lastSendResponse?.createdMessage.status, .sent)
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

    func test_markAsRead_existingSeedIds() async {
        await sut.load(request: .init(
            parentId: "parent-test-1", specialistId: "specialist-test-1"
        ))
        await sut.markAsRead(request: .init(
            parentId: "parent-test-1", messageIds: ["seed.welcome", "seed.intro"]
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
