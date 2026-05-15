import XCTest
@testable import HappySpeech

// MARK: - SpyBiometricGateService

private struct SpyBiometricGateService: BiometricGateService {
    var canUseResult: Bool
    var authResult: AuthResult

    func canUseBiometric() async -> Bool { canUseResult }
    func authenticate(reason: String) async -> AuthResult { authResult }
}

private extension AuthResult {
    static let testDenied: AuthResult = .denied(reason: "test")
}

// MARK: - SpySharePlayPresenter
// SharePlayPresentationLogic is a protocol → we can implement directly.

@MainActor
private final class SpySharePlayPresenter: SharePlayPresentationLogic {
    private(set) var loadCallCount: Int = 0
    private(set) var startSessionCallCount: Int = 0
    private(set) var stateChangeCallCount: Int = 0
    private(set) var remoteMessageCallCount: Int = 0
    private(set) var endSessionCallCount: Int = 0
    private(set) var sessionStatsCallCount: Int = 0

    private(set) var lastLoadResponse: SharePlay.Load.Response?
    private(set) var lastStartOutcome: SharePlay.StartSession.Response.Outcome?
    private(set) var lastStateChange: SharePlay.SessionStateChange.Response?

    func presentLoad(_ response: SharePlay.Load.Response) {
        loadCallCount += 1
        lastLoadResponse = response
    }
    func presentStartSession(_ response: SharePlay.StartSession.Response) {
        startSessionCallCount += 1
        lastStartOutcome = response.outcome
    }
    func presentSessionStateChange(_ response: SharePlay.SessionStateChange.Response) {
        stateChangeCallCount += 1
        lastStateChange = response
    }
    func presentRemoteMessage(_ response: SharePlay.RemoteMessage.Response) {
        remoteMessageCallCount += 1
    }
    func presentEndSession(_ response: SharePlay.EndSession.Response) {
        endSessionCallCount += 1
    }
    func presentSessionStats(_ response: SharePlay.SessionStats.Response) {
        sessionStatsCallCount += 1
    }
}

// MARK: - SharePlayInteractorTests

@MainActor
final class SharePlayInteractorTests: XCTestCase {

    // MARK: - SUT factory
    // Uses real FamilyShareplayController — on simulator activate() returns false (no FaceTime).

    private func makeSUT(
        canUseBiometric: Bool = true,
        authResult: AuthResult = .success
    ) -> (
        sut: SharePlayInteractor,
        childRepo: SpyChildRepository,
        presenter: SpySharePlayPresenter
    ) {
        let biometric = SpyBiometricGateService(canUseResult: canUseBiometric, authResult: authResult)
        let childRepo = SpyChildRepository(children: [
            TestDataBuilder.childProfile(id: "c1", name: "Маша")
        ])
        let controller = FamilyShareplayController()
        let sut = SharePlayInteractor(
            biometric: biometric,
            childRepository: childRepo,
            controller: controller
        )
        let presenter = SpySharePlayPresenter()
        sut.presenter = presenter
        return (sut, childRepo, presenter)
    }

    private func makeLesson() -> SharePlayLessonItem {
        SharePlayLessonItem(id: "sp-001", title: "Тест", soundId: "р", templateKind: "repeatAfterModel")
    }

    // MARK: - load

    func test_load_callsPresentLoad() async {
        let (sut, _, presenter) = makeSUT()
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        XCTAssertEqual(presenter.loadCallCount, 1)
    }

    func test_load_returnsChildName() async {
        let (sut, _, presenter) = makeSUT()
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        XCTAssertEqual(presenter.lastLoadResponse?.childName, "Маша")
    }

    func test_load_childNotFound_usesDefaultName() async {
        let (sut, _, presenter) = makeSUT()
        await sut.load(SharePlay.Load.Request(childId: "unknown"))
        XCTAssertFalse(presenter.lastLoadResponse?.childName.isEmpty ?? true)
    }

    func test_load_returnsAtLeast5Lessons() async {
        let (sut, _, presenter) = makeSUT()
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        XCTAssertGreaterThanOrEqual(presenter.lastLoadResponse?.availableLessons.count ?? 0, 5)
    }

    func test_load_reportsBiometricAvailability_false() async {
        let (sut, _, presenter) = makeSUT(canUseBiometric: false)
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        XCTAssertEqual(presenter.lastLoadResponse?.isBiometricAvailable, false)
    }

    func test_load_reportsBiometricAvailability_true() async {
        let (sut, _, presenter) = makeSUT(canUseBiometric: true)
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        XCTAssertEqual(presenter.lastLoadResponse?.isBiometricAvailable, true)
    }

    // MARK: - startSession biometric gate

