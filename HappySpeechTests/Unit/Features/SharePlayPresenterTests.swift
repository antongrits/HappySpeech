@testable import HappySpeech
import XCTest

// MARK: - SharePlayPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие SharePlayPresenter (0% → цель ≥90%).
//
// Presenter мутирует @Observable SharePlayViewModel напрямую.
// Тесты создают SharePlayViewModel, присоединяют и проверяют её свойства.

@MainActor
final class SharePlayPresenterTests: XCTestCase {

    private func makeSUT() -> (SharePlayPresenter, SharePlayViewModel) {
        let viewModel = SharePlayViewModel()
        let presenter = SharePlayPresenter()
        presenter.viewModel = viewModel
        return (presenter, viewModel)
    }

    private func makeLesson(
        id: String = "l-1",
        title: String = "Урок 1",
        soundId: String = "С"
    ) -> SharePlayLessonItem {
        SharePlayLessonItem(id: id, title: title, soundId: soundId, templateKind: "listen-and-choose")
    }

    private func makeSyncMessage(kind: SyncMessage.Kind) -> SyncMessage {
        SyncMessage(kind: kind, timestamp: Date().timeIntervalSince1970, senderId: "device-1")
    }

    // MARK: - presentLoad

    func test_presentLoad_childNameSet() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(childName: "Маша", availableLessons: [], isBiometricAvailable: false))
        XCTAssertEqual(vm.childName, "Маша")
    }

    func test_presentLoad_availableLessonsSet() {
        let (sut, vm) = makeSUT()
        let lessons = [makeLesson(), makeLesson(id: "l-2")]
        sut.presentLoad(.init(childName: "Маша", availableLessons: lessons, isBiometricAvailable: false))
        XCTAssertEqual(vm.availableLessons.count, 2)
    }

    func test_presentLoad_startButtonLabelNotEmpty() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(childName: "Маша", availableLessons: [], isBiometricAvailable: false))
        XCTAssertFalse(vm.startButtonLabel.isEmpty)
    }

    func test_presentLoad_biometricHintVisible_true() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(childName: "Маша", availableLessons: [], isBiometricAvailable: true))
        XCTAssertTrue(vm.biometricHintVisible)
    }

    func test_presentLoad_biometricHintVisible_false() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(childName: "Маша", availableLessons: [], isBiometricAvailable: false))
        XCTAssertFalse(vm.biometricHintVisible)
    }

    // MARK: - presentStartSession

    func test_presentStartSession_activating_noAlert() {
        let (sut, vm) = makeSUT()
        sut.presentStartSession(.init(outcome: .activating))
        XCTAssertFalse(vm.showAlert)
        XCTAssertFalse(vm.showFallbackHint)
    }

    func test_presentStartSession_notAvailable_showsFallbackHint() {
        let (sut, vm) = makeSUT()
        sut.presentStartSession(.init(outcome: .notAvailable))
        XCTAssertTrue(vm.showFallbackHint)
        XCTAssertFalse(vm.showAlert)
    }

    func test_presentStartSession_authFailed_showsAlert() {
        let (sut, vm) = makeSUT()
        sut.presentStartSession(.init(outcome: .authFailed))
        XCTAssertTrue(vm.showAlert)
        XCTAssertNotNil(vm.alertMessage)
        XCTAssertFalse(vm.showFallbackHint)
    }

    func test_presentStartSession_error_showsAlertWithMessage() {
        let (sut, vm) = makeSUT()
        sut.presentStartSession(.init(outcome: .error("Тест ошибки")))
        XCTAssertTrue(vm.showAlert)
        XCTAssertEqual(vm.alertMessage, "Тест ошибки")
    }

    // MARK: - presentSessionStateChange

    func test_presentSessionStateChange_isActiveSet() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 2))
        XCTAssertTrue(vm.isSessionActive)
    }

    func test_presentSessionStateChange_endButtonVisibleWhenActive() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 1))
        XCTAssertTrue(vm.endButtonVisible)
    }

    func test_presentSessionStateChange_endButtonHiddenWhenInactive() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: false, participantCount: 0))
        XCTAssertFalse(vm.endButtonVisible)
    }

    func test_presentSessionStateChange_zeroParticipants_countLabelNotEmpty() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 0))
        XCTAssertFalse(vm.participantCountLabel.isEmpty)
    }

    func test_presentSessionStateChange_oneParticipant_countLabelNotEmpty() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 1))
        XCTAssertFalse(vm.participantCountLabel.isEmpty)
    }

    func test_presentSessionStateChange_manyParticipants_countLabelNotEmpty() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 3))
        XCTAssertFalse(vm.participantCountLabel.isEmpty)
    }

    // MARK: - presentRemoteMessage

    func test_presentRemoteMessage_roundComplete_remoteScoreSet() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .roundComplete(roundIndex: 1, score: 0.85))
        sut.presentRemoteMessage(.init(message: msg))
        XCTAssertEqual(vm.remoteScore ?? -1, 0.85, accuracy: 0.001)
    }

    func test_presentRemoteMessage_roundComplete_remoteLabelNotEmpty() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .roundComplete(roundIndex: 1, score: 0.9))
        sut.presentRemoteMessage(.init(message: msg))
        XCTAssertFalse(vm.remoteChildLabel?.isEmpty ?? true)
    }

    func test_presentRemoteMessage_lyalyaCelebration_celebrationVisible() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .lyalyaCelebration(intensity: "high"))
        sut.presentRemoteMessage(.init(message: msg))
        XCTAssertTrue(vm.celebrationVisible)
    }

    func test_presentRemoteMessage_sessionComplete_sessionCompleteVisible() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .sessionComplete(totalScore: 0.75))
        sut.presentRemoteMessage(.init(message: msg))
        XCTAssertTrue(vm.sessionCompleteVisible)
    }

    func test_presentRemoteMessage_sessionComplete_totalScoreSet() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .sessionComplete(totalScore: 0.6))
        sut.presentRemoteMessage(.init(message: msg))
        XCTAssertEqual(vm.remoteScore ?? -1, 0.6, accuracy: 0.001)
    }

    func test_presentRemoteMessage_participantReady_remoteLabelNotEmpty() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .participantReady)
        sut.presentRemoteMessage(.init(message: msg))
        XCTAssertFalse(vm.remoteChildLabel?.isEmpty ?? true)
    }

    func test_presentRemoteMessage_roundStart_noChanges() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .roundStart(roundIndex: 1, soundId: "С"))
        sut.presentRemoteMessage(.init(message: msg))
        // roundStart falls into default: no changes
        XCTAssertNil(vm.remoteScore)
        XCTAssertNil(vm.remoteChildLabel)
        XCTAssertFalse(vm.celebrationVisible)
        XCTAssertFalse(vm.sessionCompleteVisible)
    }

    // MARK: - presentEndSession

    func test_presentEndSession_sessionInactive() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 2))
        sut.presentEndSession(.init())
        XCTAssertFalse(vm.isSessionActive)
    }

    func test_presentEndSession_endButtonHidden() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 1))
        sut.presentEndSession(.init())
        XCTAssertFalse(vm.endButtonVisible)
    }

    func test_presentEndSession_remoteScoreCleared() {
        let (sut, vm) = makeSUT()
        let msg = makeSyncMessage(kind: .roundComplete(roundIndex: 1, score: 0.9))
        sut.presentRemoteMessage(.init(message: msg))
        sut.presentEndSession(.init())
        XCTAssertNil(vm.remoteScore)
    }

    func test_presentEndSession_participantCountLabelCleared() {
        let (sut, vm) = makeSUT()
        sut.presentSessionStateChange(.init(isActive: true, participantCount: 3))
        sut.presentEndSession(.init())
        XCTAssertEqual(vm.participantCountLabel, "")
    }
}
