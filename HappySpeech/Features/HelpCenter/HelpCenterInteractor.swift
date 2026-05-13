import Foundation
import OSLog

// MARK: - HelpCenterBusinessLogic

@MainActor
protocol HelpCenterBusinessLogic: AnyObject {
    func load(request: HelpCenterModels.Load.Request) async
    func toggleFAQ(request: HelpCenterModels.ToggleFAQ.Request) async
    func selectVideo(request: HelpCenterModels.SelectVideo.Request) async
    func contactSupport(request: HelpCenterModels.ContactSupport.Request) async
}

// MARK: - HelpCenterDataStore

@MainActor
protocol HelpCenterDataStore: AnyObject {
    var expandedIds: Set<String> { get set }
    var selectedVideo: TutorialVideo? { get set }
}

// MARK: - HelpCenterInteractor (Clean Swift: Interactor)
//
// Block AE v21 — экран справки. Управляет:
//   • загрузкой FAQ + видео-туториалов (через FAQRepositoryWorker)
//   • состоянием раскрытия аккордеона
//   • выбором видео для проигрывания
//   • действием «Связаться с логопедом» (через Router → LogopedistChat)
//
// COPPA: всё on-device; никаких внешних API.

@MainActor
final class HelpCenterInteractor: HelpCenterBusinessLogic, HelpCenterDataStore {

    // MARK: - DataStore

    var expandedIds: Set<String> = []
    var selectedVideo: TutorialVideo?

    // MARK: - VIP

    var presenter: (any HelpCenterPresentationLogic)?

    // MARK: - Workers / deps

    private let faqWorker: any FAQRepositoryWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HelpCenter.Interactor"
    )

    // MARK: - Init

    init(
        faqWorker: any FAQRepositoryWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.faqWorker = faqWorker
        self.hapticService = hapticService
    }

    // MARK: - Load

    func load(request: HelpCenterModels.Load.Request) async {
        _ = request
        let faqs = await faqWorker.loadFAQ()
        let videos = await faqWorker.loadVideos()

        let response = HelpCenterModels.Load.Response(
            categories: FAQCategory.allCases,
            entries: faqs,
            videos: videos
        )
        Self.logger.debug("Loaded HelpCenter: \(faqs.count) FAQ, \(videos.count) videos")
        await presenter?.presentLoad(response: response)
    }

    // MARK: - ToggleFAQ

    func toggleFAQ(request: HelpCenterModels.ToggleFAQ.Request) async {
        let willExpand: Bool
        if expandedIds.contains(request.entryId) {
            expandedIds.remove(request.entryId)
            willExpand = false
        } else {
            expandedIds.insert(request.entryId)
            willExpand = true
        }
        hapticService.selection()
        let response = HelpCenterModels.ToggleFAQ.Response(
            entryId: request.entryId,
            expanded: willExpand
        )
        await presenter?.presentToggleFAQ(response: response)
    }

    // MARK: - SelectVideo

    func selectVideo(request: HelpCenterModels.SelectVideo.Request) async {
        guard let video = HelpCenterCorpus.video(forId: request.videoId) else {
            Self.logger.error("Unknown video id: \(request.videoId, privacy: .public)")
            return
        }
        guard faqWorker.videoExists(video.resourceName) else {
            Self.logger.error("Video file missing: \(video.resourceName, privacy: .public)")
            return
        }
        self.selectedVideo = video
        hapticService.impact(.light)
        let response = HelpCenterModels.SelectVideo.Response(video: video)
        await presenter?.presentSelectVideo(response: response)
    }

    // MARK: - ContactSupport

    func contactSupport(request: HelpCenterModels.ContactSupport.Request) async {
        _ = request
        Self.logger.info("Contact support requested")
        hapticService.notification(.success)
        let response = HelpCenterModels.ContactSupport.Response(success: true)
        await presenter?.presentContactSupport(response: response)
    }
}
