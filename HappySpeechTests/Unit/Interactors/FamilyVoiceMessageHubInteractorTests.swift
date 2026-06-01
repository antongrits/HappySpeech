@testable import HappySpeech
import XCTest

// MARK: - FamilyVoiceMessageHubInteractorTests
//
// Thin VIP (@Observable). Стартовое состояние — пустое (без выдуманных
// сообщений). Тесты проверяют честный empty-state + markRead / markAllRead /
// unreadCount над реально заданными сообщениями.

@MainActor
final class FamilyVoiceMessageHubInteractorTests: XCTestCase {

    private func makeSUT() -> FamilyVoiceMessageHubInteractor {
        FamilyVoiceMessageHubInteractor()
    }

    /// Загружает тестовые сообщения в state SUT (имитирует доставку из репозитория).
    private func seed(_ sut: FamilyVoiceMessageHubInteractor) {
        sut.state.messages = [
            .init(id: "m1", sender: .mom, durationSeconds: 12, timeLabel: "—", preview: "a", isUnread: true),
            .init(id: "m2", sender: .dad, durationSeconds: 8, timeLabel: "—", preview: "b", isUnread: true),
            .init(id: "m3", sender: .grandma, durationSeconds: 22, timeLabel: "—", preview: "c", isUnread: false)
        ]
    }

    // MARK: - Initial state

    func test_initialState_isEmpty() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.messages.isEmpty)
        XCTAssertTrue(sut.state.isEmpty)
        XCTAssertEqual(sut.state.unreadCount, 0)
    }

    // MARK: - markRead

    func test_markRead_clearsUnreadOnTarget() {
        let sut = makeSUT()
        seed(sut)
        sut.markRead("m1")
        let m1 = sut.state.messages.first { $0.id == "m1" }
        XCTAssertEqual(m1?.isUnread, false)
    }

    func test_markRead_decrementsUnreadCount() {
        let sut = makeSUT()
        seed(sut)
        let before = sut.state.unreadCount
        sut.markRead("m1")
        XCTAssertEqual(sut.state.unreadCount, before - 1)
    }

    func test_markRead_unknownId_isNoOp() {
        let sut = makeSUT()
        seed(sut)
        let before = sut.state.unreadCount
        sut.markRead("does-not-exist")
        XCTAssertEqual(sut.state.unreadCount, before)
    }

    func test_markRead_alreadyRead_keepsCount() {
        let sut = makeSUT()
        seed(sut)
        let before = sut.state.unreadCount
        sut.markRead("m3")
        XCTAssertEqual(sut.state.unreadCount, before)
    }

    // MARK: - markAllRead

    func test_markAllRead_zeroesUnreadCount() {
        let sut = makeSUT()
        seed(sut)
        sut.markAllRead()
        XCTAssertEqual(sut.state.unreadCount, 0)
    }

    func test_markAllRead_allMessagesRead() {
        let sut = makeSUT()
        seed(sut)
        sut.markAllRead()
        XCTAssertTrue(sut.state.messages.allSatisfy { !$0.isUnread })
    }

    // MARK: - SenderRole model

    func test_senderRole_titleAndEmoji_nonEmpty() {
        for role in [FamilyVoiceMessageHubModels.SenderRole.mom,
                     .dad, .kid, .grandma] {
            XCTAssertFalse(role.title.isEmpty)
            XCTAssertFalse(role.emoji.isEmpty)
        }
    }
}
