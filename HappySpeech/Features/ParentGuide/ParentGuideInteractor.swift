import Foundation
import OSLog

// MARK: - ParentGuideBusinessLogic

@MainActor
protocol ParentGuideBusinessLogic: AnyObject {
    func load(request: ParentGuideModels.Load.Request) async
    func markRead(request: ParentGuideModels.MarkRead.Request) async
    func toggleFavorite(request: ParentGuideModels.ToggleFavorite.Request) async
}

// MARK: - ParentGuideDataStore

@MainActor
protocol ParentGuideDataStore: AnyObject {
    var childId: String { get set }
}

// MARK: - ParentGuideInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Бизнес-логика обучающей базы: загружает корпус уроков, приоритизирует по
// группам звуков ребёнка, ведёт состояния «прочитано» / «избранное».

@MainActor
final class ParentGuideInteractor: ParentGuideBusinessLogic, ParentGuideDataStore {

    // MARK: - DataStore

    var childId: String

    // MARK: - VIP

    var presenter: (any ParentGuidePresentationLogic)?

    // MARK: - Deps

    private let worker: any ParentGuideWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentGuide.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any ParentGuideWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Load

    func load(request: ParentGuideModels.Load.Request) async {
        childId = request.childId
        let lessons = await worker.loadLessons()
        let soundGroups = await worker.childSoundGroups(childId: request.childId)
        let response = ParentGuideModels.Load.Response(
            lessons: lessons,
            childSoundGroups: soundGroups,
            readLessonIds: worker.readLessonIds(),
            favoriteLessonIds: worker.favoriteLessonIds()
        )
        Self.logger.debug(
            "Loaded parent guide: \(lessons.count) lessons, \(soundGroups.count) sound groups"
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - MarkRead

    func markRead(request: ParentGuideModels.MarkRead.Request) async {
        worker.markRead(request.lessonId)
        let response = ParentGuideModels.MarkRead.Response(
            lessonId: request.lessonId,
            isRead: true
        )
        await presenter?.presentMarkRead(response: response)
    }

    // MARK: - ToggleFavorite

    func toggleFavorite(request: ParentGuideModels.ToggleFavorite.Request) async {
        let isFavorite = worker.toggleFavorite(request.lessonId)
        hapticService.selection()
        let response = ParentGuideModels.ToggleFavorite.Response(
            lessonId: request.lessonId,
            isFavorite: isFavorite
        )
        await presenter?.presentToggleFavorite(response: response)
    }
}
