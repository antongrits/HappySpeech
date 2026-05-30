@testable import HappySpeech
import XCTest

// MARK: - ParentVoiceNotePresenterTests
//
// Verifies the non-trivial Response → ViewModel mapping in the parent
// voice-note presenter:
//   - Load: clips grouped by lessonTemplate → hasClip flag per template
//   - Load: most-recent clip wins when several exist for one template
//   - Load: durationLabel / recordedAtLabel populated only when clip exists
//   - Load: isEnabledGlobally + localized chrome strings carried
//   - Save / Delete / Toggle / Error → values forwarded verbatim
//   - formatDuration: rounds and clamps negatives

@MainActor
final class ParentVoiceNotePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ParentVoiceNoteDisplayLogic {
        var loadVM: ParentVoiceNoteModels.Load.ViewModel?
        var savedClip: ParentVoiceClipData?
        var deletedId: String?
        var toggled: Bool?
        var errorMessage: String?

        func displayLoad(viewModel: ParentVoiceNoteModels.Load.ViewModel) async { loadVM = viewModel }
        func displaySave(savedClip: ParentVoiceClipData) async { self.savedClip = savedClip }
        func displayDelete(deletedId: String) async { self.deletedId = deletedId }
        func displayToggle(isEnabled: Bool) async { toggled = isEnabled }
        func displayError(message: String) async { errorMessage = message }
    }

    private func makeSUT() -> (ParentVoiceNotePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ParentVoiceNotePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func clip(
        id: String,
        template: String,
        duration: Double = 12,
        recordedAt: Date = Date()
    ) -> ParentVoiceClipData {
        ParentVoiceClipData(
            id: id, childId: "c1", lessonTemplate: template,
            fileURL: "/tmp/\(id).m4a", durationSec: duration,
            recordedAt: recordedAt, isEnabled: true
        )
    }

    private func response(
        templates: [LessonTemplateOption] = LessonTemplateOption.canonical,
        clips: [ParentVoiceClipData] = [],
        enabled: Bool = true
    ) -> ParentVoiceNoteModels.Load.Response {
        .init(childId: "c1", templates: templates, existingClips: clips, isEnabledGlobally: enabled)
    }

    // MARK: - Load

    func test_load_templateCountPreserved() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: response())
        XCTAssertEqual(spy.loadVM?.templates.count, LessonTemplateOption.canonical.count)
    }

    func test_load_hasClipFlagSetForMatchingTemplate() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: response(clips: [clip(id: "k1", template: "bingo")]))
        let bingo = spy.loadVM?.templates.first { $0.id == "bingo" }
        let memory = spy.loadVM?.templates.first { $0.id == "memory" }
        XCTAssertEqual(bingo?.hasClip, true)
        XCTAssertEqual(memory?.hasClip, false)
    }

    func test_load_durationAndRecordedLabels_presentOnlyWhenClipExists() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: response(clips: [clip(id: "k1", template: "bingo")]))
        let bingo = spy.loadVM?.templates.first { $0.id == "bingo" }
        let memory = spy.loadVM?.templates.first { $0.id == "memory" }
        XCTAssertNotNil(bingo?.durationLabel)
        XCTAssertNotNil(bingo?.recordedAtLabel)
        XCTAssertNil(memory?.durationLabel ?? nil)
        XCTAssertNil(memory?.recordedAtLabel ?? nil)
    }

    func test_load_mostRecentClipWinsPerTemplate() async {
        let (sut, spy) = makeSUT()
        let old = clip(id: "old", template: "bingo", duration: 5,
                       recordedAt: Date(timeIntervalSince1970: 1_000))
        let new = clip(id: "new", template: "bingo", duration: 25,
                       recordedAt: Date(timeIntervalSince1970: 2_000))
        await sut.presentLoad(response: response(clips: [old, new]))
        let bingo = spy.loadVM?.templates.first { $0.id == "bingo" }
        // Duration label must derive from the newer clip (25s), not the older (5s).
        XCTAssertTrue(bingo?.durationLabel?.contains("25") ?? false,
                      "Самая свежая запись должна определять метку длительности")
    }

    func test_load_isEnabledGloballyCarried() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: response(enabled: false))
        XCTAssertEqual(spy.loadVM?.isEnabledGlobally, false)
    }

    func test_load_chromeStringsNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: response())
        XCTAssertFalse(spy.loadVM?.title.isEmpty ?? true)
        XCTAssertFalse(spy.loadVM?.introMessage.isEmpty ?? true)
        XCTAssertFalse(spy.loadVM?.optInLabel.isEmpty ?? true)
        XCTAssertFalse(spy.loadVM?.optInSubtitle.isEmpty ?? true)
    }

    func test_load_noClips_allTemplatesHaveNoClip() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: response(clips: []))
        XCTAssertTrue((spy.loadVM?.templates ?? []).allSatisfy { !$0.hasClip })
    }

    // MARK: - Save / Delete / Toggle / Error

    func test_save_forwardsClip() async {
        let (sut, spy) = makeSUT()
        let c = clip(id: "saved", template: "memory")
        await sut.presentSave(savedClip: c)
        XCTAssertEqual(spy.savedClip?.id, "saved")
    }

    func test_delete_forwardsId() async {
        let (sut, spy) = makeSUT()
        await sut.presentDelete(deletedId: "gone")
        XCTAssertEqual(spy.deletedId, "gone")
    }

    func test_toggle_forwardsFlag() async {
        let (sut, spy) = makeSUT()
        await sut.presentToggle(isEnabled: true)
        XCTAssertEqual(spy.toggled, true)
    }

    func test_error_forwardsMessage() async {
        let (sut, spy) = makeSUT()
        await sut.presentError(message: "Ошибка записи")
        XCTAssertEqual(spy.errorMessage, "Ошибка записи")
    }

    // MARK: - Duration formatting helper

    func test_formatDuration_roundsToNearestSecond() {
        XCTAssertTrue(ParentVoiceNotePresenter.formatDuration(12.4).contains("12"))
        XCTAssertTrue(ParentVoiceNotePresenter.formatDuration(12.6).contains("13"))
    }

    func test_formatDuration_clampsNegativeToZero() {
        XCTAssertTrue(ParentVoiceNotePresenter.formatDuration(-3).contains("0"))
    }
}
