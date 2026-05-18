import Foundation
import OSLog

// MARK: - ParentGuideWorkerProtocol

@MainActor
protocol ParentGuideWorkerProtocol: AnyObject {
    /// Возвращает корпус уроков.
    func loadLessons() async -> [GuideLesson]
    /// Возвращает группы звуков ребёнка (для приоритизации релевантных уроков).
    func childSoundGroups(childId: String) async -> [String]
    /// Идентификаторы прочитанных уроков.
    func readLessonIds() -> Set<String>
    /// Идентификаторы избранных уроков.
    func favoriteLessonIds() -> Set<String>
    /// Отмечает урок прочитанным.
    func markRead(_ lessonId: String)
    /// Переключает избранное; возвращает новое состояние.
    func toggleFavorite(_ lessonId: String) -> Bool
}

// MARK: - ParentGuideWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Загружает статический корпус уроков, читает группы звуков ребёнка из
// `ChildRepository` для приоритизации и хранит «прочитано» / «избранное»
// в UserDefaults. Полностью offline / on-device.

@MainActor
final class ParentGuideWorker: ParentGuideWorkerProtocol {

    private let childRepository: any ChildRepository
    private let defaults: UserDefaults

    private static let readKey = "parentGuide.readLessonIds"
    private static let favoriteKey = "parentGuide.favoriteLessonIds"

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentGuide.Worker"
    )

    init(
        childRepository: any ChildRepository,
        defaults: UserDefaults = .standard
    ) {
        self.childRepository = childRepository
        self.defaults = defaults
    }

    func loadLessons() async -> [GuideLesson] {
        Self.logger.debug("Loaded \(ParentGuideCorpus.lessons.count) guide lessons")
        return ParentGuideCorpus.lessons
    }

    func childSoundGroups(childId: String) async -> [String] {
        do {
            let child = try await childRepository.fetch(id: childId)
            let groups = child.targetSounds.compactMap { ParentGuideCorpus.soundGroup(for: $0) }
            return Array(Set(groups))
        } catch {
            Self.logger.error(
                "Failed to read child sound groups: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    func readLessonIds() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.readKey) ?? [])
    }

    func favoriteLessonIds() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.favoriteKey) ?? [])
    }

    func markRead(_ lessonId: String) {
        var ids = readLessonIds()
        guard !ids.contains(lessonId) else { return }
        ids.insert(lessonId)
        defaults.set(Array(ids), forKey: Self.readKey)
    }

    func toggleFavorite(_ lessonId: String) -> Bool {
        var ids = favoriteLessonIds()
        let isFavorite: Bool
        if ids.contains(lessonId) {
            ids.remove(lessonId)
            isFavorite = false
        } else {
            ids.insert(lessonId)
            isFavorite = true
        }
        defaults.set(Array(ids), forKey: Self.favoriteKey)
        return isFavorite
    }
}
