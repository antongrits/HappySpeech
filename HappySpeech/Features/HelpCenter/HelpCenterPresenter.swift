import Foundation
import OSLog

// MARK: - HelpCenterPresentationLogic

@MainActor
protocol HelpCenterPresentationLogic: AnyObject {
    func presentLoad(response: HelpCenterModels.Load.Response) async
    func presentToggleFAQ(response: HelpCenterModels.ToggleFAQ.Response) async
    func presentSelectVideo(response: HelpCenterModels.SelectVideo.Response) async
    func presentContactSupport(response: HelpCenterModels.ContactSupport.Response) async
}

// MARK: - HelpCenterPresenter (Clean Swift: Presenter)
//
// Block AE v21 — мапит Response → ViewModel.
// Все строки через `String(localized:)`; формат длительности видео — «mm:ss».

@MainActor
final class HelpCenterPresenter: HelpCenterPresentationLogic {

    weak var displayLogic: (any HelpCenterDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HelpCenter.Presenter"
    )

    init(displayLogic: (any HelpCenterDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: HelpCenterModels.Load.Response) async {
        let grouped = Dictionary(grouping: response.entries) { $0.category }

        let categoryVMs: [HelpCenterModels.Load.CategoryViewModel] = response.categories.compactMap { category in
            guard let entries = grouped[category], !entries.isEmpty else { return nil }
            let categoryTitle = String(localized: String.LocalizationValue(category.titleKey))
            let entryVMs = entries.map { entry in
                HelpCenterModels.Load.FAQEntryViewModel(
                    id: entry.id,
                    question: String(localized: String.LocalizationValue(entry.questionKey)),
                    answer: String(localized: String.LocalizationValue(entry.answerKey)),
                    categoryTitle: categoryTitle
                )
            }
            return .init(
                id: category.rawValue,
                title: categoryTitle,
                symbolName: category.symbolName,
                entries: entryVMs
            )
        }

        let videoCells = response.videos.map { video in
            HelpCenterModels.Load.VideoCellViewModel(
                id: video.id,
                title: String(localized: String.LocalizationValue(video.titleKey)),
                description: String(localized: String.LocalizationValue(video.descriptionKey)),
                resourceName: video.resourceName,
                durationLabel: formatDuration(video.durationSeconds),
                symbolName: video.symbolName,
                accessibilityLabel: String(
                    format: String(localized: "helpCenter.video.cell.a11y"),
                    String(localized: String.LocalizationValue(video.titleKey)),
                    formatDuration(video.durationSeconds)
                )
            )
        }

        let videoSection = HelpCenterModels.Load.VideoSectionViewModel(
            title: String(localized: "helpCenter.video.section.title"),
            subtitle: String(localized: "helpCenter.video.section.subtitle"),
            videos: videoCells
        )

        let viewModel = HelpCenterModels.Load.ViewModel(
            categories: categoryVMs,
            videoSection: videoSection,
            contactCta: String(localized: "helpCenter.contact.cta"),
            contactDescription: String(localized: "helpCenter.contact.description")
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - ToggleFAQ

    func presentToggleFAQ(response: HelpCenterModels.ToggleFAQ.Response) async {
        let viewModel = HelpCenterModels.ToggleFAQ.ViewModel(
            entryId: response.entryId,
            expanded: response.expanded
        )
        await displayLogic?.displayToggleFAQ(viewModel: viewModel)
    }

    // MARK: - SelectVideo

    func presentSelectVideo(response: HelpCenterModels.SelectVideo.Response) async {
        let title = String(localized: String.LocalizationValue(response.video.titleKey))
        let description = String(localized: String.LocalizationValue(response.video.descriptionKey))
        let viewModel = HelpCenterModels.SelectVideo.ViewModel(
            videoTitle: title,
            videoDescription: description,
            resourceName: response.video.resourceName,
            durationLabel: formatDuration(response.video.durationSeconds)
        )
        await displayLogic?.displaySelectVideo(viewModel: viewModel)
    }

    // MARK: - ContactSupport

    func presentContactSupport(response: HelpCenterModels.ContactSupport.Response) async {
        let toast = response.success
            ? String(localized: "helpCenter.contact.toast.opened")
            : String(localized: "helpCenter.contact.toast.failed")
        let viewModel = HelpCenterModels.ContactSupport.ViewModel(toastMessage: toast)
        await displayLogic?.displayContactSupport(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
