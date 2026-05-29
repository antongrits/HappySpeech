@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubAssessmentWorker: SpecialistAssessmentWorkerProtocol {
    var stubbedQuestions: [SpecialistAssessmentQuestion]
    var stubbedAxes: [SpecialistAssessmentAxis] = []
    private(set) var saveCalls: [(String, String, [SpecialistAssessmentAnswer])] = []

    init(questions: [SpecialistAssessmentQuestion]) {
        self.stubbedQuestions = questions
    }

    var questions: [SpecialistAssessmentQuestion] { stubbedQuestions }

    func saveResult(
        childId: String,
        specialistId: String,
        answers: [SpecialistAssessmentAnswer]
    ) async -> SpecialistAssessmentModels.Submit.Response {
        saveCalls.append((childId, specialistId, answers))
        return .init(recommendedAxes: stubbedAxes, savedResultId: "stub-id")
    }

    func computeRecommendedAxes(
        answers: [SpecialistAssessmentAnswer]
    ) -> [SpecialistAssessmentAxis] {
        stubbedAxes
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyAssessmentPresenter:
    SpecialistAssessmentPresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var submitCount = 0
    var lastLoadResponse: SpecialistAssessmentModels.Load.Response?
    var lastSubmitResponse: SpecialistAssessmentModels.Submit.Response?

    func presentLoad(response: SpecialistAssessmentModels.Load.Response) async {
        loadCount += 1
        lastLoadResponse = response
    }
    func presentSubmit(response: SpecialistAssessmentModels.Submit.Response) async {
        submitCount += 1
        lastSubmitResponse = response
    }
}

// MARK: - Fixtures

private func makeQuestion(
    id: String,
    axis: SpecialistAssessmentAxis = .articulation,
    type: SpecialistAssessmentQuestionType = .yesno
) -> SpecialistAssessmentQuestion {
    SpecialistAssessmentQuestion(
        id: id,
        axis: axis,
        text: "Текст \(id)",
        type: type,
        scale: type == .scale
            ? SpecialistAssessmentScale(min: 1, max: 5, lowLabel: "лоу", highLabel: "хай")
            : nil
    )
}

// MARK: - Tests

@MainActor
final class SpecialistAssessmentInteractorTests: XCTestCase {

    private func makeSUT(
        questions: [SpecialistAssessmentQuestion] = (1...10).map {
            makeQuestion(id: "q\($0)")
        }
    ) -> (SpecialistAssessmentInteractor, SpyAssessmentPresenter, StubAssessmentWorker) {
        let worker = StubAssessmentWorker(questions: questions)
        let interactor = SpecialistAssessmentInteractor(
            childId: "child-1",
            specialistId: "spec-1",
            worker: worker
        )
        let spy = SpyAssessmentPresenter()
        interactor.presenter = spy
        return (interactor, spy, worker)
    }

    func test_load_presentsAllQuestions() async {
        let (sut, spy, _) = makeSUT()
        await sut.load(request: .init(childId: "c", specialistId: "s"))
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.lastLoadResponse?.questions.count, 10)
        XCTAssertEqual(sut.childId, "c")
        XCTAssertEqual(sut.specialistId, "s")
    }

    func test_answer_storesByQuestionId() async {
        let (sut, _, _) = makeSUT()
        await sut.answer(request: .init(
            questionId: "q1",
            axis: .articulation,
            boolValue: true,
            numericValue: nil
        ))
        XCTAssertEqual(sut.answers["q1"]?.boolValue, true)
        XCTAssertNil(sut.answers["q1"]?.numericValue)
    }

    func test_answer_overwritesPreviousAnswer() async {
        let (sut, _, _) = makeSUT()
        await sut.answer(request: .init(
            questionId: "q1", axis: .articulation,
            boolValue: false, numericValue: nil
        ))
        await sut.answer(request: .init(
            questionId: "q1", axis: .articulation,
            boolValue: true, numericValue: nil
        ))
        XCTAssertEqual(sut.answers["q1"]?.boolValue, true)
        XCTAssertEqual(sut.answers.count, 1)
    }

    func test_submit_callsWorkerWithCollectedAnswers() async {
        let (sut, spy, worker) = makeSUT()
        await sut.answer(request: .init(
            questionId: "q1", axis: .articulation,
            boolValue: true, numericValue: nil
        ))
        await sut.answer(request: .init(
            questionId: "q2", axis: .phonology,
            boolValue: false, numericValue: nil
        ))
        await sut.submit(request: .init(childId: "child-1", specialistId: "spec-1"))
        XCTAssertEqual(worker.saveCalls.count, 1)
        XCTAssertEqual(worker.saveCalls.first?.0, "child-1")
        XCTAssertEqual(worker.saveCalls.first?.2.count, 2)
        XCTAssertEqual(spy.submitCount, 1)
    }

    func test_submit_passesRecommendedAxesThrough() async {
        let (sut, spy, worker) = makeSUT()
        worker.stubbedAxes = [.lexical, .grammar]
        await sut.submit(request: .init(childId: "c", specialistId: "s"))
        XCTAssertEqual(spy.lastSubmitResponse?.recommendedAxes, [.lexical, .grammar])
    }
}

