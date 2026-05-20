@testable import HappySpeech
import XCTest

// MARK: - Spy

@MainActor
private final class SpyDescriptionMapDisplay: ObjectDescriptionMapDisplayLogic, @unchecked Sendable {

    var loadVM: ObjectDescriptionMapModels.LoadObjects.ViewModel?
    var selectVM: ObjectDescriptionMapModels.SelectObject.ViewModel?
    var resultVM: ObjectDescriptionMapModels.RecordResult.ViewModel?

    func displayLoadObjects(viewModel: ObjectDescriptionMapModels.LoadObjects.ViewModel) async {
        loadVM = viewModel
    }
    func displaySelectObject(viewModel: ObjectDescriptionMapModels.SelectObject.ViewModel) async {
        selectVM = viewModel
    }
    func displayRecordResult(viewModel: ObjectDescriptionMapModels.RecordResult.ViewModel) async {
        resultVM = viewModel
    }
}

// MARK: - Corpus tests

final class ObjectDescriptionMapCorpusTests: XCTestCase {

    func test_corpus_has_objects() {
        XCTAssertGreaterThanOrEqual(ObjectDescriptionMapCorpus.objects.count, 2)
    }

    func test_corpus_categories_have_objects() {
        let grouped = ObjectDescriptionMapCorpus.grouped()
        for entry in grouped {
            XCTAssertFalse(entry.items.isEmpty, "Категория \(entry.category) пуста")
        }
    }

    func test_every_object_has_plan_with_six_to_eight_items() {
        for object in ObjectDescriptionMapCorpus.objects {
            XCTAssertGreaterThanOrEqual(object.plan.count, 6,
                                        "У объекта \(object.id) меньше 6 пунктов плана")
            XCTAssertLessThanOrEqual(object.plan.count, 8,
                                     "У объекта \(object.id) больше 8 пунктов плана")
        }
    }

    func test_every_plan_item_has_keywords() {
        for object in ObjectDescriptionMapCorpus.objects {
            for item in object.plan {
                XCTAssertGreaterThanOrEqual(item.keywords.count, 3,
                                            "У \(object.id)/\(item.slot) < 3 keywords")
            }
        }
    }
}

// MARK: - DescriptionCoverageAnalyzer tests

final class DescriptionCoverageAnalyzerTests: XCTestCase {

    private let analyzer = DescriptionCoverageAnalyzer()

    private func makePlan() -> [DescriptionPlanItem] {
        [
            DescriptionPlanItem(
                slot: "color", slotTitle: "Цвет", icon: "paintpalette.fill",
                prompt: "Какого цвета?",
                keywords: ["рыжий", "серый", "белый"]
            ),
            DescriptionPlanItem(
                slot: "size", slotTitle: "Размер", icon: "ruler.fill",
                prompt: "Какого размера?",
                keywords: ["маленький", "большой"]
            ),
            DescriptionPlanItem(
                slot: "parts", slotTitle: "Части", icon: "puzzlepiece.fill",
                prompt: "Какие части?",
                keywords: ["лапы", "хвост", "усы"]
            ),
            DescriptionPlanItem(
                slot: "sound", slotTitle: "Звук", icon: "speaker.wave.2.fill",
                prompt: "Как звучит?",
                keywords: ["мяу", "мурчит"]
            )
        ]
    }

    func test_empty_transcript_yields_zero_coverage() {
        let report = analyzer.analyse(transcript: "", plan: makePlan())
        XCTAssertEqual(report.coveredCount, 0)
        XCTAssertEqual(report.totalCount, 4)
        XCTAssertEqual(report.coverageRatio, 0, accuracy: 0.001)
        XCTAssertEqual(report.totalWords, 0)
    }

    func test_full_coverage_marks_all_items() {
        let transcript = "Кот рыжий и большой, у него лапы и хвост, говорит мяу."
        let report = analyzer.analyse(transcript: transcript, plan: makePlan())
        XCTAssertEqual(report.coveredCount, 4)
        XCTAssertTrue(report.decorated.allSatisfy(\.isCovered))
    }

    func test_partial_coverage_lists_missed_titles() {
        let transcript = "Кот серый и маленький."
        let report = analyzer.analyse(transcript: transcript, plan: makePlan())
        XCTAssertEqual(report.coveredCount, 2)
        XCTAssertEqual(report.missedTitles.sorted(), ["Звук", "Части"])
    }

    func test_punctuation_is_stripped_during_match() {
        let transcript = "Рыжий!!! Большой... Лапы, хвост — мяу?"
        let report = analyzer.analyse(transcript: transcript, plan: makePlan())
        XCTAssertEqual(report.coveredCount, 4)
    }

