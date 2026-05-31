import XCTest
@testable import HappySpeech

// MARK: - LogopedistChatWorkerTests
//
// Block R.2 v32 — тесты репозиторного слоя чата (`MockChatRepository`) и
// доменных моделей. Repository — единственный «Worker» фичи (изолирует
// Firestore/Sync). Покрытие: connect, offline-очередь + flush, unread/markRead,
// real-time stream, детерминированный chatId.

final class LogopedistChatWorkerTests: XCTestCase {

    private func identity() -> ChatIdentity {
        ChatIdentity(familyId: "family-1", specialistId: "spec-1")
    }

    // MARK: - Domain models

    func test_chatMessage_parentSender_isFromParent() {
        let message = ChatMessage(
            id: "test-1", sender: .parent, text: "Привет",
            createdAt: Date(), status: .sent
        )
        XCTAssertEqual(message.sender, .parent)
        XCTAssertFalse(message.isOptional)
    }

    func test_messageAttachment_audioRecording_hasCorrectSymbol() {
        let attachment = MessageAttachment(
            id: "att-1", kind: .audioRecording,
            titleKey: "chat.attachment.audio.title", durationSeconds: 3.5
        )
        XCTAssertEqual(attachment.symbolName, "waveform")
    }

    func test_messageStatus_sentState_equatable() {
        XCTAssertEqual(MessageStatus.sent, MessageStatus.sent)
        XCTAssertNotEqual(MessageStatus.sent, MessageStatus.read)
    }

    func test_chatIdentity_chatId_orderIndependent() {
        let a = ChatIdentity(familyId: "aaa", specialistId: "zzz")
        let b = ChatIdentity(familyId: "zzz", specialistId: "aaa")
        XCTAssertEqual(a.chatId, b.chatId)
        XCTAssertTrue(a.chatId.contains("aaa") && a.chatId.contains("zzz"))
    }

    // MARK: - Connect

    func test_connect_validCode_returnsConnected() async {
        let repo = MockChatRepository(validCode: "K7M2X9")
        let state = await repo.connectSpecialist(familyId: "family-1", code: "k7m2x9")
        if case .connected = state {} else { XCTFail("Ожидалось .connected") }
    }

    func test_connect_wrongCode_returnsNotFound() async {
        let repo = MockChatRepository(validCode: "K7M2X9")
        let state = await repo.connectSpecialist(familyId: "family-1", code: "ABCDEF")
        XCTAssertEqual(state, .failed(.codeNotFound))
    }

    func test_connect_shortCode_returnsInvalidCode() async {
        let repo = MockChatRepository(validCode: "K7M2X9")
        let state = await repo.connectSpecialist(familyId: "family-1", code: "K7M")
        XCTAssertEqual(state, .failed(.invalidCode))
    }

    func test_linkState_defaultNotConnected() async {
        let repo = MockChatRepository()
        let state = await repo.linkState(identity: identity())
        XCTAssertEqual(state, .notConnected)
    }

    // MARK: - Send online / offline queue

    func test_sendText_online_marksSent() async {
        let repo = MockChatRepository(isOnline: true)
        let msg = await repo.sendText(identity: identity(), text: "Привет", now: Date())
        XCTAssertEqual(msg.status, .sent)
        let history = await repo.loadHistory(identity: identity())
        XCTAssertEqual(history.count, 1)
    }

    func test_sendText_offline_queuesAsSending() async {
        let repo = MockChatRepository(isOnline: false)
        let msg = await repo.sendText(identity: identity(), text: "Оффлайн", now: Date())
        XCTAssertEqual(msg.status, .sending)
        let pending = await repo.pendingOutboxCount(identity: identity())
        XCTAssertEqual(pending, 1, "Оффлайн-сообщение в очереди")
    }

    func test_offlineQueue_flushOnReconnect_marksSent() async {
        let repo = MockChatRepository(isOnline: false)
        _ = await repo.sendText(identity: identity(), text: "1", now: Date())
        _ = await repo.sendText(identity: identity(), text: "2", now: Date().addingTimeInterval(1))
        var pending = await repo.pendingOutboxCount(identity: identity())
        XCTAssertEqual(pending, 2)

        await repo.goOnlineAndFlush(identity: identity())

        pending = await repo.pendingOutboxCount(identity: identity())
        XCTAssertEqual(pending, 0, "После реконнекта очередь пуста")
        let history = await repo.loadHistory(identity: identity())
        XCTAssertTrue(history.allSatisfy { $0.status == .sent },
                      "Все доставленные сообщения помечены .sent")
    }

    // MARK: - Unread / markAsRead

    func test_unreadCount_countsIncomingUnread() async {
        let now = Date()
        let repo = MockChatRepository(seededMessages: [
            identity(): [
                ChatMessage(id: "in-1", sender: .specialist, text: "a", createdAt: now, status: .delivered),
                ChatMessage(id: "in-2", sender: .specialist, text: "b", createdAt: now, status: .read),
                ChatMessage(id: "out-1", sender: .parent, text: "c", createdAt: now, status: .sent)
            ]
        ])
        let unread = await repo.unreadCount(identity: identity())
        XCTAssertEqual(unread, 1, "Только delivered входящие считаются непрочитанными")
    }

    func test_markAsRead_marksIncomingRead_ignoresOutgoing() async {
        let now = Date()
        let repo = MockChatRepository(seededMessages: [
            identity(): [
                ChatMessage(id: "in-1", sender: .specialist, text: "a", createdAt: now, status: .delivered),
                ChatMessage(id: "out-1", sender: .parent, text: "c", createdAt: now, status: .sent)
            ]
        ])
        let updated = await repo.markAsRead(identity: identity(), messageIds: ["in-1", "out-1"])
        XCTAssertEqual(updated, ["in-1"], "Исходящие нельзя пометить прочитанными")
        let unread = await repo.unreadCount(identity: identity())
        XCTAssertEqual(unread, 0)
    }

    // MARK: - Real-time stream

    func test_messageStream_yieldsInitialThenUpdate() async {
        let repo = MockChatRepository(autoConnectAll: false)
        // Seed a connected thread.
        _ = await repo.connectSpecialist(familyId: "family-1", code: "ABCD23")
        _ = await repo.sendText(identity: identity(), text: "первое", now: Date())

        let stream = repo.messageStream(identity: identity())
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        XCTAssertEqual(first?.count, 1, "Стрим сразу отдаёт текущий снапшот")

        // Имитируем входящее сообщение от логопеда.
        await repo.receiveSpecialistMessage(identity: identity(), text: "ответ")
        let second = await iterator.next()
        XCTAssertEqual(second?.count, 2, "Новое сообщение приходит через стрим")
        XCTAssertEqual(second?.last?.sender, .specialist)
    }

    // MARK: - previewSeeded

    func test_previewSeeded_isConnectedForAnyIdentity() async {
        let repo = MockChatRepository.previewSeeded()
        let state = await repo.linkState(identity: identity())
        if case .connected = state {} else { XCTFail("previewSeeded должен быть подключён") }
        let history = await repo.loadHistory(identity: identity())
        XCTAssertFalse(history.isEmpty, "previewSeeded содержит демонстрационную переписку")
    }
}