// MARK: - Worker Scoring Tests

@MainActor
final class SpecialistAssessmentWorkerTests: XCTestCase {

    func test_weakScore_yesnoNo_returns1() {
        let answer = SpecialistAssessmentAnswer(
            questionId: "q", axis: .articulation, boolValue: false
        )
        XCTAssertEqual(SpecialistAssessmentWorker.weakScore(for: answer), 1.0)
    }

    func test_weakScore_yesnoYes_returnsZero() {
        let answer = SpecialistAssessmentAnswer(
            questionId: "q", axis: .articulation, boolValue: true
        )
        XCTAssertEqual(SpecialistAssessmentWorker.weakScore(for: answer), 0)
    }

    func test_weakScore_scaleLowValue_returns1() {
        let answer = SpecialistAssessmentAnswer(
            questionId: "q", axis: .articulation, numericValue: 1
        )
        XCTAssertEqual(SpecialistAssessmentWorker.weakScore(for: answer), 1.0)
    }

    func test_weakScore_scaleMedium_returnsHalf() {
        let answer = SpecialistAssessmentAnswer(
            questionId: "q", axis: .articulation, numericValue: 3
        )
        XCTAssertEqual(SpecialistAssessmentWorker.weakScore(for: answer), 0.5)
    }

    func test_weakScore_scaleHigh_returnsZero() {
        let answer = SpecialistAssessmentAnswer(
            questionId: "q", axis: .articulation, numericValue: 5
        )
        XCTAssertEqual(SpecialistAssessmentWorker.weakScore(for: answer), 0)
    }

    func test_computeRecommendedAxes_aggregatesWeakAxes() {
        let worker = SpecialistAssessmentWorker(realmActor: nil)
        let answers: [SpecialistAssessmentAnswer] = [
            // articulation: оба слабые → 2.0
            .init(questionId: "a1", axis: .articulation, boolValue: false),
            .init(questionId: "a2", axis: .articulation, numericValue: 2),
            // lexical: один сильный → 0.0
            .init(questionId: "l1", axis: .lexical, boolValue: true),
            // phonology: 0.5
            .init(questionId: "p1", axis: .phonology, numericValue: 3),
            // grammar: 0
            .init(questionId: "g1", axis: .grammar, numericValue: 5)
        ]
        let result = worker.computeRecommendedAxes(answers: answers)
        XCTAssertTrue(result.contains(.articulation))
        XCTAssertFalse(result.contains(.lexical))
        XCTAssertFalse(result.contains(.grammar))
    }

    func test_computeRecommendedAxes_noWeak_returnsTopTwo() {
        let worker = SpecialistAssessmentWorker(realmActor: nil)
        // Все оси «средние» — балл 0.5 у каждой.
        let answers: [SpecialistAssessmentAnswer] = [
            .init(questionId: "a1", axis: .articulation, numericValue: 3),
            .init(questionId: "p1", axis: .phonology, numericValue: 3),
            .init(questionId: "l1", axis: .lexical, numericValue: 3),
            .init(questionId: "g1", axis: .grammar, numericValue: 3),
            .init(questionId: "c1", axis: .connectedSpeech, numericValue: 3)
        ]
        let result = worker.computeRecommendedAxes(answers: answers)
        XCTAssertEqual(result.count, 2, "fallback должен дать 2 оси")
    }

