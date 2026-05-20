import Foundation
import OSLog

// MARK: - CustomWordListPresenter (Clean Swift: Presenter)

@MainActor
final class CustomWordListPresenter: CustomWordListPresentationLogic {

    private weak var displayLogic: (any CustomWordListDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CustomWordList.Presenter"
    )

    init(displayLogic: any CustomWordListDisplayLogic) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: CustomWordListModels.Load.Response) async {
        let rows = response.lists.map { data -> CustomWordListModels.Load.RowViewModel in
            let countText = String(
                format: String(localized: "customWordList.list.wordsCount"),
                data.words.count
            )
            let soundText = String(
                format: String(localized: "customWordList.list.targetSound"),
                data.targetSound
            )
            let label = String(
                format: String(localized: "customWordList.a11y.row"),
                data.name,
                data.words.count,
                data.targetSound
            )
            return CustomWordListModels.Load.RowViewModel(
                id: data.id,
                name: data.name,
                targetSoundText: soundText,
                wordsCountText: countText,
                accessibilityLabel: label
            )
        }
        await displayLogic?.displayLoad(viewModel: .init(
            lists: rows,
            isEmpty: rows.isEmpty
        ))
    }

    func presentSaveSuccess(response: CustomWordListModels.Save.Response) async {
        await displayLogic?.displaySaveSuccess(viewModel: .init(dismiss: true))
    }

    func presentSaveFailure(response: CustomWordListModels.Save.FailureResponse) async {
        let message: String
        switch response.reason {
        case .emptyName:
            message = String(localized: "customWordList.editor.error.name")
        case .emptyWords:
            message = String(localized: "customWordList.editor.error.words")
        }
        await displayLogic?.displaySaveFailure(viewModel: .init(message: message))
    }

    func presentDelete(response: CustomWordListModels.Delete.Response) async {
        await displayLogic?.displayDelete(removedId: response.removedId)
    }

    func presentPreview(response: CustomWordListModels.Preview.Response) async {
        let templates = response.exercises.map { ex in
            String(localized: String.LocalizationValue(ex.kind.titleKey))
        }
        let joined = templates.joined(separator: ", ")
        let text = String(
            format: String(localized: "customWordList.editor.preview.text"),
            response.exercises.count,
            joined
        )
        await displayLogic?.displayPreview(viewModel: .init(
            text: text,
            exercisesCount: response.exercises.count
        ))
    }
}
