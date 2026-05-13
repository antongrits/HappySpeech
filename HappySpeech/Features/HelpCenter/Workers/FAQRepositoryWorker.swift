import Foundation
import OSLog

// MARK: - FAQRepositoryWorkerProtocol

@MainActor
protocol FAQRepositoryWorkerProtocol: AnyObject {
    func loadFAQ() async -> [FAQEntry]
    func loadVideos() async -> [TutorialVideo]
    /// Возвращает true, если видеофайл существует в bundle.
    func videoExists(_ resourceName: String) -> Bool
}

// MARK: - FAQRepositoryWorker
//
// Block AE v21 — воркер для HelpCenter. Загружает статический корпус
// (``HelpCenterCorpus``) и проверяет наличие видеофайлов в bundle.
//
// Полностью offline / on-device. No networking.

@MainActor
final class FAQRepositoryWorker: FAQRepositoryWorkerProtocol {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HelpCenter.FAQRepositoryWorker"
    )

    init() {}

    func loadFAQ() async -> [FAQEntry] {
        Self.logger.debug("Loaded \(HelpCenterCorpus.faqs.count) FAQ entries")
        return HelpCenterCorpus.faqs
    }

    func loadVideos() async -> [TutorialVideo] {
        // Фильтруем только те, для которых файл реально лежит в bundle.
        let videos = HelpCenterCorpus.videos.filter { videoExists($0.resourceName) }
        Self.logger.debug("Loaded \(videos.count)/\(HelpCenterCorpus.videos.count) tutorials")
        return videos
    }

    func videoExists(_ resourceName: String) -> Bool {
        // Туториалы располагаются в `Resources/Videos/tutorials/<name>.mp4`.
        // Bundle.main.url с subdirectory корректно работает с folder-references.
        if Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4",
            subdirectory: "tutorials"
        ) != nil {
            return true
        }
        // Fallback: без subdirectory (на случай, если xcodegen положил по плоской структуре).
        return Bundle.main.url(forResource: resourceName, withExtension: "mp4") != nil
    }
}
