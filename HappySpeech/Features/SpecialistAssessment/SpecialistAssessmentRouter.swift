import Foundation

// MARK: - SpecialistAssessmentRoutingLogic

@MainActor
protocol SpecialistAssessmentRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SpecialistAssessmentRouter

@MainActor
final class SpecialistAssessmentRouter: SpecialistAssessmentRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
