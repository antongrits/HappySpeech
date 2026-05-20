@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubVoiceWorker: ParentVoiceNoteWorkerProtocol {

    var clips: [ParentVoiceClipData] = []
    var shouldFailSave = false
    var shouldFailDelete = false
    private(set) var saveCount = 0
    private(set) var deleteCount = 0
    private(set) var setEnabledCount = 0
    private(set) var playCount = 0
    private(set) var stopCount = 0
    private(set) var lastEnabledValue: Bool?

    func fetchClips(childId: String) async -> [ParentVoiceClipData] {
        clips.filter { $0.childId == childId }
    }

    func activeClip(childId: String, lessonTemplate: String) async -> ParentVoiceClipData? {
        clips.first { $0.childId == childId && $0.lessonTemplate == lessonTemplate && $0.isEnabled }
    }

    func saveClip(
        childId: String,
        lessonTemplate: String,
        tempFileURL: URL,
        durationSec: Double
    ) async -> ParentVoiceClipData? {
        saveCount += 1
        guard !shouldFailSave else { return nil }
        // удалить старый
        clips.removeAll { $0.childId == childId && $0.lessonTemplate == lessonTemplate }
        let new = ParentVoiceClipData(
            id: UUID().uuidString,
            childId: childId,
            lessonTemplate: lessonTemplate,
            fileURL: "ParentVoiceNotes/\(tempFileURL.lastPathComponent)",
            durationSec: durationSec,
            recordedAt: Date(),
            isEnabled: true
        )
        clips.append(new)
        return new
    }

    func deleteClip(_ data: ParentVoiceClipData) async -> Bool {
        deleteCount += 1
        if shouldFailDelete { return false }
        let countBefore = clips.count
        clips.removeAll { $0.id == data.id }
        return clips.count < countBefore
    }

    func setEnabledForChild(_ childId: String, isEnabled: Bool) async {
        setEnabledCount += 1
        lastEnabledValue = isEnabled
        for index in clips.indices where clips[index].childId == childId {
            clips[index] = ParentVoiceClipData(
                id: clips[index].id,
                childId: clips[index].childId,
                lessonTemplate: clips[index].lessonTemplate,
                fileURL: clips[index].fileURL,
                durationSec: clips[index].durationSec,
                recordedAt: clips[index].recordedAt,
                isEnabled: isEnabled
            )
        }
    }

    func play(_ data: ParentVoiceClipData) async {
        playCount += 1
    }

    func stopPlayback() {
        stopCount += 1
    }
}

// MARK: - Stub OptIn

@MainActor
private final class StubOptIn: ParentVoiceNoteOptInServiceProtocol {
    var storage: [String: Bool] = [:]
    func isEnabled(childId: String) -> Bool { storage[childId] ?? true }
    func setEnabled(childId: String, isEnabled: Bool) { storage[childId] = isEnabled }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyVoicePresenter:
    ParentVoiceNotePresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var saveCount = 0
    var deleteCount = 0
    var toggleCount = 0
    var errorCount = 0
    var lastLoad: ParentVoiceNoteModels.Load.Response?
    var lastSaved: ParentVoiceClipData?
    var lastDeletedId: String?
    var lastToggleValue: Bool?
    var lastError: String?

    func presentLoad(response: ParentVoiceNoteModels.Load.Response) async {
        loadCount += 1
        lastLoad = response
    }
    func presentSave(savedClip: ParentVoiceClipData) async {
        saveCount += 1
        lastSaved = savedClip
    }
    func presentDelete(deletedId: String) async {
        deleteCount += 1
        lastDeletedId = deletedId
    }
    func presentToggle(isEnabled: Bool) async {
        toggleCount += 1
        lastToggleValue = isEnabled
    }
    func presentError(message: String) async {
        errorCount += 1
        lastError = message
    }
}

// MARK: - Interactor Tests

@MainActor
final class ParentVoiceNoteInteractorTests: XCTestCase {

    private func makeSUT() -> (
        ParentVoiceNoteInteractor,
        SpyVoicePresenter,
        StubVoiceWorker,
        StubOptIn
    ) {
        let worker = StubVoiceWorker()
        let optIn = StubOptIn()
        let interactor = ParentVoiceNoteInteractor(
            childId: "child-1",
            worker: worker,
            optInService: optIn
        )
        let spy = SpyVoicePresenter()
        interactor.presenter = spy
        return (interactor, spy, worker, optIn)
    }

