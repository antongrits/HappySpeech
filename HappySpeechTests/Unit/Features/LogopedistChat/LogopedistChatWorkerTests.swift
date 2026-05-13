import XCTest
@testable import HappySpeech

// MARK: - LogopedistChatWorkerTests
//
// Block AA v21 — Smoke tests для модели LogopedistChat (Worker-уровень).
// LogopedistChat не имеет отдельного Worker — персистенция in-memory + UserDefaults seed.
// Тесты верифицируют доменные модели ChatMessage и MessageAttachment.

final class LogopedistChatWorkerTests: XCTestCase {

    // MARK: - Tests

    func test_chatMessage_parentSender_isFromParent() {
        let message = ChatMessage(
            id: "test-1",
            sender: .parent,
            text: "Привет",
            createdAt: Date(),
            status: .sent
        )
        XCTAssertEqual(message.sender, .parent)
        XCTAssertFalse(message.isOptional)
    }

    func test_messageAttachment_audioRecording_hasCorrectSymbol() {
        let attachment = MessageAttachment(
            id: "att-1",
            kind: .audioRecording,
            titleKey: "chat.attachment.audio.title",
            durationSeconds: 3.5
        )
        XCTAssertEqual(attachment.symbolName, "waveform")
    }

    func test_messageStatus_sentState_equatable() {
        let status1 = MessageStatus.sent
        let status2 = MessageStatus.sent
        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, MessageStatus.read)
    }
}
