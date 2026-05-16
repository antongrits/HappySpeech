import XCTest
@testable import HappySpeech

// MARK: - SoundDictionaryPresenterTests
//
// Phase 2.6 batch 3 — покрытие SoundDictionaryPresenter (0% → цель ≥90%).

@MainActor
final class SoundDictionaryPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SoundDictionaryDisplayLogic {
        var loadVM: SoundDictionaryModels.Load.ViewModel?
        var selectPhonemeVM: SoundDictionaryModels.SelectPhoneme.ViewModel?
        var playAudioVM: SoundDictionaryModels.PlayAudio.ViewModel?
        var practiceVM: SoundDictionaryModels.PracticePhoneme.ViewModel?

        func displayLoad(viewModel: SoundDictionaryModels.Load.ViewModel) async { loadVM = viewModel }
        func displaySelectPhoneme(viewModel: SoundDictionaryModels.SelectPhoneme.ViewModel) async { selectPhonemeVM = viewModel }
        func displayPlayAudio(viewModel: SoundDictionaryModels.PlayAudio.ViewModel) async { playAudioVM = viewModel }
        func displayPracticePhoneme(viewModel: SoundDictionaryModels.PracticePhoneme.ViewModel) async { practiceVM = viewModel }
    }

    private func makeSUT() -> (SoundDictionaryPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let sut = SoundDictionaryPresenter(displayLogic: spy)
        return (sut, spy)
    }

    private func makeEntry(
        id: String = "wh-s",
        cyrillic: String = "С",
        group: PhonemeGroup = .whistling
    ) -> PhonemeEntry {
        PhonemeEntry(
            id: id,
            cyrillic: cyrillic,
            ipa: "s",
            group: group,
            exampleWord: "солнце",
            exampleSyllable: "са",
            articulationNoteKey: "soundDictionary.phoneme.wh-s.articulation"
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_emptyEntries_sectionsEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(entries: []))
        XCTAssertNotNil(spy.loadVM)
        XCTAssertTrue(spy.loadVM?.sections.isEmpty == true)
        XCTAssertEqual(spy.loadVM?.totalCount, 0)
    }

    func test_presentLoad_singleEntry_oneSectionWithOneCell() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry()
        await sut.presentLoad(response: .init(entries: [entry]))
        XCTAssertEqual(spy.loadVM?.sections.count, 1)
        XCTAssertEqual(spy.loadVM?.sections.first?.cells.count, 1)
        XCTAssertEqual(spy.loadVM?.totalCount, 1)
    }

    func test_presentLoad_cellIpaWrappedInBrackets() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry(id: "wh-s", cyrillic: "С", group: .whistling)
        await sut.presentLoad(response: .init(entries: [entry]))
        let cell = spy.loadVM?.sections.first?.cells.first
        XCTAssertEqual(cell?.ipa, "[s]")
    }

    func test_presentLoad_totalCountLabel_notEmpty() async {
        let (sut, spy) = makeSUT()
        let entries = [makeEntry(id: "e1", group: .vowels), makeEntry(id: "e2", group: .vowels)]
        await sut.presentLoad(response: .init(entries: entries))
        XCTAssertFalse(spy.loadVM?.totalCountLabel.isEmpty ?? true)
    }

    func test_presentLoad_twoGroupsEntries_twoSections() async {
        let (sut, spy) = makeSUT()
        let entries = [
            makeEntry(id: "v1", cyrillic: "А", group: .vowels),
            makeEntry(id: "w1", cyrillic: "С", group: .whistling)
        ]
        await sut.presentLoad(response: .init(entries: entries))
        XCTAssertEqual(spy.loadVM?.sections.count, 2)
    }

    func test_presentLoad_sectionGroupSymbol_notEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(entries: [makeEntry()]))
        XCTAssertFalse(spy.loadVM?.sections.first?.groupSymbol.isEmpty ?? true)
    }

    func test_presentLoad_sectionAccessibilityLabel_notEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(entries: [makeEntry()]))
        XCTAssertFalse(spy.loadVM?.sections.first?.groupAccessibilityLabel.isEmpty ?? true)
    }

    func test_presentLoad_cellAccessibilityLabel_notEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(entries: [makeEntry()]))
        XCTAssertFalse(spy.loadVM?.sections.first?.cells.first?.accessibilityLabel.isEmpty ?? true)
    }

    func test_presentLoad_groupsOrderedByPhonemeGroupAllCases() async {
        let (sut, spy) = makeSUT()
        // Добавляем фонемы из двух групп в перемешанном порядке
        let entries = [
            makeEntry(id: "son-r", cyrillic: "Р", group: .sonants),
            makeEntry(id: "vow-a", cyrillic: "А", group: .vowels)
        ]
        await sut.presentLoad(response: .init(entries: entries))
        let sectionIds = spy.loadVM?.sections.map(\.id) ?? []
        // vowels идёт раньше sonants в PhonemeGroup.allCases
        let vowelsIndex = sectionIds.firstIndex(of: PhonemeGroup.vowels.rawValue)
        let sonantsIndex = sectionIds.firstIndex(of: PhonemeGroup.sonants.rawValue)
        XCTAssertNotNil(vowelsIndex)
        XCTAssertNotNil(sonantsIndex)
        XCTAssertLessThan(vowelsIndex!, sonantsIndex!)
    }

    // MARK: - presentSelectPhoneme

    func test_presentSelectPhoneme_titleIsCyrillic() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry(id: "wh-s", cyrillic: "С")
        await sut.presentSelectPhoneme(response: .init(entry: entry, hasAudio: true))
        XCTAssertEqual(spy.selectPhonemeVM?.title, "С")
        XCTAssertEqual(spy.selectPhonemeVM?.ipaLabel, "[s]")
        XCTAssertTrue(spy.selectPhonemeVM?.hasAudio == true)
    }

    func test_presentSelectPhoneme_noAudio_hasAudioFalse() async {
        let (sut, spy) = makeSUT()
        let entry = makeEntry()
        await sut.presentSelectPhoneme(response: .init(entry: entry, hasAudio: false))
        XCTAssertFalse(spy.selectPhonemeVM?.hasAudio ?? true)
    }

    func test_presentSelectPhoneme_ctaLabels_notEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSelectPhoneme(response: .init(entry: makeEntry(), hasAudio: true))
        XCTAssertFalse(spy.selectPhonemeVM?.practiceCtaLabel.isEmpty ?? true)
        XCTAssertFalse(spy.selectPhonemeVM?.playAudioLabel.isEmpty ?? true)
    }

    func test_presentSelectPhoneme_exampleWordPropagated() async {
        let (sut, spy) = makeSUT()
        await sut.presentSelectPhoneme(response: .init(entry: makeEntry(), hasAudio: false))
        XCTAssertEqual(spy.selectPhonemeVM?.exampleWord, "солнце")
    }

    // MARK: - presentPlayAudio

    func test_presentPlayAudio_success_toastNil() async {
        let (sut, spy) = makeSUT()
        await sut.presentPlayAudio(response: .init(success: true, usedFallbackTTS: false))
        XCTAssertNil(spy.playAudioVM?.toastMessage)
    }

    func test_presentPlayAudio_failure_toastNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentPlayAudio(response: .init(success: false, usedFallbackTTS: false))
        XCTAssertFalse(spy.playAudioVM?.toastMessage?.isEmpty ?? true)
    }

    func test_presentPlayAudio_fallbackTTS_toastNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentPlayAudio(response: .init(success: true, usedFallbackTTS: true))
        XCTAssertFalse(spy.playAudioVM?.toastMessage?.isEmpty ?? true)
    }

    // MARK: - presentPracticePhoneme

    func test_presentPracticePhoneme_phonemeIdPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentPracticePhoneme(response: .init(phonemeId: "wh-s"))
        XCTAssertEqual(spy.practiceVM?.phonemeId, "wh-s")
    }

    func test_presentPracticePhoneme_differentIds_differentValues() async {
        let (sut, spy) = makeSUT()
        for phonemeId in ["vow-a", "son-r", "hs-sh"] {
            await sut.presentPracticePhoneme(response: .init(phonemeId: phonemeId))
            XCTAssertEqual(spy.practiceVM?.phonemeId, phonemeId)
        }
    }
}
