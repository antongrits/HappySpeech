@testable import HappySpeech
import XCTest

// MARK: - SpeechGrowthDiaryInteractorTests
//
// Full VIP with real workers: RealmActor (on-disk default), DiaryEncryptionWorker
// (CryptoKit AES-GCM, key in Keychain), DiaryStorage (Documents/<folder>/).
//
// We exercise the real encrypt → store → persist → list → decrypt → delete
// pipeline. To isolate from other tests and from the device's real diary state:
//   - childId is a fresh UUID per test (Realm rows + crypto key are namespaced
//     by childId, so tests don't see each other's clips);
//   - DiaryStorage uses a per-test temp folder;
//   - DiaryEncryptionWorker uses a per-test keychain service name.
//
// Microphone / camera capture is out of scope; we feed raw bytes via
// saveClipFromData (the production helper intended exactly for this).

@MainActor
final class SpeechGrowthDiaryInteractorTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SpeechGrowthDiaryDisplayLogic {
        var lastListVM: SpeechGrowthDiaryModels.List.ViewModel?
        var lastShareVM: SpeechGrowthDiaryModels.Share.ViewModel?
        var listCount = 0

        func displayList(viewModel: SpeechGrowthDiaryModels.List.ViewModel) async {
            listCount += 1
            lastListVM = viewModel
        }