    func test_computeRecommendedAxes_allStrong_returnsEmpty() {
        let worker = SpecialistAssessmentWorker(realmActor: nil)
        let answers: [SpecialistAssessmentAnswer] = SpecialistAssessmentAxis.allCases
            .map { .init(questionId: "q-\($0.rawValue)", axis: $0, boolValue: true) }
        let result = worker.computeRecommendedAxes(answers: answers)
        XCTAssertEqual(result.count, 0)
    }
}

// MARK: - Corpus tests
//
// `SpecialistAssessmentCorpus.allQuestions` грузится через `Bundle.main`,
// который в xctest-контексте указывает на test-runner, а не на host app —
// поэтому в юнит-тестах коллекция пуста. JSON-ресурс
// `pack_specialist_assessment.json` физически лежит в host app bundle
// (project: Content/Seed/** → resources основного таргета).
// Тесты грузят корпус напрямую из host app bundle (тот же приём, что
// PhraseMappingLoader в LessonVoiceWorkerTests) и проверяют реально
// поставляемый JSON. Актуальный корпус — 15 вопросов (commit 3d45405f).

private enum SpecialistAssessmentCorpusLoader {
    private struct PackFile: Decodable {
        let questions: [SpecialistAssessmentQuestion]
    }

    /// Находит URL ресурса `pack_specialist_assessment.json` среди всех
    /// доступных бандлов. В хост-аппе ресурс лежит в корне HappySpeech.app;
    /// `Bundle.main` в xctest указывает на test-runner, поэтому перебираем
    /// `Bundle.allBundles` + бандл хост-аппа, выведенный из URL test-bundle.
    private static func resourceURL(for testClass: AnyClass) -> URL? {
        let name = "pack_specialist_assessment"
        let ext = "json"

        var candidates = Bundle.allBundles
        candidates.append(.main)
        for bundle in candidates {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }

        // Fallback: .../HappySpeech.app/PlugIns/<...>.xctest → .../HappySpeech.app/<json>
        let appRootURL = Bundle(for: testClass).bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: appRootURL.path) {
            return appRootURL
        }
        return nil
    }

    static func loadQuestions(for testClass: AnyClass) -> [SpecialistAssessmentQuestion] {
        guard let url = resourceURL(for: testClass),
              let data = try? Data(contentsOf: url),
              let pack = try? JSONDecoder().decode(PackFile.self, from: data) else {
            return []
        }
        return pack.questions
    }

    /// Диагностика без мутабельного состояния (Swift 6 strict concurrency).
    static func diagnostic(for testClass: AnyClass) -> String {
        let name = "pack_specialist_assessment"
        var lines: [String] = []
        for bundle in Bundle.allBundles {
            let hit = bundle.url(forResource: name, withExtension: "json") != nil
            lines.append("[ab]\(bundle.bundlePath.split(separator: "/").suffix(2).joined(separator: "/")) hit=\(hit)")
        }
        let mainHit = Bundle.main.url(forResource: name, withExtension: "json") != nil
        lines.append("[main]\(Bundle.main.bundlePath.split(separator: "/").suffix(2).joined(separator: "/")) hit=\(mainHit)")
        let appRoot = Bundle(for: testClass).bundleURL
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("\(name).json")
        lines.append("[fb]\(appRoot.path) exists=\(FileManager.default.fileExists(atPath: appRoot.path))")
        return lines.joined(separator: " | ")
    }
}

final class SpecialistAssessmentCorpusTests: XCTestCase {

    private func loadCorpus() -> [SpecialistAssessmentQuestion] {
        SpecialistAssessmentCorpusLoader.loadQuestions(for: Self.self)
    }

    func test_corpus_has15Questions() {
        let c = loadCorpus()
        let attachment = XCTAttachment(
            string: SpecialistAssessmentCorpusLoader.diagnostic(for: Self.self)
        )
        attachment.name = "corpus-diagnostic"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(c.count, 15)
    }

    func test_corpus_coversAll5Axes() {
        let axes = Set(loadCorpus().map(\.axis))
        XCTAssertEqual(axes.count, 5)
        for axis in SpecialistAssessmentAxis.allCases {
            XCTAssertTrue(axes.contains(axis), "ось \(axis.rawValue) пропущена")
        }
    }

    func test_corpus_questionIdsAreUnique() {
        let ids = loadCorpus().map(\.id)
        XCTAssertFalse(ids.isEmpty, "корпус должен загрузиться из host app bundle")
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
