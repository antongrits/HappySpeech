import Foundation
import OSLog

// MARK: - LetterTracePresenter (Clean Swift: Presenter)

@MainActor
final class LetterTracePresenter: LetterTracePresentationLogic {

    private weak var displayLogic: (any LetterTraceDisplayLogic)?
    private var totalCount: Int = 0
    private var currentPosition: Int = 0

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterTrace.Presenter"
    )

    init(displayLogic: any LetterTraceDisplayLogic) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: LetterTraceModels.Load.Response) async {
        totalCount = response.items.count
        currentPosition = 0
        let first = response.items.first.map { item in
            itemViewModel(from: item, position: 1, total: totalCount)
        }
        await displayLogic?.displayLoad(viewModel: .init(
            totalCount: totalCount,
            firstItem: first
        ))
    }

    func presentAdvance(response: LetterTraceModels.Advance.Response) async {
        currentPosition = response.position
        totalCount = response.totalCount
        let viewModel = response.nextItem.map {
            itemViewModel(from: $0, position: response.position, total: response.totalCount)
        }
        await displayLogic?.displayAdvance(viewModel: .init(item: viewModel))
    }

    func presentScore(response: LetterTraceModels.Score.Response) async {
        let percent = response.score.percent
        let text: String
        let symbol: String
        let success: Bool
        switch response.score.band {
        case .excellent:
            text = String(format: String(localized: "letterTrace.score.excellent"), percent)
            symbol = "checkmark.seal.fill"
            success = true
        case .good:
            text = String(format: String(localized: "letterTrace.score.good"), percent)
            symbol = "checkmark.circle.fill"
            success = true
        case .tryAgain:
            text = String(format: String(localized: "letterTrace.score.tryAgain"), percent)
            symbol = "arrow.counterclockwise.circle.fill"
            success = false
        }
        await displayLogic?.displayScore(viewModel: .init(
            feedbackText: text,
            bandSymbol: symbol,
            isSuccess: success,
            percent: percent
        ))
    }

    // MARK: - Helpers

    private func itemViewModel(
        from item: TraceItem,
        position: Int,
        total: Int
    ) -> LetterTraceModels.Load.ItemViewModel {
        let promptFormat: String = item.kind == .syllable
            ? String(localized: "letterTrace.prompt.syllable")
            : String(localized: "letterTrace.prompt")
        let promptText = String(format: promptFormat, item.symbol)
        let progress = String(
            format: String(localized: "letterTrace.progress.text"),
            position,
            total
        )
        return LetterTraceModels.Load.ItemViewModel(
            id: item.id,
            symbol: item.symbol,
            kind: item.kind,
            promptText: promptText,
            referenceStrokes: item.strokes,
            progressText: progress
        )
    }
}
