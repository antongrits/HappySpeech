@testable import HappySpeech
import MultipeerConnectivity
import XCTest

// MARK: - SiblingMPCWorkerTests
//
// MultipeerConnectivity (MCSession, MCNearbyServiceAdvertiser, MCNearbyServiceBrowser)
// требует реальное Bonjour-окружение — в unit-target недоступно.
//
// Тестируем:
//   - init / serviceType константу
//   - start/stop не крашат
//   - connectedDisplayNames до connect = []
//   - peerID(for:) до регистрации → nil
//   - SiblingMessage Codable round-trip
//   - SiblingMPCWorkerDelegate mock (weak reference)

// MARK: - SiblingMessage Codable tests

final class SiblingMessageCodableTests: XCTestCase {

    func test_siblingMessage_readyState_roundTrip() throws {
        let original = SiblingMessage.readyState(isReady: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .readyState(let isReady) = decoded {
            XCTAssertTrue(isReady)
        } else {
            XCTFail("Неверный case после decode")
        }
    }

    func test_siblingMessage_readyState_false_roundTrip() throws {
        let original = SiblingMessage.readyState(isReady: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .readyState(let isReady) = decoded {
            XCTAssertFalse(isReady)
        } else {
            XCTFail("Неверный case после decode")
        }
    }

    func test_siblingMessage_roundStart_roundTrip() throws {
        let original = SiblingMessage.roundStart(word: "рак", roundIndex: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .roundStart(let word, let roundIndex) = decoded {
            XCTAssertEqual(word, "рак")
            XCTAssertEqual(roundIndex, 3)
        } else {
            XCTFail("Ожидался .roundStart")
        }
    }

    func test_siblingMessage_scoreUpdate_roundTrip() throws {
        let original = SiblingMessage.scoreUpdate(score: 0.87, roundIndex: 2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .scoreUpdate(let score, let idx) = decoded {
            XCTAssertEqual(score, 0.87, accuracy: 0.001)
            XCTAssertEqual(idx, 2)
        } else {
            XCTFail("Ожидался .scoreUpdate")
        }
    }

    func test_siblingMessage_roundResult_withWinner_roundTrip() throws {
        let original = SiblingMessage.roundResult(winnerPeerID: "Маша")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .roundResult(let winner) = decoded {
            XCTAssertEqual(winner, "Маша")
        } else {
            XCTFail("Ожидался .roundResult")
        }
    }

    func test_siblingMessage_roundResult_nil_roundTrip() throws {
        let original = SiblingMessage.roundResult(winnerPeerID: nil) // ничья
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .roundResult(let winner) = decoded {
            XCTAssertNil(winner, "nil winnerPeerID должен остаться nil после decode")
        } else {
            XCTFail("Ожидался .roundResult")
        }
    }

    func test_siblingMessage_gameResult_roundTrip() throws {
        let original = SiblingMessage.gameResult(finalScores: ["Маша": 3, "Ваня": 2])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .gameResult(let scores) = decoded {
            XCTAssertEqual(scores["Маша"], 3)
            XCTAssertEqual(scores["Ваня"], 2)
        } else {
            XCTFail("Ожидался .gameResult")
        }
    }

    func test_siblingMessage_disconnect_roundTrip() throws {
        let original = SiblingMessage.disconnect
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SiblingMessage.self, from: data)
        if case .disconnect = decoded {} else {
            XCTFail("Ожидался .disconnect")
        }
    }
}

// MARK: - SiblingMPCWorker lifecycle tests

@MainActor
final class SiblingMPCWorkerLifecycleTests: XCTestCase {

    // MARK: - serviceType constant

    func test_serviceType_isValid() {
        let type = SiblingMPCWorker.serviceType
        XCTAssertFalse(type.isEmpty, "serviceType не должен быть пустым")
        XCTAssertLessThanOrEqual(type.count, 15,
                                 "serviceType ≤ 15 символов (MPC ограничение)")
        XCTAssertEqual(type, type.lowercased(),
                       "serviceType должен быть нижнего регистра")
    }

    func test_serviceType_value() {
        XCTAssertEqual(SiblingMPCWorker.serviceType, "hs-sibling")
    }

    // MARK: - init

    func test_init_doesNotCrash() {
        XCTAssertNoThrow(SiblingMPCWorker(displayName: "Маша"))
    }

    // MARK: - connectedDisplayNames: initially empty

    func test_connectedDisplayNames_initiallyEmpty() {
        let worker = SiblingMPCWorker(displayName: "Ваня")
        XCTAssertTrue(worker.connectedDisplayNames.isEmpty,
                      "До старта нет подключённых пиров")
    }

    // MARK: - peerID(for:): unknown displayName → nil

    func test_peerID_unknownDisplayName_returnsNil() {
        let worker = SiblingMPCWorker(displayName: "Тест")
        XCTAssertNil(worker.peerID(for: "UnknownPeer"),
                     "peerID для незарегистрированного имени → nil")
    }

    // MARK: - stop without start: idempotent

    func test_stop_withoutStart_doesNotCrash() {
        let worker = SiblingMPCWorker(displayName: "Тест")
        XCTAssertNoThrow(worker.stop())
    }

    // MARK: - send without session: silent skip

    func test_send_withoutSession_doesNotCrash() {
        let worker = SiblingMPCWorker(displayName: "Тест")
        let msg = SiblingMessage.disconnect
        XCTAssertNoThrow(worker.send(msg))
    }

    // MARK: - invite without peerID: silent skip

    func test_invite_unknownPeer_doesNotCrash() {
        let worker = SiblingMPCWorker(displayName: "Хост")
        XCTAssertNoThrow(worker.invite(displayName: "НеизвестныйПир"))
    }

    // MARK: - delegate: weak reference does not retain

    func test_delegate_weakReference() {
        let worker = SiblingMPCWorker(displayName: "Тест")
        class TestDelegate: SiblingMPCWorkerDelegate {
            func mpcWorkerDidDiscoverPeer(displayName: String) {}
            func mpcWorkerDidLosePeer(displayName: String) {}
            func mpcWorkerDidReceiveInvite(from displayName: String,
                                           accept: @MainActor @escaping () -> Void) {}
            func mpcWorkerDidConnect(displayName: String) {}
            func mpcWorkerDidDisconnect(displayName: String) {}
            func mpcWorkerDidReceive(message: SiblingMessage, from displayName: String) {}
        }
        var delegate: TestDelegate? = TestDelegate()
        worker.delegate = delegate
        XCTAssertNotNil(worker.delegate)
        delegate = nil
        XCTAssertNil(worker.delegate, "delegate должен быть weak")
    }
}
