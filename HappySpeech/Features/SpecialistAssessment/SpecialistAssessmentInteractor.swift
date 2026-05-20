import Foundation
import OSLog

// MARK: - SpecialistAssessmentBusinessLogic

@MainActor
protocol SpecialistAssessmentBusinessLogic: AnyObject {
    func load(request: SpecialistAssessmentModels.Load.Request) async
    func answer(request: SpecialistAssessmentModels.Answer.Request) async
    func submit(request: SpecialistAssessmentModels.Submit.Request) async
}

// MARK: - SpecialistAssessmentDataStore

@MainActor
protocol SpecialistAssessmentDataStore: AnyObject {
    var childId: String { get set }
    var specialistId: String { get set }
    var answers: [String: SpecialistAssessmentAnswer] { get set }
}

// MARK: - SpecialistAssessmentInteractor (Clean Swift)
//
// VIP-логика анкеты:
//   1. load → передаёт все 10 вопросов Presenter'у.
//   2. answer(perQuestion) → сохраняет в DataStore.
//   3. submit → передаёт все ответы Worker'у → результат → Presenter.

@MainActor
final class SpecialistAssessmentInteractor:
    SpecialistAssessmentBusinessLogic, SpecialistAssessmentDataStore {

    // MARK: - DataStore

    var childId: String
    var specialistId: String
    var answers: [String: SpecialistAssessmentAnswer] = [:]

    // MARK: - VIP

    var presenter: (any SpecialistAssessmentPresentationLogic)?

    // MARK: - Deps

    private let worker: any SpecialistAssessmentWorkerProtocol

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistAssessment.Interactor"
    )

    init(
        childId: String,
        specialistId: String,
        worker: any SpecialistAssessmentWorkerProtocol
    ) {
        self.childId = childId
        self.specialistId = specialistId
        self.worker = worker
    }

    // MARK: - Load

    func load(request: SpecialistAssessmentModels.Load.Request) async {
        childId = request.childId
        specialistId = request.specialistId
        let response = SpecialistAssessmentModels.Load.Response(
            questions: worker.questions,
            childId: request.childId,
            specialistId: request.specialistId
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - Answer

    func answer(request: SpecialistAssessmentModels.Answer.Request) async {
        let answer = SpecialistAssessmentAnswer(
            questionId: request.questionId,
            axis: request.axis,
            boolValue: request.boolValue,
            numericValue: request.numericValue
        )
        answers[request.questionId] = answer
    }

    // MARK: - Submit

    func submit(request: SpecialistAssessmentModels.Submit.Request) async {
        let collected = Array(answers.values)
        let response = await worker.saveResult(
            childId: request.childId,
            specialistId: request.specialistId,
            answers: collected
        )
        let axesString = response.recommendedAxes.map(\.rawValue).joined(separator: ",")
        Self.logger.info(
            "Assessment saved id=\(response.savedResultId, privacy: .private); axes=\(axesString, privacy: .public)"
        )
        await presenter?.presentSubmit(response: response)
    }
}
