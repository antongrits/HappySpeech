import Foundation
import OSLog

// MARK: - DialectAdaptationPresentationLogic

@MainActor
protocol DialectAdaptationPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: DialectAdaptationModels.Load.Response) async
    func presentSelect(response: DialectAdaptationModels.Select.Response) async
    func presentReset(response: DialectAdaptationModels.Reset.Response) async
}

// MARK: - DialectAdaptationPresenter (Clean Swift: Presenter)
//
// Block R.1 v18 — мапит Response → ViewModel.
//
// • Все строки через `String(localized:)` — ключи появятся в xcstrings
//   автоматически при сборке.
// • Дата применения форматируется через `RelativeDateTimeFormatter`.
// • Accessibility labels включают название диалекта + статус выбора.

@MainActor
final class DialectAdaptationPresenter: DialectAdaptationPresentationLogic {

    weak var displayLogic: (any DialectAdaptationDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DialectAdaptation.Presenter"
    )

    private let relativeFormatter: RelativeDateTimeFormatter

    init(displayLogic: (any DialectAdaptationDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ru_RU")
        self.relativeFormatter = formatter
    }

    // MARK: - Load

    func presentLoad(response: DialectAdaptationModels.Load.Response) async {
        let appliedText: String?
        if let appliedAt = response.appliedAt {
            let relative = relativeFormatter.localizedString(for: appliedAt, relativeTo: Date())
            appliedText = String(
                format: String(localized: "dialect.applied.format"),
                relative
            )
        } else {
            appliedText = nil
        }

        let rows = response.availableDialects.map { dialect in
            let isSelected = dialect.id == response.currentDialect.id
            let title = String(localized: String.LocalizationValue(dialect.titleKey))
            let description = String(localized: String.LocalizationValue(dialect.descriptionKey))

            let a11y: String
            if isSelected {
                a11y = String(
                    format: String(localized: "dialect.row.a11y.selected"),
                    title
                )
            } else {
                a11y = String(
                    format: String(localized: "dialect.row.a11y.available"),
                    title
                )
            }

            return DialectAdaptationModels.Load.DialectRow(
                id: dialect.id,
                title: title,
                description: description,
                symbolName: dialect.symbolName,
                markers: dialect.phoneticMarkers,
                isSelected: isSelected,
                accessibilityLabel: a11y
            )
        }

        let viewModel = DialectAdaptationModels.Load.ViewModel(
            currentDialectId: response.currentDialect.id,
            currentDialectTitle: String(
                localized: String.LocalizationValue(response.currentDialect.titleKey)
            ),
            appliedAtText: appliedText,
            dialects: rows
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - Select

    func presentSelect(response: DialectAdaptationModels.Select.Response) async {
        let title = String(
            localized: String.LocalizationValue(response.appliedDialect.titleKey)
        )
        let toast = String(
            format: String(localized: "dialect.toast.applied"),
            title
        )

        let viewModel = DialectAdaptationModels.Select.ViewModel(
            toastMessage: toast,
            dialectTitle: title,
            success: response.success
        )

        await displayLogic?.displaySelect(viewModel: viewModel)
    }

    // MARK: - Reset

    func presentReset(response: DialectAdaptationModels.Reset.Response) async {
        let title = String(
            localized: String.LocalizationValue(response.restored.titleKey)
        )
        let toast = String(
            format: String(localized: "dialect.toast.reset"),
            title
        )

        let viewModel = DialectAdaptationModels.Reset.ViewModel(
            toastMessage: toast
        )

        await displayLogic?.displayReset(viewModel: viewModel)
    }
}
