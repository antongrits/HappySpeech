@testable import HappySpeech
import XCTest

// MARK: - SpecialistAssessmentPresenterTests
//
// Verifies the non-trivial Response → ViewModel mapping in the specialist
// first-assessment presenter:
//   - Load: progress label includes 1-based index + total for each question
//   - Load: localized title is non-empty; question count preserved
//   - Submit: recommended axes get stable enumerated ids "rec-<idx>-<axis>"
//   - Submit: per-axis displayName + rationale resolved (distinct, non-empty)
//   - Submit: empty recommended axes → "no focus" title branch
//   - Submit: validUntil label is non-empty (date formatting present)
//   - Submit: applyCtaTitle non-empty

@MainActor
final class SpecialistAssessmentPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SpecialistAssessmentDisplayLogic {
        var loadVM: SpecialistAssessmentModels.Load.ViewModel?
        var submitVM: SpecialistAssessmentModels.Submit.ViewModel?
        var loadCount = 0
        var submitCount = 0

        func displayLoad(viewModel: SpecialistAssessmentModels.Load.ViewModel) async {
            loadCount += 1
            loadVM = viewModel
        }
        func displaySubmit(viewModel: SpecialistAssessmentModels.Submit.ViewModel) async {
            submitCount += 1
            submitVM = viewModel
        }
    }

    private func makeSUT() -> (SpecialistAssessmentPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = SpecialistAssessmentPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func question(
        _ id: String,
        axis: SpecialistAssessmentAxis = .articulation,
        type: SpecialistAssessmentQuestionType = .yesno
    ) -> SpecialistAssessmentQuestion {
        SpecialistAssessmentQuestion(
            id: id, axis: axis, text: "Вопрос \(id)", type: type, scale: nil, options: nil
        )
    }

    // MARK: - Load

    func test_load_callsDisplayAndPreservesCount() async {
        let (sut, spy) = makeSUT()
        let response = SpecialistAssessmentModels.Load.Response(
            questions: [question("q1"), question("q2"), question("q3")],
            childId: "c1", specialistId: "s1"
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.loadVM?.questions.count, 3)
    }

    func test_load_titleNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            questions: [question("q1")], childId: "c1", specialistId: "s1"
        ))
        XCTAssertFalse(spy.loadVM?.title.isEmpty ?? true)
    }

    func test_load_progressLabelNonEmptyAndDiffersAcrossQuestions() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            questions: [question("q1"), question("q2"), question("q3")],
            childId: "c1", specialistId: "s1"
        ))
        let labels = (spy.loadVM?.questions ?? []).map(\.progressLabel)
        XCTAssertEqual(labels.count, 3)
        XCTAssertTrue(labels.allSatisfy { !$0.isEmpty })
        // 1-based index → each label is distinct (1/3, 2/3, 3/3).
        XCTAssertEqual(Set(labels).count, 3)
    }

    func test_load_preservesQuestionFields() async {
        let (sut, spy) = makeSUT()
        let scale = SpecialistAssessmentScale(min: 1, max: 5, lowLabel: "низко", highLabel: "высоко")
        let q = SpecialistAssessmentQuestion(
            id: "qx", axis: .phonology, text: "Текст", type: .scale,
            scale: scale, options: ["А", "Б"]
        )
        await sut.presentLoad(response: .init(
            questions: [q], childId: "c1", specialistId: "s1"
        ))
        let vm = spy.loadVM?.questions.first
        XCTAssertEqual(vm?.id, "qx")
        XCTAssertEqual(vm?.axis, .phonology)
        XCTAssertEqual(vm?.type, .scale)
        XCTAssertEqual(vm?.scale, scale)
        XCTAssertEqual(vm?.options, ["А", "Б"])
    }

    func test_load_emptyQuestions_producesEmptyList() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            questions: [], childId: "c1", specialistId: "s1"
        ))
        XCTAssertEqual(spy.loadVM?.questions.count, 0)
    }

    // MARK: - Submit

    func test_submit_recommendedAxesEnumeratedIds() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmit(response: .init(
            recommendedAxes: [.articulation, .grammar],
            savedResultId: "r1"
        ))
        let ids = (spy.submitVM?.recommendedAxes ?? []).map(\.id)
        XCTAssertEqual(ids, ["rec-0-articulation", "rec-1-grammar"])
    }

    func test_submit_displayNameAndRationaleResolved() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmit(response: .init(
            recommendedAxes: [.lexical],
            savedResultId: "r1"
        ))
        let axis = spy.submitVM?.recommendedAxes.first
        XCTAssertEqual(axis?.axis, .lexical)
        XCTAssertFalse(axis?.displayName.isEmpty ?? true)
        XCTAssertFalse(axis?.rationale.isEmpty ?? true)
    }

    func test_submit_distinctDisplayNamesAcrossAxes() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmit(response: .init(
            recommendedAxes: SpecialistAssessmentAxis.allCases,
            savedResultId: "r1"
        ))
        let names = (spy.submitVM?.recommendedAxes ?? []).map(\.displayName)
        XCTAssertEqual(names.count, SpecialistAssessmentAxis.allCases.count)
        XCTAssertEqual(Set(names).count, names.count, "Каждая ось имеет уникальное название")
    }

    func test_submit_emptyAxes_usesNoFocusTitleBranch() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmit(response: .init(recommendedAxes: [], savedResultId: "r1"))
        let emptyTitle = spy.submitVM?.title

        await sut.presentSubmit(response: .init(recommendedAxes: [.grammar], savedResultId: "r2"))
        let nonEmptyTitle = spy.submitVM?.title

        XCTAssertNotNil(emptyTitle)
        XCTAssertNotNil(nonEmptyTitle)
        XCTAssertNotEqual(emptyTitle, nonEmptyTitle, "Пустой набор осей даёт иной заголовок")
        XCTAssertEqual(spy.submitVM?.recommendedAxes.count, 1)
    }

    func test_submit_validUntilAndCtaNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmit(response: .init(
            recommendedAxes: [.articulation],
            savedResultId: "r1"
        ))
        XCTAssertFalse(spy.submitVM?.validUntilLabel.isEmpty ?? true)
        XCTAssertFalse(spy.submitVM?.applyCtaTitle.isEmpty ?? true)
    }

    func test_submit_helperDisplayName_coversAllAxes() {
        for axis in SpecialistAssessmentAxis.allCases {
            XCTAssertFalse(SpecialistAssessmentPresenter.displayName(for: axis).isEmpty)
            XCTAssertFalse(SpecialistAssessmentPresenter.rationale(for: axis).isEmpty)
        }
    }
}
