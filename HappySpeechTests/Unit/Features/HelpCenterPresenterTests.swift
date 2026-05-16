import XCTest
@testable import HappySpeech

// MARK: - HelpCenterPresenterTests
//
// Phase 2.6 batch 3 — покрытие HelpCenterPresenter (0% → цель ≥90%).

@MainActor
final class HelpCenterPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: HelpCenterDisplayLogic {
        var loadVM: HelpCenterModels.Load.ViewModel?
        var toggleFAQVM: HelpCenterModels.ToggleFAQ.ViewModel?
        var selectVideoVM: HelpCenterModels.SelectVideo.ViewModel?
        var contactSupportVM: HelpCenterModels.ContactSupport.ViewModel?

        func displayLoad(viewModel: HelpCenterModels.Load.ViewModel) async { loadVM = viewModel }
        func displayToggleFAQ(viewModel: HelpCenterModels.ToggleFAQ.ViewModel) async { toggleFAQVM = viewModel }
        func displaySelectVideo(viewModel: HelpCenterModels.SelectVideo.ViewModel) async { selectVideoVM = viewModel }
        func displayContactSupport(viewModel: HelpCenterModels.ContactSupport.ViewModel) async { contactSupportVM = viewModel }
    }

    private func makeSUT() -> (HelpCenterPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let sut = HelpCenterPresenter(displayLogic: spy)
        return (sut, spy)
    }

    private func makeEntry(id: String = "faq-1", category: FAQCategory = .gettingStarted) -> FAQEntry {
        FAQEntry(
            id: id,
            questionKey: "helpCenter.faq.gs1.question",
            answerKey: "helpCenter.faq.gs1.answer",
            category: category
        )
    }

    private func makeVideo(id: String = "vid-1", durationSeconds: Int = 90) -> TutorialVideo {
        TutorialVideo(
            id: id,
            titleKey: "helpCenter.video.howToPlay.title",
            descriptionKey: "helpCenter.video.howToPlay.description",
            resourceName: "tutorial_how_to_play",
            durationSeconds: durationSeconds,
            symbolName: "play.rectangle.fill"
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_emptyEntries_categoriesEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            categories: [.gettingStarted],
            entries: [],
            videos: []
        ))
        XCTAssertNotNil(spy.loadVM)
        XCTAssertTrue(spy.loadVM?.categories.isEmpty == true)
    }

    func test_presentLoad_oneEntry_oneCategoryOneEntry() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry(id: "faq-1", category: .gettingStarted)
        await sut.presentLoad(response: .init(
            categories: [.gettingStarted],
            entries: [entry],
            videos: []
        ))
        XCTAssertEqual(spy.loadVM?.categories.count, 1)
        XCTAssertEqual(spy.loadVM?.categories.first?.entries.count, 1)
    }

    func test_presentLoad_contactCtaNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(categories: [], entries: [], videos: []))
        XCTAssertFalse(spy.loadVM?.contactCta.isEmpty ?? true)
        XCTAssertFalse(spy.loadVM?.contactDescription.isEmpty ?? true)
    }

    func test_presentLoad_videoSectionTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(categories: [], entries: [], videos: []))
        XCTAssertFalse(spy.loadVM?.videoSection.title.isEmpty ?? true)
    }

    func test_presentLoad_videoCell_durationLabel_formattedCorrectly() async {
        let (sut, spy) = makeSUT()
        let video = makeVideo(durationSeconds: 125)
        await sut.presentLoad(response: .init(categories: [], entries: [], videos: [video]))
        let cell = spy.loadVM?.videoSection.videos.first
        XCTAssertEqual(cell?.durationLabel, "2:05")
    }

    func test_presentLoad_videoCell_zeroDuration_formattedAsZero() async {
        let (sut, spy) = makeSUT()
        let video = makeVideo(durationSeconds: 0)
        await sut.presentLoad(response: .init(categories: [], entries: [], videos: [video]))
        let cell = spy.loadVM?.videoSection.videos.first
        XCTAssertEqual(cell?.durationLabel, "0:00")
    }

    func test_presentLoad_videoCell_exactlyOneMinute() async {
        let (sut, spy) = makeSUT()
        let video = makeVideo(durationSeconds: 60)
        await sut.presentLoad(response: .init(categories: [], entries: [], videos: [video]))
        XCTAssertEqual(spy.loadVM?.videoSection.videos.first?.durationLabel, "1:00")
    }

    func test_presentLoad_videoCell_accessibilityLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(categories: [], entries: [], videos: [makeVideo()]))
        XCTAssertFalse(spy.loadVM?.videoSection.videos.first?.accessibilityLabel.isEmpty ?? true)
    }

    func test_presentLoad_categorySymbol_notEmpty() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry(category: .voiceRecognition)
        await sut.presentLoad(response: .init(
            categories: [.voiceRecognition],
            entries: [entry],
            videos: []
        ))
        XCTAssertFalse(spy.loadVM?.categories.first?.symbolName.isEmpty ?? true)
    }

    // MARK: - presentToggleFAQ

    func test_presentToggleFAQ_expandedTrue_propagates() async {
        let (sut, spy) = makeSUT()
        await sut.presentToggleFAQ(response: .init(entryId: "faq-1", expanded: true))
        XCTAssertEqual(spy.toggleFAQVM?.entryId, "faq-1")
        XCTAssertTrue(spy.toggleFAQVM?.expanded == true)
    }

    func test_presentToggleFAQ_expandedFalse_propagates() async {
        let (sut, spy) = makeSUT()
        await sut.presentToggleFAQ(response: .init(entryId: "faq-2", expanded: false))
        XCTAssertEqual(spy.toggleFAQVM?.entryId, "faq-2")
        XCTAssertFalse(spy.toggleFAQVM?.expanded ?? true)
    }

    // MARK: - presentSelectVideo

    func test_presentSelectVideo_titleNotEmpty() async {
        let (sut, spy) = makeSUT()
        let video = makeVideo(durationSeconds: 95)
        await sut.presentSelectVideo(response: .init(video: video))
        XCTAssertNotNil(spy.selectVideoVM)
        XCTAssertFalse(spy.selectVideoVM?.videoTitle.isEmpty ?? true)
        XCTAssertFalse(spy.selectVideoVM?.videoDescription.isEmpty ?? true)
        XCTAssertEqual(spy.selectVideoVM?.resourceName, "tutorial_how_to_play")
        XCTAssertEqual(spy.selectVideoVM?.durationLabel, "1:35")
    }

    func test_presentSelectVideo_durationFormatted_1min35sec() async {
        let (sut, spy) = makeSUT()
        let video = makeVideo(durationSeconds: 95)
        await sut.presentSelectVideo(response: .init(video: video))
        XCTAssertEqual(spy.selectVideoVM?.durationLabel, "1:35")
    }

    // MARK: - presentContactSupport

    func test_presentContactSupport_success_toastNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentContactSupport(response: .init(success: true))
        XCTAssertFalse(spy.contactSupportVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentContactSupport_failure_toastNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentContactSupport(response: .init(success: false))
        XCTAssertFalse(spy.contactSupportVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentContactSupport_successAndFailure_differentMessages() async {
        let (sut, spy) = makeSUT()
        await sut.presentContactSupport(response: .init(success: true))
        let successMsg = spy.contactSupportVM?.toastMessage

        await sut.presentContactSupport(response: .init(success: false))
        let failMsg = spy.contactSupportVM?.toastMessage

        XCTAssertNotEqual(successMsg, failMsg)
    }

    // MARK: - formatDuration (через presentSelectVideo)

    func test_formatDuration_65seconds_1min05sec() async {
        let (sut, spy) = makeSUT()
        let video = makeVideo(durationSeconds: 65)
        await sut.presentSelectVideo(response: .init(video: video))
        XCTAssertEqual(spy.selectVideoVM?.durationLabel, "1:05")
    }

    func test_formatDuration_3600seconds_60min00sec() async {
        let (sut, spy) = makeSUT()
        let video = makeVideo(durationSeconds: 3600)
        await sut.presentSelectVideo(response: .init(video: video))
        XCTAssertEqual(spy.selectVideoVM?.durationLabel, "60:00")
    }
}
