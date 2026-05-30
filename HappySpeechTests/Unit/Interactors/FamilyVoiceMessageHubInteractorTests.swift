@testable import HappySpeech
import XCTest

// MARK: - FamilyVoiceMessageHubInteractorTests
//
// Thin VIP (@Observable). Tests markRead / markAllRead and the unreadCount
// computed property, including the no-op for an unknown id.

@MainActor
final class FamilyVoiceMessageHubInteractorTests: XCTestCase {

    private func makeSUT() -> FamilyVoiceMessageHubInteractor {
        FamilyVoiceMessageHubInteractor()
    }

    // MARK: - Initial state

    func test_initialState_hasSeedMessages() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.messages.isEmpty)
    }

    func test_initialState_unreadCountMatchesSeed() {
        let sut = makeSUT()
        // Seed has m1 + m2 unread → 2.
        XCTAssertEqual(sut.state.unreadCount, 2)
    }

    // MARK: - markRead

    func test_markRead_clearsUnreadOnTarget() {
        let sut = makeSUT()
        sut.markRead("m1")
        let m1 = sut.state.messages.first { $0.id == "m1" }
        XCTAssertEqual(m1?.isUnread, false)
    }

    func test_markRead_decrementsUnreadCount() {
        let sut = makeSUT()
        let before = sut.state.unreadCount
        sut.markRead("m1")
        XCTAssertEqual(sut.state.unreadCount, before - 1)
    }

    func test_markRead_unknownId_isNoOp() {
        let sut = makeSUT()
        let before = sut.state.unreadCount
        sut.markRead("does-not-exist")
        XCTAssertEqual(sut.state.unreadCount, before)
    }

    func test_markRead_alreadyRead_keepsCount() {
        let sut = makeSUT()
        // m3 already read in seed.
        let before = sut.state.unreadCount
        sut.markRead("m3")
        XCTAssertEqual(sut.state.unreadCount, before)
    }

    // MARK: - markAllRead

    func test_markAllRead_zeroesUnreadCount() {
        let sut = makeSUT()
        sut.markAllRead()
        XCTAssertEqual(sut.state.unreadCount, 0)
    }

    func test_markAllRead_allMessagesRead() {
        let sut = makeSUT()
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
