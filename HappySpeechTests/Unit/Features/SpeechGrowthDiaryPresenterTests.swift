@testable import HappySpeech
import XCTest

// MARK: - SpeechGrowthDiaryPresenterTests

@MainActor
final class SpeechGrowthDiaryPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SpeechGrowthDiaryDisplayLogic {
        var lastListVM: SpeechGrowthDiaryModels.List.ViewModel?
        var lastShareVM: SpeechGrowthDiaryModels.Share.ViewModel?

        func displayList(viewModel: SpeechGrowthDiaryModels.List.ViewModel) async {
            lastListVM = viewModel
        }

        func displayShare(viewModel: SpeechGrowthDiaryModels.Share.ViewModel) async {
            lastShareVM = viewModel
        }
    }

    private func makeSUT() -> (SpeechGrowthDiaryPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = SpeechGrowthDiaryPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeClip(
        id: String = UUID().uuidString,
        durationSeconds: Double = 25.0,
        topicTag: String = "артикуляция",
        targetSound: String = "Р",
        note: String = "",
        shareToken: String? = nil,
        shareTokenExpiresAt: Date? = nil
    ) -> EncryptedVideoClipData {
        EncryptedVideoClipData(
            id: id,
            childId: "child-1",
            recordedAt: Date(timeIntervalSince1970: 1_716_480_000),
            durationSeconds: durationSeconds,
            encryptedClipPath: "/enc/\(id).enc",
            encryptedThumbnailPath: "",
            topicTag: topicTag,
            targetSound: targetSound,
            note: note,
            shareToken: shareToken,
            shareTokenExpiresAt: shareTokenExpiresAt
        )
    }

    private func makeListResponse(clips: [EncryptedVideoClipData] = []) -> SpeechGrowthDiaryModels.List.Response {
        SpeechGrowthDiaryModels.List.Response(clips: clips)
    }

    // MARK: - presentList

    func test_presentList_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentList(response: makeListResponse())
        XCTAssertNotNil(spy.lastListVM)
    }

    func test_presentList_emptyClips_isEmptyTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentList(response: makeListResponse(clips: []))
        XCTAssertTrue(spy.lastListVM?.isEmpty ?? false)
    }

    func test_presentList_withClips_isEmptyFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentList(response: makeListResponse(clips: [makeClip()]))
        XCTAssertFalse(spy.lastListVM?.isEmpty ?? true)
    }

    func test_presentList_clipsCountMatchesInput() async {
        let (sut, spy) = makeSUT()
        let clips = [makeClip(), makeClip(), makeClip()]
        await sut.presentList(response: makeListResponse(clips: clips))
        XCTAssertEqual(spy.lastListVM?.clips.count, 3)
    }

    func test_presentList_durationFormattedInMinutesSeconds() async {
        // 90 seconds → "1:30"
        let (sut, spy) = makeSUT()
        let clip = makeClip(durationSeconds: 90.0)
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertEqual(spy.lastListVM?.clips.first?.durationLabel, "1:30")
    }

    func test_presentList_shortDuration_formattedWithZeroMinutes() async {
        // 25 seconds → "0:25"
        let (sut, spy) = makeSUT()
        let clip = makeClip(durationSeconds: 25.0)
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertEqual(spy.lastListVM?.clips.first?.durationLabel, "0:25")
    }

    func test_presentList_topicTagPassedThrough() async {
        let (sut, spy) = makeSUT()
        let clip = makeClip(topicTag: "свистящие")
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertEqual(spy.lastListVM?.clips.first?.topicTag, "свистящие")
    }

    func test_presentList_targetSoundPassedThrough() async {
        let (sut, spy) = makeSUT()
        let clip = makeClip(targetSound: "Ш")
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertEqual(spy.lastListVM?.clips.first?.targetSound, "Ш")
    }

    func test_presentList_notePassedThrough() async {
        let (sut, spy) = makeSUT()
        let clip = makeClip(note: "Хорошо получился звук")
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertEqual(spy.lastListVM?.clips.first?.note, "Хорошо получился звук")
    }

    func test_presentList_noShareToken_isSharedFalse() async {
        let (sut, spy) = makeSUT()
        let clip = makeClip(shareToken: nil)
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertFalse(spy.lastListVM?.clips.first?.isShared ?? true)
    }

    func test_presentList_withShareToken_isSharedTrue() async {
        let (sut, spy) = makeSUT()
        let clip = makeClip(shareToken: "tok-abc-123")
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertTrue(spy.lastListVM?.clips.first?.isShared ?? false)
    }

    func test_presentList_shareTokenExpired_isShareExpiredTrue() async {
        let (sut, spy) = makeSUT()
        let pastDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let clip = makeClip(shareToken: "tok-old", shareTokenExpiresAt: pastDate)
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertTrue(spy.lastListVM?.clips.first?.isShareExpired ?? false)
    }

    func test_presentList_shareTokenNotYetExpired_isShareExpiredFalse() async {
        let (sut, spy) = makeSUT()
        let futureDate = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        let clip = makeClip(shareToken: "tok-valid", shareTokenExpiresAt: futureDate)
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertFalse(spy.lastListVM?.clips.first?.isShareExpired ?? true)
    }

    func test_presentList_noShareTokenNilExpiry_isShareExpiredFalse() async {
        let (sut, spy) = makeSUT()
        let clip = makeClip(shareToken: nil, shareTokenExpiresAt: nil)
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertFalse(spy.lastListVM?.clips.first?.isShareExpired ?? true)
    }

    func test_presentList_recordedAtLabelIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        let clip = makeClip()
        await sut.presentList(response: makeListResponse(clips: [clip]))
        XCTAssertFalse(spy.lastListVM?.clips.first?.recordedAtLabel.isEmpty ?? true)
    }

    // MARK: - presentShare

    func test_presentShare_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let response = SpeechGrowthDiaryModels.Share.Response(
            clipId: "clip-1",
            token: "share-tok-xyz",
            expiresAt: Date(timeIntervalSinceNow: 3600)
        )
        await sut.presentShare(response: response)
        XCTAssertNotNil(spy.lastShareVM)
    }

    func test_presentShare_tokenPassedThrough() async {
        let (sut, spy) = makeSUT()
        let response = SpeechGrowthDiaryModels.Share.Response(
            clipId: "clip-1",
            token: "abc-def-123",
            expiresAt: Date(timeIntervalSinceNow: 3600)
        )
        await sut.presentShare(response: response)
        XCTAssertEqual(spy.lastShareVM?.token, "abc-def-123")
    }

    func test_presentShare_copyMessageContainsToken() async {
        let (sut, spy) = makeSUT()
        let response = SpeechGrowthDiaryModels.Share.Response(
            clipId: "clip-1",
            token: "tok-abc-def",
            expiresAt: Date(timeIntervalSinceNow: 7200)
        )
        await sut.presentShare(response: response)
        let copyMsg = spy.lastShareVM?.copyMessage ?? ""
        XCTAssertFalse(copyMsg.isEmpty)
        XCTAssertTrue(copyMsg.contains("Токен скопирован"))
    }

    func test_presentShare_expiresAtLabelIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        let response = SpeechGrowthDiaryModels.Share.Response(
            clipId: "clip-1",
            token: "tok",
            expiresAt: Date(timeIntervalSince1970: 1_716_480_000)
        )
        await sut.presentShare(response: response)
        XCTAssertFalse(spy.lastShareVM?.expiresAtLabel.isEmpty ?? true)
    }
}
