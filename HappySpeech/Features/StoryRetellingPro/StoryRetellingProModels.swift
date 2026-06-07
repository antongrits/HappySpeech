import Foundation

// MARK: - StoryRetellingProModels (Clean Swift: Models)
//
// Реальная активность пересказа: ребёнок слушает/вспоминает сказку, нажимает
// «Записать», пересказывает; речь распознаётся (ASR) и оценивается по покрытию
// ключевых фактов сказки. Запись и завершённость персистятся в Realm
// (`ChildOralStoryObject`, `stimulusIds = [storyId]`). Флаг «выполнено»
// вычисляется из РЕАЛЬНЫХ сохранённых пересказов — без хардкода.

enum StoryRetellingProModels {

    /// Сказка с реальным набором ключевых фактов для скоринга покрытия.
    struct Story: Identifiable, Hashable {
        let id: String
        let title: String
        let summary: String
        /// Ключевые слова/факты, которые ребёнок должен упомянуть при пересказе.
        let keyFacts: [String]
        let durationSeconds: Int
        /// Завершено — есть сохранённый пересказ с достаточным покрытием.
        var isCompleted: Bool
        /// Лучшее достигнутое покрытие фактов, 0…1 (из реальных пересказов).
        var bestCoverage: Double

        var keyFactsCount: Int { keyFacts.count }
    }

    /// Стадия активности пересказа.
    enum Phase: Equatable {
        case browsing
        case recording
        case scoring
        case result(coverage: Double, matched: [String], missed: [String])
    }

    struct ViewState: Equatable {
        var stories: [Story]
        var selectedStoryId: String?
        var phase: Phase
        var isLoading: Bool

        /// Порог покрытия фактов для зачёта пересказа.
        static let passThreshold = 0.6

        /// Каталог сказок с реальными ключевыми фактами (русские народные).
        /// Флаги `isCompleted/bestCoverage` стартуют нейтрально и заполняются
        /// из Realm в `StoryRetellingProInteractor.load()`.
        static let catalog: [Story] = [
            Story(
                id: "kurochka-ryaba",
                title: "Курочка Ряба",
                summary: "О золотом яичке",
                keyFacts: ["дед", "баба", "курочка", "яичко", "мышка", "разбилось"],
                durationSeconds: 90,
                isCompleted: false,
                bestCoverage: 0
            ),
            Story(
                id: "repka",
                title: "Репка",
                summary: "Дружно — не грузно",
                keyFacts: ["дед", "репка", "бабка", "внучка", "жучка", "кошка", "мышка"],
                durationSeconds: 110,
                isCompleted: false,
                bestCoverage: 0
            ),
            Story(
                id: "kolobok",
                title: "Колобок",
                summary: "Хитрость лисы",
                keyFacts: ["колобок", "дед", "баба", "заяц", "волк", "медведь", "лиса"],
                durationSeconds: 140,
                isCompleted: false,
                bestCoverage: 0
            ),
            Story(
                id: "teremok",
                title: "Теремок",
                summary: "Кто в теремочке живёт",
                keyFacts: ["теремок", "мышка", "лягушка", "заяц", "лиса", "волк", "медведь"],
                durationSeconds: 160,
                isCompleted: false,
                bestCoverage: 0
            ),
            Story(
                id: "tri-medvedya",
                title: "Три медведя",
                summary: "Маша в лесу",
                keyFacts: ["маша", "лес", "избушка", "медведь", "стул", "каша", "кровать"],
                durationSeconds: 180,
                isCompleted: false,
                bestCoverage: 0
            )
        ]

        static let initial = ViewState(
            stories: catalog,
            selectedStoryId: nil,
            phase: .browsing,
            isLoading: true
        )
    }
}
