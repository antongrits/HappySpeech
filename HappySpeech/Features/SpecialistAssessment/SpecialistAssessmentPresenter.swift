import Foundation
import OSLog

// MARK: - SpecialistAssessmentPresentationLogic

@MainActor
protocol SpecialistAssessmentPresentationLogic: AnyObject {
    func presentLoad(response: SpecialistAssessmentModels.Load.Response) async
    func presentSubmit(response: SpecialistAssessmentModels.Submit.Response) async
}

// MARK: - SpecialistAssessmentPresenter

@MainActor
final class SpecialistAssessmentPresenter: SpecialistAssessmentPresentationLogic {

    weak var displayLogic: (any SpecialistAssessmentDisplayLogic)?

    init(displayLogic: (any SpecialistAssessmentDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: SpecialistAssessmentModels.Load.Response) async {
        let total = response.questions.count
        let questionVMs = response.questions.enumerated().map { idx, question in
            SpecialistAssessmentModels.Load.QuestionViewModel(
                id: question.id,
                text: question.text,
                axis: question.axis,
                type: question.type,
                scale: question.scale,
                progressLabel: String(
                    format: String(localized: "specAssessment.progress"),
                    idx + 1, total
                )
            )
        }
        let viewModel = SpecialistAssessmentModels.Load.ViewModel(
            title: String(localized: "specAssessment.title"),
            questions: questionVMs
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - Submit

    func presentSubmit(response: SpecialistAssessmentModels.Submit.Response) async {
        let recommended = response.recommendedAxes.enumerated().map { idx, axis in
            SpecialistAssessmentModels.Submit.RecommendedAxisViewModel(
                id: "rec-\(idx)-\(axis.rawValue)",
                axis: axis,
                displayName: Self.displayName(for: axis),
                rationale: Self.rationale(for: axis)
            )
        }
        let validUntil = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        let viewModel = SpecialistAssessmentModels.Submit.ViewModel(
            title: response.recommendedAxes.isEmpty
                ? String(localized: "specAssessment.summary.noFocus")
                : String(localized: "specAssessment.summary.title"),
            recommendedAxes: recommended,
            validUntilLabel: String(
                format: String(localized: "specAssessment.summary.validUntil"),
                formatter.string(from: validUntil)
            ),
            applyCtaTitle: String(localized: "specAssessment.summary.apply")
        )
        await displayLogic?.displaySubmit(viewModel: viewModel)
    }

    // MARK: - Helpers

    static func displayName(for axis: SpecialistAssessmentAxis) -> String {
        switch axis {
        case .articulation:     return String(localized: "specAssessment.axis.articulation")
        case .phonology:        return String(localized: "specAssessment.axis.phonology")
        case .lexical:          return String(localized: "specAssessment.axis.lexical")
        case .grammar:          return String(localized: "specAssessment.axis.grammar")
        case .connectedSpeech:  return String(localized: "specAssessment.axis.connectedSpeech")
        }
    }

    static func rationale(for axis: SpecialistAssessmentAxis) -> String {
        switch axis {
        case .articulation:
            return String(localized: "specAssessment.rationale.articulation")
        case .phonology:
            return String(localized: "specAssessment.rationale.phonology")
        case .lexical:
            return String(localized: "specAssessment.rationale.lexical")
        case .grammar:
            return String(localized: "specAssessment.rationale.grammar")
        case .connectedSpeech:
            return String(localized: "specAssessment.rationale.connectedSpeech")
        }
    }
}
