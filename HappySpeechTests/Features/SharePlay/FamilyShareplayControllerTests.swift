@testable import HappySpeech
import XCTest

// MARK: - FamilyShareplayControllerTests
//
// FamilyShareplayController зависит от GroupActivities / FaceTime — недоступны
// на симуляторе и в unit-target.
//
// Тестируем:
//   - Начальное состояние: session=nil, isActive=false, participants=[]
//   - endSession: idempotent, state сбрасывается
//   - send без messenger → SharePlayError.messengerUnavailable
//   - incomingMessages без messenger → поток завершается сразу
//   - SyncMessage: Codable round-trip для всех .Kind
//   - SharePlayError: errorDescription не nil

// MARK: - SyncMessage Codable round-trip

final class SyncMessageCodableTests: XCTestCase {

    func test_roundStart_encodeDecode() throws {
        let msg = SyncMessage.roundStart(roundIndex: 2, soundId: "sound_р", senderId: "device-aaa")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        if case .roundStart(let idx, let soundId) = decoded.kind {
            XCTAssertEqual(idx, 2)
            XCTAssertEqual(soundId, "sound_р")
        } else { XCTFail("Ожидался .roundStart") }
    }

    func test_roundComplete_encodeDecode() throws {
        let msg = SyncMessage.roundComplete(roundIndex: 1, score: 0.85, senderId: "dev-bbb")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        if case .roundComplete(let idx, let score) = decoded.kind {
            XCTAssertEqual(idx, 1)
            XCTAssertEqual(score, 0.85, accuracy: 0.001)
        } else { XCTFail("Ожидался .roundComplete") }
    }

    func test_childAnswer_encodeDecode() throws {
        let msg = SyncMessage.childAnswer(
            roundIndex: 0, answer: "коты", isCorrect: true, senderId: "dev-ccc"
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        if case .childAnswer(_, let answer, let isCorrect) = decoded.kind {
            XCTAssertEqual(answer, "коты")
            XCTAssertTrue(isCorrect)
        } else { XCTFail("Ожидался .childAnswer") }
    }

    func test_lyalyaCelebration_encodeDecode() throws {
        let msg = SyncMessage.lyalyaCelebration(intensity: "high", senderId: "dev-ddd")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        if case .lyalyaCelebration(let intensity) = decoded.kind {
            XCTAssertEqual(intensity, "high")
        } else { XCTFail("Ожидался .lyalyaCelebration") }
    }

    func test_sessionComplete_encodeDecode() throws {
        let msg = SyncMessage.sessionComplete(totalScore: 0.75, senderId: "dev-eee")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        if case .sessionComplete(let total) = decoded.kind {
            XCTAssertEqual(total, 0.75, accuracy: 0.001)
        } else { XCTFail("Ожидался .sessionComplete") }
    }

    func test_participantReady_encodeDecode() throws {
        let msg = SyncMessage.participantReady(senderId: "dev-fff")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        if case .participantReady = decoded.kind {} else { XCTFail("Ожидался .participantReady") }
    }

    func test_syncMessage_equatable() {
        // Фабрики (`SyncMessage.roundStart`) проставляют `timestamp` через `Date()`,
        // поэтому два вызова подряд дают разный timestamp и не равны. Equatable
        // учитывает все поля, включая timestamp, — поэтому здесь фиксируем его явно
        // через memberwise-инициализатор, чтобы проверять именно семантику равенства.
        let fixedTimestamp: TimeInterval = 1_700_000_000
        let m1 = SyncMessage(
            kind: .roundStart(roundIndex: 1, soundId: "x"),
            timestamp: fixedTimestamp,
            senderId: "s"
        )
        let m2 = SyncMessage(
            kind: .roundStart(roundIndex: 1, soundId: "x"),
            timestamp: fixedTimestamp,
            senderId: "s"
        )
        let m3 = SyncMessage(
            kind: .roundStart(roundIndex: 2, soundId: "x"),
            timestamp: fixedTimestamp,
            senderId: "s"
        )
        // Разный timestamp → не равны, даже при одинаковом kind/senderId.
        let m4 = SyncMessage(
            kind: .roundStart(roundIndex: 1, soundId: "x"),
            timestamp: fixedTimestamp + 1,
            senderId: "s"
        )
        XCTAssertEqual(m1, m2)
        XCTAssertNotEqual(m1, m3)
        XCTAssertNotEqual(m1, m4)
    }
}

// MARK: - FamilyShareplayController initial state

@MainActor
final class FamilyShareplayControllerTests: XCTestCase {

    private var sut: FamilyShareplayController!

    override func setUp() {
        super.setUp()
        sut = FamilyShareplayController()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_sessionIsNil() {
        XCTAssertNil(sut.session, "Начальное состояние: session=nil")
    }

    func test_initialState_isActiveFalse() {
        XCTAssertFalse(sut.isActive, "Начальное состояние: isActive=false")
    }

    func test_initialState_participantsEmpty() {
        XCTAssertTrue(sut.participants.isEmpty, "Начальное состояние: participants=[]")
    }

    // MARK: - endSession: resets state

    func test_endSession_resetsState() {
        sut.endSession()
        XCTAssertNil(sut.session)
        XCTAssertFalse(sut.isActive)
        XCTAssertTrue(sut.participants.isEmpty)
    }

    func test_endSession_idempotent() {
        sut.endSession()
        XCTAssertNoThrow(sut.endSession())
    }

    // MARK: - send without messenger → error

    func test_send_noMessenger_throwsMessengerUnavailable() async {
        do {
            try await sut.send(.roundStart(roundIndex: 0, soundId: "test"))
            XCTFail("Ожидалась ошибка SharePlayError.messengerUnavailable")
        } catch SharePlayError.messengerUnavailable {
            // Ожидаемый путь
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - incomingMessages: no messenger → stream finishes immediately

    func test_incomingMessages_noMessenger_streamFinishesImmediately() async {
        let stream = sut.incomingMessages()
        var count = 0
        for await _ in stream { count += 1 }
        XCTAssertEqual(count, 0, "Без messenger поток сразу завершается")
    }
}

// MARK: - SharePlayError errorDescription

final class SharePlayErrorTests: XCTestCase {

    func test_notActivated_hasDescription() {
        XCTAssertNotNil(SharePlayError.notActivated.errorDescription)
    }

    func test_messengerUnavailable_hasDescription() {
        XCTAssertNotNil(SharePlayError.messengerUnavailable.errorDescription)
    }

    func test_parentAuthRequired_hasDescription() {
        XCTAssertNotNil(SharePlayError.parentAuthRequired.errorDescription)
    }

    func test_sessionUnavailable_hasDescription() {
        XCTAssertNotNil(SharePlayError.sessionUnavailable.errorDescription)
    }
}
