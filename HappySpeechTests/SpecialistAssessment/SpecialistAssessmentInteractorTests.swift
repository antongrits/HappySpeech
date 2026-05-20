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

final class SpecialistAssessmentCorpusTests: XCTestCase {

    func test_corpus_has10Questions() {
        XCTAssertEqual(SpecialistAssessmentCorpus.allQuestions.count, 10)
    }

    func test_corpus_coversAll5Axes() {
        let axes = Set(SpecialistAssessmentCorpus.allQuestions.map(\.axis))
        XCTAssertEqual(axes.count, 5)
        for axis in SpecialistAssessmentAxis.allCases {
            XCTAssertTrue(axes.contains(axis), "ось \(axis.rawValue) пропущена")
        }
    }

    func test_corpus_questionIdsAreUnique() {
        let ids = SpecialistAssessmentCorpus.allQuestions.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