    func test_yo_letter_is_normalised() {
        let plan = [
            DescriptionPlanItem(
                slot: "color", slotTitle: "Цвет", icon: "paintpalette.fill",
                prompt: "Какого цвета?",
                keywords: ["жёлтый"]
            )
        ]
        let report = analyzer.analyse(transcript: "Это желтый шар.", plan: plan)
        XCTAssertEqual(report.coveredCount, 1)
    }

    func test_word_endings_are_tolerated_via_stem_match() {
        // «рыжего» ⊃ stem(«рыжий») → должен матчиться.
        let transcript = "У кота нет рыжего цвета."
        let plan = [
            DescriptionPlanItem(
                slot: "color", slotTitle: "Цвет", icon: "paintpalette.fill",
                prompt: "Какого цвета?",
                keywords: ["рыжий"]
            )
        ]
        let report = analyzer.analyse(transcript: transcript, plan: plan)
        XCTAssertEqual(report.coveredCount, 1)
    }

    func test_multi_word_keyword_substring_match() {
        let transcript = "Он живёт в норе на дереве."
        let plan = [
            DescriptionPlanItem(
                slot: "habitat", slotTitle: "Где живёт", icon: "house.fill",
                prompt: "Где живёт?",
                keywords: ["на дереве"]
            )
        ]
        let report = analyzer.analyse(transcript: transcript, plan: plan)
        XCTAssertEqual(report.coveredCount, 1)
    }

    func test_lexical_diversity_is_calculated() {
        let report = analyzer.analyse(
            transcript: "кот кот кот рыжий",
            plan: makePlan()
        )
        XCTAssertEqual(report.totalWords, 4)
        XCTAssertEqual(report.lexicalDiversity, 0.5, accuracy: 0.01)
    }

    func test_average_sentence_length_counts_separators() {
        let report = analyzer.analyse(
            transcript: "Кот рыжий. У него лапы.",
            plan: makePlan()
        )
        XCTAssertEqual(report.totalWords, 5)
        XCTAssertEqual(report.avgSentenceLengthWords, 2.5, accuracy: 0.01)
    }

    // MARK: - Stars

    func test_stars_thresholds() {
        XCTAssertEqual(analyzer.stars(forRatio: 0.0), 0)
        XCTAssertEqual(analyzer.stars(forRatio: 0.10), 0)
        XCTAssertEqual(analyzer.stars(forRatio: 0.25), 1)
        XCTAssertEqual(analyzer.stars(forRatio: 0.49), 1)
        XCTAssertEqual(analyzer.stars(forRatio: 0.50), 2)
        XCTAssertEqual(analyzer.stars(forRatio: 0.79), 2)
        XCTAssertEqual(analyzer.stars(forRatio: 0.80), 3)
        XCTAssertEqual(analyzer.stars(forRatio: 1.00), 3)
    }
}

// MARK: - Presenter tests

@MainActor
final class ObjectDescriptionMapPresenterTests: XCTestCase {

    private func makeSUT() -> (ObjectDescriptionMapPresenter, SpyDescriptionMapDisplay) {
        let display = SpyDescriptionMapDisplay()
        let presenter = ObjectDescriptionMapPresenter(displayLogic: display)
        return (presenter, display)
    }

    func test_presentLoadObjects_groups_by_category() async {
        let (presenter, display) = makeSUT()
        let objects = ObjectDescriptionMapCorpus.objects
        await presenter.presentLoadObjects(response: .init(objects: objects))
        XCTAssertNotNil(display.loadVM)
        XCTAssertEqual(
            display.loadVM?.categoriesInOrder,
            ObjectDescriptionMapCorpus.categoriesInOrder
        )
        for category in display.loadVM?.categoriesInOrder ?? [] {
            XCTAssertFalse(display.loadVM?.grouped[category]?.isEmpty ?? true)
        }
    }

    func test_presentSelectObject_attaches_plan_and_hint() async {
        guard let firstObject = ObjectDescriptionMapCorpus.objects.first else {
            return XCTFail("Empty corpus")
        }
        let (presenter, display) = makeSUT()
        await presenter.presentSelectObject(response: .init(objectId: firstObject.id))
        XCTAssertEqual(display.selectVM?.object.id, firstObject.id)
        XCTAssertFalse(display.selectVM?.planItems.isEmpty ?? true)
        XCTAssertFalse(display.selectVM?.hintMessage.isEmpty ?? true)
    }

    func test_presentRecordResult_calculates_stars_and_feedback() async {
        guard let object = ObjectDescriptionMapCorpus.objects.first else {
            return XCTFail("Empty corpus")
        }
        let analyzer = DescriptionCoverageAnalyzer()
        // Соберём искусственный "идеальный" транскрипт из первых keywords каждого пункта.
        let transcript = object.plan.compactMap { $0.keywords.first }.joined(separator: " ")
        let coverage = analyzer.analyse(transcript: transcript, plan: object.plan)
        XCTAssertEqual(coverage.coveredCount, object.plan.count,
                       "Идеальный транскрипт должен закрыть весь план")

        let (presenter, display) = makeSUT()
        await presenter.presentRecordResult(response: .init(
            object: object,
            transcript: transcript,
            durationSeconds: 30,
            coverage: coverage
        ))
        XCTAssertEqual(display.resultVM?.stars, 3)
        XCTAssertEqual(display.resultVM?.coveragePercent, 100)
        XCTAssertFalse(display.resultVM?.feedbackTitle.isEmpty ?? true)
        XCTAssertTrue(display.resultVM?.missedTitles.isEmpty ?? false)
    }

