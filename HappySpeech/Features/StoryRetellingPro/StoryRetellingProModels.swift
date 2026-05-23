import Foundation

// MARK: - StoryRetellingProModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum StoryRetellingProModels {

    struct Story: Identifiable, Hashable {
        let id: String
        let title: String
        let summary: String
        let keyFactsCount: Int
        let durationSeconds: Int
        let isCompleted: Bool
    }

    struct ViewState: Equatable {
        var stories: [Story]
        var selectedStoryId: String?

        static let initial = ViewState(stories: [
            Story(id: "s1", title: "Курочка Ряба", summary: "О золотом яичке", keyFactsCount: 5, durationSeconds: 90, isCompleted: true),
            Story(id: "s2", title: "Репка", summary: "Дружно — не грузно", keyFactsCount: 6, durationSeconds: 110, isCompleted: true),
            Story(id: "s3", title: "Колобок", summary: "Хитрость лисы", keyFactsCount: 7, durationSeconds: 140, isCompleted: false),
            Story(id: "s4", title: "Теремок", summary: "Кто в теремочке живёт", keyFactsCount: 8, durationSeconds: 160, isCompleted: false),
            Story(id: "s5", title: "Три медведя", summary: "Маша в лесу", keyFactsCount: 9, durationSeconds: 180, isCompleted: false)
        ], selectedStoryId: nil)
    }
}
