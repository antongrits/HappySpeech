@testable import HappySpeech
import XCTest

// MARK: - VoiceJournalPresenterTests

@MainActor
final class VoiceJournalPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: VoiceJournalDisplayLogic {
        var lastLoadVM: VoiceJournalModels.LoadEntries.ViewModel?
        var lastSavedVM: VoiceJournalModels.LoadEntries.ViewModel?
        var recordingStartedCallCount = 0
        var lastFailMessage: String?

        func displayLoadEntries(viewModel: VoiceJournalModels.LoadEntries.ViewModel) async {
            lastLoadVM = viewModel
        }

        func displayRecordingStarted() async {
            recordingStartedCallCount += 1
        }

        func displayRecordingFailed(message: String) async {
            lastFailMessage = message
        }

        func displayRecordingSaved(viewModel: VoiceJournalModels.LoadEntries.ViewModel) async {
            lastSavedVM = viewModel
        }
    }

    private func makeSUT() -> (VoiceJournalPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = VoiceJournalPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeEntry(
        id: String = UUID().uuidString,
        title: String = "Запись",
        durationSeconds: Int = 45
    ) -> VoiceJournalEntry {
        VoiceJournalEntry(
            id: id,
            childId: "child-1",
            date: Date(timeIntervalSince1970: 1_716_480_000), // fixed date
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            title: title,
            durationSeconds: durationSeconds,
            transcript: nil
        )
    }

    // MARK: - presentLoadEntries

    func test_presentLoadEntries_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadEntries(response: .init(entries: []))
        XCTAssertNotNil(spy.lastLoadVM)
    }

    func test_presentLoadEntries_emptyEntries_isEmptyTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadEntries(response: .init(entries: []))
        XCTAssertTrue(spy.lastLoadVM?.isEmpty ?? false)
    }

    func test_presentLoadEntries_withEntries_isEmptyFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadEntries(response: .init(entries: [makeEntry()]))
        XCTAssertFalse(spy.lastLoadVM?.isEmpty ?? true)
    }

    func test_presentLoadEntries_durationFormattedCorrectly() async {
        // 45 seconds → "0:45"
        let (sut, spy) = makeSUT()
        let entry = makeEntry(durationSeconds: 45)
        await sut.presentLoadEntries(response: .init(entries: [entry]))
        XCTAssertEqual(spy.lastLoadVM?.rows.first?.durationText, "0:45")
    }

    func test_presentLoadEntries_longDurationFormattedWithMinutes() async {
        // 125 seconds → "2:05"
        let (sut, spy) = makeSUT()
        let entry = makeEntry(durationSeconds: 125)
        await sut.presentLoadEntries(response: .init(entries: [entry]))
        XCTAssertEqual(spy.lastLoadVM?.rows.first?.durationText, "2:05")
    }

    func test_presentLoadEntries_emptyTitleUsesDefaultTitle() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry(title: "")
        await sut.presentLoadEntries(response: .init(entries: [entry]))
        let rowTitle = spy.lastLoadVM?.rows.first?.title ?? ""
        XCTAssertFalse(rowTitle.isEmpty)
    }

    func test_presentLoadEntries_nonEmptyTitleKept() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry(title: "Моя запись")
        await sut.presentLoadEntries(response: .init(entries: [entry]))
        XCTAssertEqual(spy.lastLoadVM?.rows.first?.title, "Моя запись")
    }

    func test_presentLoadEntries_rowsCountMatchesEntries() async {
        let (sut, spy) = makeSUT()
        let entries = [makeEntry(), makeEntry(), makeEntry()]
        await sut.presentLoadEntries(response: .init(entries: entries))
        XCTAssertEqual(spy.lastLoadVM?.rows.count, 3)
    }

    func test_presentLoadEntries_emptyStateTitlesNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadEntries(response: .init(entries: []))
        XCTAssertFalse(spy.lastLoadVM?.emptyTitle.isEmpty ?? true)
        XCTAssertFalse(spy.lastLoadVM?.emptyBody.isEmpty ?? true)
        XCTAssertFalse(spy.lastLoadVM?.emptyCtaTitle.isEmpty ?? true)
    }

    // MARK: - presentRecordingStarted / Failed / Saved

    func test_presentRecordingStarted_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentRecordingStarted()
        XCTAssertEqual(spy.recordingStartedCallCount, 1)
    }

    func test_presentRecordingFailed_passesMessage() async {
        let (sut, spy) = makeSUT()
        await sut.presentRecordingFailed(message: "Нет доступа к микрофону")
        XCTAssertEqual(spy.lastFailMessage, "Нет доступа к микрофону")
    }

    func test_presentRecordingSaved_callsDisplaySaved() async {
        let (sut, spy) = makeSUT()
        await sut.presentRecordingSaved(allEntries: [makeEntry()])
        XCTAssertNotNil(spy.lastSavedVM)
        XCTAssertFalse(spy.lastSavedVM?.isEmpty ?? true)
    }
}
