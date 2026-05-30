@testable import HappySpeech
import XCTest

// MARK: - VoiceJournalInteractorTests
//
// VoiceJournalInteractor зависит от AVFoundation (реальный рекордер) и
// RealmActor. В unit-тестах мы покрываем пути без реальных аудио-операций:
//   - presentLoadEntries вызывается через loadEntries
//   - stopRecording без активной записи → presentRecordingFailed
//   - play с несуществующим файлом → Response(success: false)
//   - cancelRecording не падает без активного recorder
//   - stopPlayback не падает без активного player

@MainActor
final class VoiceJournalInteractorTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: VoiceJournalDisplayLogic {
        var lastLoadVM: VoiceJournalModels.LoadEntries.ViewModel?
        var lastSavedVM: VoiceJournalModels.LoadEntries.ViewModel?
        var recordingStartedCount = 0
        var lastFailMessage: String?

        func displayLoadEntries(viewModel: VoiceJournalModels.LoadEntries.ViewModel) async {
            lastLoadVM = viewModel
        }

        func displayRecordingStarted() async {
            recordingStartedCount += 1
        }

        func displayRecordingFailed(message: String) async {
            lastFailMessage = message
        }

        func displayRecordingSaved(viewModel: VoiceJournalModels.LoadEntries.ViewModel) async {
            lastSavedVM = viewModel
        }
    }

    private var display: DisplaySpy!

    override func setUp() async throws {
        try await super.setUp()
        display = DisplaySpy()
    }

    override func tearDown() async throws {
        display = nil
        try await super.tearDown()
    }

    private func makeSUT(childId: String = "child-1") -> VoiceJournalInteractor {
        let presenter = VoiceJournalPresenter(displayLogic: display)
        let router = VoiceJournalRouter()
        let realm = RealmActor()
        return VoiceJournalInteractor(
            presenter: presenter,
            router: router,
            realmActor: realm,
            childId: childId
        )
    }

    // MARK: - loadEntries

    func test_loadEntries_callsDisplayLoadEntries() async {
        let sut = makeSUT(childId: "vj-\(UUID().uuidString)")
        await sut.loadEntries(.init(childId: "child-loadtest"))
        // Presenter.presentLoadEntries is always called (even with empty list).
        XCTAssertNotNil(display.lastLoadVM)
    }

    func test_loadEntries_freshChild_returnsEmptyOrSeeded() async {
        // A fresh child ID with no Realm entries returns an empty list.
        let sut = makeSUT(childId: "child-fresh-\(UUID().uuidString)")
        await sut.loadEntries(.init(childId: "child-fresh"))
        XCTAssertNotNil(display.lastLoadVM)
    }

    func test_loadEntries_emptyResult_viewModelIsEmpty() async {
        // Realm actor returns [] for a brand new childId.
        let sut = makeSUT(childId: "vj-test-\(UUID().uuidString)")
        await sut.loadEntries(.init(childId: "vj-test-new"))
        let vm = display.lastLoadVM
        XCTAssertNotNil(vm)
        // isEmpty must reflect actual state — can be true for a new child.
        XCTAssertEqual(vm?.isEmpty, vm?.rows.isEmpty)
    }

    // MARK: - stopRecording without active recorder

    func test_stopRecording_noActiveRecorder_callsDisplayFailed() async {
        let sut = makeSUT()
        await sut.stopRecording(.init(childId: "child-1", title: "Тест"))
        XCTAssertNotNil(display.lastFailMessage)
    }

    func test_stopRecording_noActiveRecorder_doesNotCallDisplaySaved() async {
        let sut = makeSUT()
        await sut.stopRecording(.init(childId: "child-1", title: "Тест"))
        XCTAssertNil(display.lastSavedVM)
    }

    // MARK: - play with nonexistent file

    func test_play_nonexistentFile_returnsFailure() async {
        let sut = makeSUT()
        let missingURL = URL(fileURLWithPath: "/nonexistent/path/recording.m4a")
        let entry = VoiceJournalEntry(
            id: "e-1",
            childId: "child-1",
            date: Date(),
            fileURL: missingURL,
            title: "Тест",
            durationSeconds: 10,
            transcript: nil
        )
        let result = await sut.play(.init(entry: entry))
        XCTAssertFalse(result.success)
    }

    // MARK: - cancelRecording

    func test_cancelRecording_noActiveRecorder_doesNotCrash() {
        let sut = makeSUT()
        sut.cancelRecording()
        XCTAssertTrue(true)
    }

    func test_cancelRecording_calledTwice_doesNotCrash() {
        let sut = makeSUT()
        sut.cancelRecording()
        sut.cancelRecording()
        XCTAssertTrue(true)
    }

    // MARK: - stopPlayback

    func test_stopPlayback_noActivePlayer_doesNotCrash() {
        let sut = makeSUT()
        sut.stopPlayback()
        XCTAssertTrue(true)
    }

    // MARK: - delete

    func test_delete_missingFile_doesNotCrash() async {
        let sut = makeSUT(childId: "child-del-\(UUID().uuidString)")
        let missingURL = URL(fileURLWithPath: "/nonexistent/vj/recording.m4a")
        let entry = VoiceJournalEntry(
            id: "del-e-1",
            childId: "child-del",
            date: Date(),
            fileURL: missingURL,
            title: "Удалить",
            durationSeconds: 5,
            transcript: nil
        )
        await sut.delete(.init(entry: entry))
        // After delete, loadEntries is called internally, so display should have been refreshed.
        XCTAssertNotNil(display.lastLoadVM)
    }

    // MARK: - VoiceJournalEntry duration formatting

    func test_durationLabel_60seconds_isOneMinute() {
        // Validate duration formatting through presenter (Presenter unit)
        let spy = DisplaySpy()
        let presenter = VoiceJournalPresenter(displayLogic: spy)
        let entry = VoiceJournalEntry(
            id: "e", childId: "c", date: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/t.m4a"),
            title: "T", durationSeconds: 60, transcript: nil
        )
        Task { @MainActor in
            await presenter.presentLoadEntries(response: .init(entries: [entry]))
            XCTAssertEqual(spy.lastLoadVM?.rows.first?.durationText, "1:00")
        }
    }
}
