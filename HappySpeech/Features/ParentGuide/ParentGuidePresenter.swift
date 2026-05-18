import Foundation
import OSLog

// MARK: - ParentGuidePresentationLogic

@MainActor
protocol ParentGuidePresentationLogic: AnyObject {
    func presentLoad(response: ParentGuideModels.Load.Response) async
    func presentMarkRead(response: ParentGuideModels.MarkRead.Response) async
    func presentToggleFavorite(response: ParentGuideModels.ToggleFavorite.Response) async
}

// MARK: - ParentGuidePresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Мапит корпус уроков в ViewModel: группирует по темам, помечает
// рекомендованные (по группам звуков ребёнка), выбирает «совет дня».
// Все строки — через `String(localized:)`.

@MainActor
final class ParentGuidePresenter: ParentGuidePresentationLogic {

    weak var displayLogic: (any ParentGuideDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentGuide.Presenter"
    )

    init(displayLogic: (any ParentGuideDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: ParentGuideModels.Load.Response) async {
        let soundGroupSet = Set(response.childSoundGroups)

        func isRecommended(_ lesson: GuideLesson) -> Bool {
            guard !lesson.relevantSoundGroups.isEmpty else { return false }
            return !soundGroupSet.isDisjoint(with: lesson.relevantSoundGroups)
        }

        func makeLessonVM(_ lesson: GuideLesson) -> ParentGuideModels.Load.LessonViewModel {
            let title = localized(lesson.titleKey)
            let topicTitle = localized(lesson.topic.titleKey)
            let isRead = response.readLessonIds.contains(lesson.id)
            let recommended = isRecommended(lesson)
            let readLabel = String(
                format: String(localized: "parentGuide.lesson.readMinutes"),
                lesson.readMinutes
            )
            let stateText = isRead
                ? String(localized: "parentGuide.lesson.read")
                : String(localized: "parentGuide.lesson.unread")
            return .init(
                id: lesson.id,
                title: title,
                summary: localized(lesson.summaryKey),
                body: localized(lesson.bodyKey),
                topicTitle: topicTitle,
                symbolName: lesson.topic.symbolName,
                readLabel: readLabel,
                isRead: isRead,
                isFavorite: response.favoriteLessonIds.contains(lesson.id),
                isRecommended: recommended,
                accessibilityLabel: "\(title). \(topicTitle). \(readLabel). \(stateText)"
            )
        }

        // Группировка по темам, темы — в порядке enum.
        let grouped = Dictionary(grouping: response.lessons) { $0.topic }
        let topicVMs: [ParentGuideModels.Load.TopicViewModel] = GuideTopic.allCases.compactMap { topic in
            guard let lessons = grouped[topic], !lessons.isEmpty else { return nil }
            // Рекомендованные уроки внутри темы — выше.
            let sorted = lessons.sorted { lhs, rhs in
                isRecommended(lhs) && !isRecommended(rhs)
            }
            return .init(
                id: topic.rawValue,
                title: localized(topic.titleKey),
                symbolName: topic.symbolName,
                lessons: sorted.map(makeLessonVM)
            )
        }

        // Совет дня: первый нерпрочитанный рекомендованный, иначе первый нерпрочитанный.
        let recommendedUnread = response.lessons.first {
            isRecommended($0) && !response.readLessonIds.contains($0.id)
        }
        let anyUnread = response.lessons.first { !response.readLessonIds.contains($0.id) }
        let tipLesson = recommendedUnread ?? anyUnread ?? response.lessons.first
        let tipVM = tipLesson.map(makeLessonVM)

        let viewModel = ParentGuideModels.Load.ViewModel(
            headerTitle: String(localized: "parentGuide.header.title"),
            headerSubtitle: String(localized: "parentGuide.header.subtitle"),
            tipOfDay: tipVM,
            topics: topicVMs
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - MarkRead

    func presentMarkRead(response: ParentGuideModels.MarkRead.Response) async {
        await displayLogic?.displayMarkRead(
            viewModel: .init(lessonId: response.lessonId, isRead: response.isRead)
        )
    }

    // MARK: - ToggleFavorite

    func presentToggleFavorite(response: ParentGuideModels.ToggleFavorite.Response) async {
        await displayLogic?.displayToggleFavorite(
            viewModel: .init(lessonId: response.lessonId, isFavorite: response.isFavorite)
        )
    }

    // MARK: - Helpers

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
