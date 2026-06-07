import Foundation
import OSLog

// MARK: - LetterPaintingFunInteractor

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
@MainActor
@Observable
final class LetterPaintingFunInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterPaintingFun"
    )

    let childId: String
    var state: LetterPaintingFunModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func selectLetter(_ letter: String) {
        state.currentLetter = letter
        state.strokes.removeAll()
        Self.logger.info("selectLetter \(letter, privacy: .public)")
    }

    func selectColor(_ color: LetterPaintingFunModels.PaintColor) {
        state.currentColor = color
        Self.logger.info("selectColor \(color.rawValue, privacy: .public)")
    }

    func appendStroke(_ points: [CGPoint]) {
        guard !points.isEmpty else { return }
        let stroke = LetterPaintingFunModels.Stroke(
            id: UUID(),
            color: state.currentColor,
            points: points
        )
        state.strokes.append(stroke)
    }

    func clear() {
        state.strokes.removeAll()
        Self.logger.info("clear strokes")
    }
}