    func test_presentRecordResult_partial_coverage_gives_one_or_two_stars() async {
        guard let object = ObjectDescriptionMapCorpus.objects.first else {
            return XCTFail("Empty corpus")
        }
        let halfPlan = Array(object.plan.prefix(object.plan.count / 2))
        let halfTranscript = halfPlan.compactMap { $0.keywords.first }.joined(separator: " ")
        let coverage = DescriptionCoverageAnalyzer().analyse(transcript: halfTranscript, plan: object.plan)

        let (presenter, display) = makeSUT()
        await presenter.presentRecordResult(response: .init(
            object: object,
            transcript: halfTranscript,
            durationSeconds: 20,
            coverage: coverage
        ))
        let stars = display.resultVM?.stars ?? -1
        XCTAssertTrue(stars >= 1 && stars <= 2,
                      "Половина покрытия должна дать 1 или 2 звезды, а не \(stars)")
    }

    func test_presentRecordResult_empty_transcript_gives_zero_stars() async {
        guard let object = ObjectDescriptionMapCorpus.objects.first else {
            return XCTFail("Empty corpus")
        }
        let coverage = DescriptionCoverageAnalyzer().analyse(transcript: "", plan: object.plan)
        let (presenter, display) = makeSUT()
        await presenter.presentRecordResult(response: .init(
            object: object,
            transcript: "",
            durationSeconds: 0,
            coverage: coverage
        ))
        XCTAssertEqual(display.resultVM?.stars, 0)
        XCTAssertEqual(display.resultVM?.coveragePercent, 0)
    }
}

// MARK: - Interactor tests

@MainActor
final class ObjectDescriptionMapInteractorTests: XCTestCase {

    private func makeSUT() -> (ObjectDescriptionMapInteractor, SpyDescriptionMapDisplay) {
        let container = AppContainer.preview()
        let display = SpyDescriptionMapDisplay()
        let presenter = ObjectDescriptionMapPresenter(displayLogic: display)
        let interactor = ObjectDescriptionMapInteractor(
            presenter: presenter,
            audioService: container.audioService,
            asrService: container.asrService
        )
        return (interactor, display)
    }

    func test_loadObjects_presentsViewModel() async {
        let (sut, display) = makeSUT()
        await sut.loadObjects()
        XCTAssertNotNil(display.loadVM)
        XCTAssertFalse(display.loadVM?.categoriesInOrder.isEmpty ?? true)
    }

    func test_selectObject_setsSelectionAndPresentsPlan() async {
        guard let firstObject = ObjectDescriptionMapCorpus.objects.first else {
            return XCTFail("Empty corpus")
        }
        let (sut, display) = makeSUT()
        await sut.loadObjects()
        await sut.selectObject(id: firstObject.id)
        XCTAssertEqual(sut.selectedObjectId, firstObject.id)
        XCTAssertEqual(display.selectVM?.object.id, firstObject.id)
    }

    func test_selectObject_unknownId_isIgnored() async {
        let (sut, _) = makeSUT()
        await sut.loadObjects()
        await sut.selectObject(id: "no-such-object")
        XCTAssertNil(sut.selectedObjectId)
    }

    func test_clearSelection_resetsState() async {
        guard let firstObject = ObjectDescriptionMapCorpus.objects.first else {
            return XCTFail("Empty corpus")
        }
        let (sut, _) = makeSUT()
        await sut.selectObject(id: firstObject.id)
        sut.clearSelection()
        XCTAssertNil(sut.selectedObjectId)
    }

    func test_processTranscript_withoutSelection_returnsNil() async {
        let (sut, _) = makeSUT()
        let report = await sut.processTranscript("какой-то текст", duration: 10)
        XCTAssertNil(report)
    }

    func test_processTranscript_afterSelection_producesReport() async {
        guard let object = ObjectDescriptionMapCorpus.objects.first else {
            return XCTFail("Empty corpus")
        }
        let transcript = object.plan.compactMap { $0.keywords.first }.joined(separator: " ")
        let (sut, display) = makeSUT()
        await sut.selectObject(id: object.id)
        let report = await sut.processTranscript(transcript, duration: 25)
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.totalCount, object.plan.count)
        XCTAssertEqual(report?.coveredCount, object.plan.count)
        XCTAssertEqual(display.resultVM?.object.id, object.id)
    }
}