        func displayShare(viewModel: SpeechGrowthDiaryModels.Share.ViewModel) async {
            lastShareVM = viewModel
        }
    }

    private var childId: String!
    private var serviceName: String!
    private var folderName: String!

    override func setUp() async throws {
        try await super.setUp()
        let unique = UUID().uuidString
        childId = "child-\(unique)"
        serviceName = "ru.happyspeech.diary.test.\(unique)"
        folderName = "DiaryTest-\(unique)"
    }

    private func makeSUT() -> (SpeechGrowthDiaryInteractor, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = SpeechGrowthDiaryPresenter(displayLogic: spy)
        let encryption = DiaryEncryptionWorker(serviceName: serviceName)
        let storage = DiaryStorage(folderName: folderName)
        let sut = SpeechGrowthDiaryInteractor(
            presenter: presenter,
            realmActor: RealmActor(),
            childId: childId,
            encryption: encryption,
            storage: storage
        )
        return (sut, spy)
    }

    private func makeBytes(_ string: String) -> Data { Data(string.utf8) }

    /// Saves a clip and unwraps the result. `XCTUnwrap` cannot take an async
    /// autoclosure, so we await first, then unwrap the materialised value.
    private func saveAndUnwrap(
        _ sut: SpeechGrowthDiaryInteractor,
        bytes: Data,
        thumbnail: Data? = nil,
        durationSeconds: Double = 3,
        topicTag: String = "t",
        targetSound: String = "С",
        note: String = ""
    ) async throws -> EncryptedVideoClipData {
        let saved = await sut.saveClipFromData(
            clipBytes: bytes, thumbnailBytes: thumbnail,
            durationSeconds: durationSeconds, topicTag: topicTag,
            targetSound: targetSound, note: note
        )
        return try XCTUnwrap(saved)
    }

    // MARK: - loadClips (empty)

    func test_loadClips_emptyForFreshChild() async {
        let (sut, spy) = makeSUT()
        await sut.loadClips()
        XCTAssertEqual(spy.lastListVM?.clips.count, 0)
        XCTAssertTrue(spy.lastListVM?.isEmpty ?? false)
    }

    // MARK: - saveClipFromData

    func test_saveClip_returnsClipDataWithMetadata() async {
        let (sut, _) = makeSUT()
        let saved = await sut.saveClipFromData(
            clipBytes: makeBytes("hello-video"),
            thumbnailBytes: nil,
            durationSeconds: 12.0,
            topicTag: "артикуляция",
            targetSound: "Р",
            note: "первая попытка"
        )
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.targetSound, "Р")
        XCTAssertEqual(saved?.topicTag, "артикуляция")
        XCTAssertEqual(saved?.durationSeconds, 12.0)
        XCTAssertEqual(saved?.childId, childId)
        XCTAssertFalse(saved?.encryptedClipPath.isEmpty ?? true)
    }

    func test_saveClip_refreshesListWithOneClip() async {
        let (sut, spy) = makeSUT()
        await sut.saveClipFromData(
            clipBytes: makeBytes("v1"), thumbnailBytes: nil,
            durationSeconds: 5, topicTag: "t", targetSound: "С", note: ""
        )
        XCTAssertEqual(spy.lastListVM?.clips.count, 1)
    }

    func test_saveClip_withThumbnail_setsThumbnailPath() async {
        let (sut, _) = makeSUT()
        let saved = await sut.saveClipFromData(
            clipBytes: makeBytes("v"), thumbnailBytes: makeBytes("thumb"),
            durationSeconds: 5, topicTag: "t", targetSound: "С", note: ""
        )
        XCTAssertFalse(saved?.encryptedThumbnailPath.isEmpty ?? true)
    }

    func test_saveTwoClips_listHasTwo() async {
        let (sut, spy) = makeSUT()
        await sut.saveClipFromData(
            clipBytes: makeBytes("a"), thumbnailBytes: nil,
            durationSeconds: 1, topicTag: "t", targetSound: "С", note: ""
        )
        await sut.saveClipFromData(
            clipBytes: makeBytes("b"), thumbnailBytes: nil,
            durationSeconds: 2, topicTag: "t", targetSound: "З", note: ""
        )
        XCTAssertEqual(spy.lastListVM?.clips.count, 2)
    }

    // MARK: - decryptClip (round-trip)

    func test_saveThenDecrypt_returnsOriginalBytes() async throws {
        let (sut, _) = makeSUT()
        let original = makeBytes("the-original-clip-bytes")
        let saved = try await saveAndUnwrap(sut, bytes: original, durationSeconds: 8, targetSound: "Р")
        let decrypted = try await sut.decryptClip(id: saved.id)
        XCTAssertEqual(decrypted, original)
    }

    // MARK: - deleteClip

    func test_deleteClip_removesFromList() async throws {
        let (sut, spy) = makeSUT()
        let saved = try await saveAndUnwrap(sut, bytes: makeBytes("x"))
        await sut.deleteClip(id: saved.id)
        XCTAssertEqual(spy.lastListVM?.clips.count, 0)
    }

    func test_deleteClip_decryptAfterwardThrows() async throws {
        let (sut, _) = makeSUT()
        let saved = try await saveAndUnwrap(sut, bytes: makeBytes("x"))
        await sut.deleteClip(id: saved.id)
        do {
            _ = try await sut.decryptClip(id: saved.id)
            XCTFail("Expected decrypt to throw after file deletion")
        } catch {
            // Expected — encrypted file is gone.
        }
    }

    // MARK: - share token

    func test_issueShareToken_returnsTokenAndPresentsShare() async throws {
        let (sut, spy) = makeSUT()
        let saved = try await saveAndUnwrap(sut, bytes: makeBytes("x"))
        let result = await sut.issueShareToken(clipId: saved.id, durationHours: 24)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.token.isEmpty ?? true)
        XCTAssertEqual(result?.clipId, saved.id)
        XCTAssertNotNil(spy.lastShareVM)
    }

    func test_issueShareToken_marksClipShared() async throws {
        let (sut, spy) = makeSUT()
        let saved = try await saveAndUnwrap(sut, bytes: makeBytes("x"))
        _ = await sut.issueShareToken(clipId: saved.id, durationHours: 24)
        XCTAssertEqual(spy.lastListVM?.clips.first?.isShared, true)
    }

    func test_issueShareToken_expiresInFuture() async throws {
        let (sut, _) = makeSUT()
        let saved = try await saveAndUnwrap(sut, bytes: makeBytes("x"))
        let result = await sut.issueShareToken(clipId: saved.id, durationHours: 1)
        let expires = try XCTUnwrap(result?.expiresAt)
        XCTAssertGreaterThan(expires, Date())
    }

    func test_revokeShareToken_clearsSharedFlag() async throws {
        let (sut, spy) = makeSUT()
        let saved = try await saveAndUnwrap(sut, bytes: makeBytes("x"))
        _ = await sut.issueShareToken(clipId: saved.id, durationHours: 24)
        await sut.revokeShareToken(clipId: saved.id)
        XCTAssertEqual(spy.lastListVM?.clips.first?.isShared, false)
    }
}