    func test_load_buildsResponseWithCanonicalTemplates() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.lastLoad?.templates.count, LessonTemplateOption.canonical.count)
        XCTAssertEqual(spy.lastLoad?.existingClips.count, 0)
    }

    func test_load_isEnabledTrue_byDefault() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.lastLoad?.isEnabledGlobally, true)
    }

    func test_saveClip_persistsAndUpdatesPresenter() async {
        let (sut, spy, worker, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        let tempURL = URL(fileURLWithPath: "/tmp/test.m4a")
        await sut.saveClip(request: .init(
            childId: "child-1",
            lessonTemplate: "bingo",
            fileURL: tempURL,
            durationSec: 10.0
        ))
        XCTAssertEqual(spy.saveCount, 1)
        XCTAssertEqual(worker.saveCount, 1)
        XCTAssertEqual(worker.clips.count, 1)
        XCTAssertEqual(sut.clips.first?.lessonTemplate, "bingo")
    }

    func test_saveClip_fail_emitsError() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.shouldFailSave = true
        await sut.load(request: .init(childId: "child-1"))
        let tempURL = URL(fileURLWithPath: "/tmp/test.m4a")
        await sut.saveClip(request: .init(
            childId: "child-1",
            lessonTemplate: "bingo",
            fileURL: tempURL,
            durationSec: 5.0
        ))
        XCTAssertEqual(spy.errorCount, 1)
        XCTAssertEqual(spy.saveCount, 0)
    }

    func test_saveClip_replacesExistingForTemplate() async {
        let (sut, _, worker, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        let url1 = URL(fileURLWithPath: "/tmp/first.m4a")
        let url2 = URL(fileURLWithPath: "/tmp/second.m4a")
        await sut.saveClip(request: .init(childId: "child-1", lessonTemplate: "bingo", fileURL: url1, durationSec: 5))
        await sut.saveClip(request: .init(childId: "child-1", lessonTemplate: "bingo", fileURL: url2, durationSec: 7))
        XCTAssertEqual(worker.clips.filter { $0.lessonTemplate == "bingo" }.count, 1)
    }

    func test_deleteClip_removesFromList() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        let tempURL = URL(fileURLWithPath: "/tmp/test.m4a")
        await sut.saveClip(request: .init(
            childId: "child-1",
            lessonTemplate: "bingo",
            fileURL: tempURL,
            durationSec: 5
        ))
        guard let clipId = sut.clips.first?.id else { XCTFail("no clip"); return }
        await sut.deleteClip(request: .init(clipId: clipId))
        XCTAssertEqual(spy.deleteCount, 1)
        XCTAssertEqual(spy.lastDeletedId, clipId)
        XCTAssertTrue(sut.clips.isEmpty)
    }

    func test_deleteClip_failingWorker_emitsError() async {
        let (sut, spy, worker, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        let tempURL = URL(fileURLWithPath: "/tmp/test.m4a")
        await sut.saveClip(request: .init(
            childId: "child-1",
            lessonTemplate: "memory",
            fileURL: tempURL,
            durationSec: 5
        ))
        worker.shouldFailDelete = true
        let clipId = sut.clips.first?.id ?? ""
        await sut.deleteClip(request: .init(clipId: clipId))
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_toggleEnabled_propagatesToOptInAndWorker() async {
        let (sut, spy, worker, optIn) = makeSUT()
        await sut.toggleEnabled(request: .init(childId: "child-1", isEnabled: false))
        XCTAssertEqual(spy.toggleCount, 1)
        XCTAssertEqual(spy.lastToggleValue, false)
        XCTAssertEqual(worker.setEnabledCount, 1)
        XCTAssertEqual(optIn.storage["child-1"], false)
    }

    func test_toggleEnabled_canBeFlippedBack() async {
        let (sut, _, _, optIn) = makeSUT()
        await sut.toggleEnabled(request: .init(childId: "child-1", isEnabled: false))
        await sut.toggleEnabled(request: .init(childId: "child-1", isEnabled: true))
        XCTAssertEqual(optIn.storage["child-1"], true)
    }

    func test_deleteClip_unknownId_isNoop() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        await sut.deleteClip(request: .init(clipId: "unknown"))
        XCTAssertEqual(spy.deleteCount, 0)
        XCTAssertEqual(spy.errorCount, 0)
    }
}

// MARK: - Models Tests

@MainActor
final class ParentVoiceNoteCanonicalTemplatesTests: XCTestCase {

    func test_canonicalTemplates_has16Entries() {
        XCTAssertEqual(LessonTemplateOption.canonical.count, 16)
    }

    func test_canonicalTemplates_idsAreUnique() {
        let ids = LessonTemplateOption.canonical.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
