import Foundation
import SwiftUI

// MARK: - ARFaceFilterPresentationLogic

@MainActor
protocol ARFaceFilterPresentationLogic: AnyObject, Sendable {
    func presentSetMask(mask: FaceMaskKind) async
    func presentTrigger(
        response: ARFaceFilterModels.Trigger.Response,
        mask: FaceMaskKind
    ) async
}

// MARK: - ARFaceFilterPresenter

@MainActor
final class ARFaceFilterPresenter: ARFaceFilterPresentationLogic {

    weak var displayLogic: (any ARFaceFilterDisplayLogic)?

    init(displayLogic: (any ARFaceFilterDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentSetMask(mask: FaceMaskKind) async {
        let prompt = String(
            format: String(localized: "facefilter.prompt"),
            mask.triggerWord
        )
        let viewModel = ARFaceFilterModels.SetMask.ViewModel(
            mask: mask,
            promptText: prompt,
            triggerWord: mask.triggerWord
        )
        await displayLogic?.displaySetMask(viewModel: viewModel)
    }

    func presentTrigger(
        response: ARFaceFilterModels.Trigger.Response,
        mask: FaceMaskKind
    ) async {
        let celebration: String
        if response.isMatched {
            celebration = String(
                format: String(localized: "facefilter.match.celebration"),
                response.matchedWord
            )
        } else {
            celebration = ""
        }
        let viewModel = ARFaceFilterModels.Trigger.ViewModel(
            isMatched: response.isMatched,
            celebrationText: celebration
        )
        await displayLogic?.displayTrigger(viewModel: viewModel)
    }
}
