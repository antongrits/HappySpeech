@testable import HappySpeech
import XCTest

// MARK: - Stub FAQ Worker

@MainActor
private final class StubFAQRepositoryWorker: FAQRepositoryWorkerProtocol {
    var faqs: [FAQEntry] = HelpCenterCorpus.faqs
    var videos: [TutorialVideo] = HelpCenterCorpus.videos
    var videoExistsResult = true
    private(set) var loadFAQCallCount = 0
    private(set) var loadVideosCallCount = 0
    private(set) var videoExistsCallCount = 0

    func loadFAQ() async -> [FAQEntry] {
        loadFAQCallCount += 1
        return faqs
    }
    func loadVideos() async -> [TutorialVideo] {
        loadVideosCallCount += 1
        return videos
    }
    func videoExists(_ resourceName: String) -> Bool {
        videoExistsCallCount += 1
        return videoExistsResult
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyHelpCenterPresenter: HelpCenterPresentationLogic, @unchecked Sendable {
    var loadCallCount = 0
    var toggleCallCount = 0
    var selectVideoCallCount = 0
    var contactCallCount = 0

    var lastLoad: HelpCenterModels.Load.Response?
    var lastToggle: HelpCenterModels.ToggleFAQ.Response?
    var lastVideo: HelpCenterModels.SelectVideo.Response?

    func presentLoad(response: HelpCenterModels.Load.Response) async {
        loadCallCount += 1
        lastLoad = response
    }
    func presentToggleFAQ(response: HelpCenterModels.ToggleFAQ.Response) async {
        toggleCallCount += 1
        lastToggle = response
    }
    func presentSelectVideo(response: HelpCenterModels.SelectVideo.Response) async {
        selectVideoCallCount += 1
        lastVideo = response
    }
    func presentContactSupport(response: HelpCenterModels.ContactSupport.Response) async {
        contactCallCount += 1
    }
}

// MARK: - Tests

@MainActor
final class HelpCenterInteractorTests: XCTestCase {

    private func makeSUT() -> (HelpCenterInteractor, SpyHelpCenterPresenter, StubFAQRepositoryWorker, SpyHapticService) {
        let worker = StubFAQRepositoryWorker()
        let haptic = SpyHapticService()
        let sut = HelpCenterInteractor(faqWorker: worker, hapticService: haptic)
        let spy = SpyHelpCenterPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    // MARK: - load

    func test_load_emitsResponse() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init())
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertFalse(spy.lastLoad?.entries.isEmpty ?? true)
        XCTAssertFalse(spy.lastLoad?.videos.isEmpty ?? true)
    }

    func test_load_includesAllCategories() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init())
        XCTAssertEqual(spy.lastLoad?.categories.count, FAQCategory.allCases.count)
    }

    func test_load_callsWorker() async {
        let (sut, _, worker, _) = makeSUT()
        await sut.load(request: .init())
        XCTAssertEqual(worker.loadFAQCallCount, 1)
        XCTAssertEqual(worker.loadVideosCallCount, 1)
    }

    // MARK: - toggleFAQ

    func test_toggleFAQ_expandsCollapsedEntry() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.toggleFAQ(request: .init(entryId: "faq-gs-1"))
        XCTAssertEqual(spy.toggleCallCount, 1)
        XCTAssertTrue(spy.lastToggle?.expanded ?? false)
        XCTAssertTrue(sut.expandedIds.contains("faq-gs-1"))
        XCTAssertGreaterThanOrEqual(haptic.selectionCount, 1)
    }

    func test_toggleFAQ_collapsesExpandedEntry() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.toggleFAQ(request: .init(entryId: "faq-gs-1"))
        await sut.toggleFAQ(request: .init(entryId: "faq-gs-1"))
        XCTAssertFalse(spy.lastToggle?.expanded ?? true)
        XCTAssertFalse(sut.expandedIds.contains("faq-gs-1"))
    }

    func test_toggleFAQ_multipleEntriesIndependent() async {
        let (sut, _, _, _) = makeSUT()
        await sut.toggleFAQ(request: .init(entryId: "faq-gs-1"))
        await sut.toggleFAQ(request: .init(entryId: "faq-vr-1"))
        XCTAssertTrue(sut.expandedIds.contains("faq-gs-1"))
        XCTAssertTrue(sut.expandedIds.contains("faq-vr-1"))
        XCTAssertEqual(sut.expandedIds.count, 2)
    }

    func test_toggleFAQ_returnsEntryId() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.toggleFAQ(request: .init(entryId: "faq-pr-1"))
        XCTAssertEqual(spy.lastToggle?.entryId, "faq-pr-1")
    }

    // MARK: - selectVideo

    func test_selectVideo_validId_emitsAndStoresSelection() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.selectVideo(request: .init(videoId: "tut-how-to-play"))
        XCTAssertEqual(spy.selectVideoCallCount, 1)
        XCTAssertEqual(sut.selectedVideo?.id, "tut-how-to-play")
        XCTAssertGreaterThanOrEqual(haptic.impactCount, 1)
    }

    func test_selectVideo_unknownId_ignored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.selectVideo(request: .init(videoId: "nonexistent"))
        XCTAssertEqual(spy.selectVideoCallCount, 0)
        XCTAssertNil(sut.selectedVideo)
    }

    func test_selectVideo_missingFile_ignored() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.videoExistsResult = false
        await sut.selectVideo(request: .init(videoId: "tut-how-to-play"))
        XCTAssertEqual(spy.selectVideoCallCount, 0)
        XCTAssertNil(sut.selectedVideo)
    }

    // MARK: - contactSupport

    func test_contactSupport_emitsSuccess() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.contactSupport(request: .init())
        XCTAssertEqual(spy.contactCallCount, 1)
        XCTAssertGreaterThanOrEqual(haptic.notificationCount, 1)
    }

    // MARK: - HelpCenterCorpus

    func test_corpus_videoLookup() {
        XCTAssertNotNil(HelpCenterCorpus.video(forId: "tut-breathing"))
        XCTAssertNil(HelpCenterCorpus.video(forId: "missing"))
    }

    func test_corpus_entryLookup() {
        XCTAssertNotNil(HelpCenterCorpus.entry(forId: "faq-pv-1"))
        XCTAssertNil(HelpCenterCorpus.entry(forId: "missing"))
    }

    func test_corpus_hasFiveVideos() {
        XCTAssertEqual(HelpCenterCorpus.videos.count, 5)
    }

    func test_faqCategory_keysNotEmpty() {
        for category in FAQCategory.allCases {
            XCTAssertFalse(category.titleKey.isEmpty)
            XCTAssertFalse(category.symbolName.isEmpty)
        }
    }
}
