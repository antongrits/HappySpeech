@testable import HappySpeech
import XCTest

// MARK: - Stub Audio Worker

@MainActor
private final class StubPhonemeAudioWorker: PhonemeAudioWorkerProtocol {
    var playResult: (Bool, Bool) = (true, false)
    private(set) var playCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var lastPlayedEntry: PhonemeEntry?

    func playSample(for entry: PhonemeEntry) async -> (Bool, Bool) {
        playCallCount += 1
        lastPlayedEntry = entry
        return playResult
    }
    func stop() {
        stopCallCount += 1
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpySoundDictionaryPresenter: SoundDictionaryPresentationLogic, @unchecked Sendable {
    var loadCallCount = 0
    var selectCallCount = 0
    var playCallCount = 0
    var practiceCallCount = 0

    var lastLoad: SoundDictionaryModels.Load.Response?
    var lastSelect: SoundDictionaryModels.SelectPhoneme.Response?
    var lastPlay: SoundDictionaryModels.PlayAudio.Response?
    var lastPractice: SoundDictionaryModels.PracticePhoneme.Response?

    func presentLoad(response: SoundDictionaryModels.Load.Response) async {
        loadCallCount += 1
        lastLoad = response
    }
    func presentSelectPhoneme(response: SoundDictionaryModels.SelectPhoneme.Response) async {
        selectCallCount += 1
        lastSelect = response
    }
    func presentPlayAudio(response: SoundDictionaryModels.PlayAudio.Response) async {
        playCallCount += 1
        lastPlay = response
    }
    func presentPracticePhoneme(response: SoundDictionaryModels.PracticePhoneme.Response) async {
        practiceCallCount += 1
        lastPractice = response
    }
}

// MARK: - Tests

@MainActor
final class SoundDictionaryInteractorTests: XCTestCase {

    private func makeSUT() -> (SoundDictionaryInteractor, SpySoundDictionaryPresenter, StubPhonemeAudioWorker, SpyHapticService) {
        let worker = StubPhonemeAudioWorker()
        let haptic = SpyHapticService()
        let sut = SoundDictionaryInteractor(audioWorker: worker, hapticService: haptic)
        let spy = SpySoundDictionaryPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    /// Любой валидный id фонемы из корпуса.
    private var validPhonemeId: String { PhonemeCorpus.all.first?.id ?? "vow-a" }

    // MARK: - load

    func test_load_emitsFullCorpus() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init())
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertEqual(spy.lastLoad?.entries.count, PhonemeCorpus.all.count)
        XCTAssertFalse(spy.lastLoad?.entries.isEmpty ?? true)
    }

    // MARK: - selectPhoneme

    func test_selectPhoneme_validId_emitsAndStores() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.selectPhoneme(request: .init(phonemeId: validPhonemeId))
        XCTAssertEqual(spy.selectCallCount, 1)
        XCTAssertEqual(sut.selectedPhoneme?.id, validPhonemeId)
        XCTAssertGreaterThanOrEqual(haptic.selectionCount, 1)
    }

    func test_selectPhoneme_unknownId_ignored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.selectPhoneme(request: .init(phonemeId: "nonexistent"))
        XCTAssertEqual(spy.selectCallCount, 0)
        XCTAssertNil(sut.selectedPhoneme)
    }

    func test_selectPhoneme_hasAudioFlagMatchesEntry() async {
        let (sut, spy, _, _) = makeSUT()
        let entry = PhonemeCorpus.all.first!
        await sut.selectPhoneme(request: .init(phonemeId: entry.id))
        XCTAssertEqual(spy.lastSelect?.hasAudio, entry.audioResourceName != nil)
    }

    // MARK: - playAudio

    func test_playAudio_validId_emitsResponse() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.playResult = (true, false)
        await sut.playAudio(request: .init(phonemeId: validPhonemeId))
        XCTAssertEqual(spy.playCallCount, 1)
        XCTAssertTrue(spy.lastPlay?.success ?? false)
        XCTAssertFalse(spy.lastPlay?.usedFallbackTTS ?? true)
        XCTAssertEqual(worker.playCallCount, 1)
    }

    func test_playAudio_unknownId_ignored() async {
        let (sut, spy, worker, _) = makeSUT()
        await sut.playAudio(request: .init(phonemeId: "missing"))
        XCTAssertEqual(spy.playCallCount, 0)
        XCTAssertEqual(worker.playCallCount, 0)
    }

    func test_playAudio_fallbackTTSPropagated() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.playResult = (true, true)
        await sut.playAudio(request: .init(phonemeId: validPhonemeId))
        XCTAssertTrue(spy.lastPlay?.usedFallbackTTS ?? false)
    }

    func test_playAudio_failure_propagatesFalse() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.playResult = (false, false)
        await sut.playAudio(request: .init(phonemeId: validPhonemeId))
        XCTAssertFalse(spy.lastPlay?.success ?? true)
    }

    // MARK: - practicePhoneme

    func test_practicePhoneme_emitsResponseWithHaptic() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.practicePhoneme(request: .init(phonemeId: validPhonemeId))
        XCTAssertEqual(spy.practiceCallCount, 1)
        XCTAssertEqual(spy.lastPractice?.phonemeId, validPhonemeId)
        XCTAssertGreaterThanOrEqual(haptic.impactCount, 1)
    }

    func test_practicePhoneme_unknownId_stillEmits() async {
        // practicePhoneme не валидирует id — просто передаёт дальше
        let (sut, spy, _, _) = makeSUT()
        await sut.practicePhoneme(request: .init(phonemeId: "any-id"))
        XCTAssertEqual(spy.practiceCallCount, 1)
        XCTAssertEqual(spy.lastPractice?.phonemeId, "any-id")
    }

    // MARK: - PhonemeCorpus pure helpers

    func test_corpus_entryLookup() {
        XCTAssertNotNil(PhonemeCorpus.entry(forId: validPhonemeId))
        XCTAssertNil(PhonemeCorpus.entry(forId: "missing"))
    }

    func test_corpus_entriesByGroup() {
        let vowels = PhonemeCorpus.entries(in: .vowels)
        XCTAssertFalse(vowels.isEmpty)
        XCTAssertTrue(vowels.allSatisfy { $0.group == .vowels })
    }

    func test_corpus_allEntriesHaveUniqueIds() {
        let ids = PhonemeCorpus.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_phonemeGroup_titleKeysNotEmpty() {
        for group in PhonemeGroup.allCases {
            XCTAssertFalse(group.titleKey.isEmpty)
            XCTAssertFalse(group.symbolName.isEmpty)
        }
    }
}
