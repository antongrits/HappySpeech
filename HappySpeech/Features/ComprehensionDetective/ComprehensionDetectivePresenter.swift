import Foundation
import OSLog

// MARK: - ComprehensionDetectivePresentationLogic

@MainActor
protocol ComprehensionDetectivePresentationLogic: AnyObject {
    func presentStart(response: ComprehensionDetectiveModels.Start.Response) async
    func presentPick(response: ComprehensionDetectiveModels.Pick.Response) async
}

// MARK: - ComprehensionDetectivePresenter (Clean Swift: Presenter)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив».

@MainActor
final class ComprehensionDetectivePresenter: ComprehensionDetectivePresentationLogic {

    weak var displayLogic: (any ComprehensionDetectiveDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.Presenter"
    )

    init(displayLogic: (any ComprehensionDetectiveDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentStart(response: ComprehensionDetectiveModels.Start.Response) async {
        let title = String(localized: "detective.title")
        let tierLabel = Self.localized(response.tier.titleKey)
        let tierHint = Self.localized(response.tier.hintKey)

        let pictures = response.shuffledPictures.map { picture in
            ComprehensionDetectiveModels.Start.PictureViewModel(
                id: picture.id,
                symbolName: picture.symbolName,
                accessibilityLabel: picture.label
            )
        }

        let chips = response.availableTiers.map { tier in
            ComprehensionDetectiveModels.Start.TierChip(
                id: tier.rawValue,
                title: Self.localized(tier.titleKey),
                isSelected: tier == response.tier
            )
        }

        let progressLabel = String(
            format: String(localized: "detective.progress"),
            response.itemIndex,
            response.totalItemsInTier
        )

        let accessibility = String(
            format: String(localized: "detective.instruction.a11y"),
            response.item.instruction
        )

        let viewModel = ComprehensionDetectiveModels.Start.ViewModel(
            title: title,
            tierLabel: tierLabel,
            tierHint: tierHint,
            instruction: response.item.instruction,
            pictures: pictures,
            availableTiers: chips,
            progressLabel: progressLabel,
            accessibilityLabel: accessibility
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    func presentPick(response: ComprehensionDetectiveModels.Pick.Response) async {
        let toastTitle: String
        let toastDetail: String
        if response.isCorrect {
            toastTitle = String(localized: "detective.toast.correct.title")
            toastDetail = String(localized: "detective.toast.correct.detail")
        } else {
            toastTitle = String(localized: "detective.toast.wrong.title")
            toastDetail = String(
                format: String(localized: "detective.toast.wrong.detail"),
                response.instruction
            )
        }
        let viewModel = ComprehensionDetectiveModels.Pick.ViewModel(
            isCorrect: response.isCorrect,
            toastTitle: toastTitle,
            toastDetail: toastDetail,
            correctPictureId: response.correctPictureId
        )
        await displayLogic?.displayPick(viewModel: viewModel)
    }

    // MARK: - Localization helper

    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}
