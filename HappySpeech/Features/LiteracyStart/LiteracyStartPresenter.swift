import Foundation

// MARK: - LiteracyStartPresenter

@MainActor
final class LiteracyStartPresenter {

    weak var displayLogic: (any LiteracyStartDisplayLogic)?

    init(displayLogic: any LiteracyStartDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load Letter

    func presentLoadLetter(response: LiteracyStartModels.LoadLetter.Response) async {
        let title = String(
            format: String(localized: "literacy.start.title.format"),
            response.letter
        )
        let a11y = String(
            format: String(localized: "literacy.start.a11y.format"),
            response.letter,
            response.words.map { $0.text }.joined(separator: ", ")
        )
        let vm = LiteracyStartModels.LoadLetter.ViewModel(
            titleText: title,
            letter: response.letter,
            words: response.words,
            traceButtonTitle: String(localized: "literacy.start.cta.trace"),
            listenButtonTitle: String(localized: "literacy.start.cta.listen"),
            accessibilityLabel: a11y
        )
        await displayLogic?.displayLoadLetter(viewModel: vm)
    }

    // MARK: - Unsupported

    func presentUnsupportedSound(targetSound: String) async {
        await displayLogic?.displayUnsupportedSound(targetSound: targetSound)
    }
}