    func test_startSession_biometricDenied_presentsAuthFailed() async {
        let (sut, _, presenter) = makeSUT(authResult: .testDenied)
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        await sut.startSession(SharePlay.StartSession.Request(lesson: makeLesson()))
        if case .authFailed = presenter.lastStartOutcome { } else {
            XCTFail("Expected authFailed, got \(String(describing: presenter.lastStartOutcome))")
        }
    }

    func test_startSession_biometricCancelled_presentsAuthFailed() async {
        let (sut, _, presenter) = makeSUT(authResult: .cancelled)
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        await sut.startSession(SharePlay.StartSession.Request(lesson: makeLesson()))
        if case .authFailed = presenter.lastStartOutcome { } else {
            XCTFail("Expected authFailed")
        }
    }

    func test_startSession_biometricFallback_doesNotReturnAuthFailed() async {
        // fallback is treated same as success
        let (sut, _, presenter) = makeSUT(authResult: .fallback)
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        await sut.startSession(SharePlay.StartSession.Request(lesson: makeLesson()))
        if case .authFailed = presenter.lastStartOutcome {
            XCTFail("fallback should NOT produce authFailed")
        }
    }

    func test_startSession_success_onSimulator_presentsNotAvailableOrActivating() async {
        // On simulator FaceTime is unavailable → notAvailable outcome is expected
        let (sut, _, presenter) = makeSUT(authResult: .success)
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        await sut.startSession(SharePlay.StartSession.Request(lesson: makeLesson()))
        switch presenter.lastStartOutcome {
        case .notAvailable, .activating, .error:
            break // all valid on simulator
        case .authFailed:
            XCTFail("Should not return authFailed for biometric success")
        case .none:
            XCTFail("Should have received an outcome")
        }
    }

    // MARK: - handleRemoteMessage

    func test_handleRemoteMessage_callsPresenter() async {
        let (sut, _, presenter) = makeSUT()
        let msg = SyncMessage(
            kind: .participantReady,
            timestamp: Date().timeIntervalSince1970,
            senderId: "dev-1"
        )
        await sut.handleRemoteMessage(msg)
        XCTAssertEqual(presenter.remoteMessageCallCount, 1)
    }

    func test_handleRemoteMessage_roundComplete_callsPresenter() async {
        let (sut, _, presenter) = makeSUT()
        let msg = SyncMessage(kind: .roundComplete(roundIndex: 1, score: 0.8), timestamp: Date().timeIntervalSince1970, senderId: "dev-1")
        await sut.handleRemoteMessage(msg)
        XCTAssertEqual(presenter.remoteMessageCallCount, 1)
    }

    // MARK: - handleSessionStateChange

    func test_handleSessionStateChange_active_forwarded() async {
        let (sut, _, presenter) = makeSUT()
        await sut.handleSessionStateChange(isActive: true, participantCount: 2)
        XCTAssertEqual(presenter.stateChangeCallCount, 1)
        XCTAssertEqual(presenter.lastStateChange?.isActive, true)
        XCTAssertEqual(presenter.lastStateChange?.participantCount, 2)
    }

    func test_handleSessionStateChange_inactive_forwarded() async {
        let (sut, _, presenter) = makeSUT()
        await sut.handleSessionStateChange(isActive: false, participantCount: 0)
        XCTAssertEqual(presenter.lastStateChange?.isActive, false)
    }

    // MARK: - endSession

    func test_endSession_callsPresentEndSession() async {
        let (sut, _, presenter) = makeSUT()
        await sut.endSession(SharePlay.EndSession.Request())
        XCTAssertEqual(presenter.endSessionCallCount, 1)
    }

    func test_endSession_doesNotCrash() async {
        // presentSessionStats may or may not fire depending on SharePlay runtime;
        // the key invariant is no crash and endSession is forwarded.
        let (sut, _, presenter) = makeSUT()
        await sut.endSession(SharePlay.EndSession.Request())
        XCTAssertEqual(presenter.endSessionCallCount, 1)
    }

    // MARK: - SharePlayLessonItem

    func test_lessonItem_hashable_equalItems() {
        let a = SharePlayLessonItem(id: "sp-001", title: "Тест", soundId: "р", templateKind: "repeat")
        let b = SharePlayLessonItem(id: "sp-001", title: "Тест", soundId: "р", templateKind: "repeat")
        XCTAssertEqual(a, b)
    }

    // MARK: - Period round-trip

    func test_startSession_multipleCalls_doNotCrash() async {
        let (sut, _, _) = makeSUT()
        await sut.load(SharePlay.Load.Request(childId: "c1"))
        await sut.startSession(SharePlay.StartSession.Request(lesson: makeLesson()))
        await sut.startSession(SharePlay.StartSession.Request(lesson: makeLesson()))
        // Should not crash on repeated calls
    }
}
