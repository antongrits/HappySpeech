import Foundation
import OSLog

// MARK: - DemoBusinessLogic

@MainActor
protocol DemoBusinessLogic: AnyObject {
    func loadDemo(_ request: DemoModels.LoadDemo.Request)
    func advanceStep(_ request: DemoModels.AdvanceStep.Request)
    func goBack(_ request: DemoModels.GoBack.Request)
    func skipDemo(_ request: DemoModels.SkipDemo.Request)
    func completeDemo(_ request: DemoModels.CompleteDemo.Request)
}

// MARK: - DemoInteractor

/// Бизнес-логика 15-шагового демо-walkthrough'а.
/// Стек шагов — статический seed (определён ниже). На M8 будет вынесено
/// в content-pack `demo_tour.json`, чтобы можно было A/B-тестировать тексты.
@MainActor
final class DemoInteractor: DemoBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any DemoPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Demo")

    // MARK: - State

    private var steps: [DemoStep] = []
    private var currentIndex: Int = 0

    // MARK: - Init

    init() {
        steps = Self.makeSeed()
    }

    // MARK: - BusinessLogic

    func loadDemo(_ request: DemoModels.LoadDemo.Request) {
        currentIndex = 0
        logger.info("loadDemo total=\(self.steps.count, privacy: .public)")
        presenter?.presentLoadDemo(.init(
            steps: steps,
            currentIndex: currentIndex
        ))
    }

    func advanceStep(_ request: DemoModels.AdvanceStep.Request) {
        let lastIndex = max(0, steps.count - 1)
        let nextIndex = min(currentIndex + 1, lastIndex)
        let isCompleted = (currentIndex >= lastIndex)

        if !isCompleted {
            currentIndex = nextIndex
        }
        logger.info("advanceStep to=\(self.currentIndex, privacy: .public) completed=\(isCompleted, privacy: .public)")

        presenter?.presentAdvanceStep(.init(
            steps: steps,
            currentIndex: currentIndex,
            isCompleted: isCompleted
        ))
    }

    func goBack(_ request: DemoModels.GoBack.Request) {
        currentIndex = max(0, currentIndex - 1)
        logger.info("goBack to=\(self.currentIndex, privacy: .public)")
        presenter?.presentGoBack(.init(
            steps: steps,
            currentIndex: currentIndex
        ))
    }

    func skipDemo(_ request: DemoModels.SkipDemo.Request) {
        logger.info("skipDemo at=\(self.currentIndex, privacy: .public)")
        presenter?.presentSkipDemo(.init())
    }

    func completeDemo(_ request: DemoModels.CompleteDemo.Request) {
        logger.info("completeDemo at=\(self.currentIndex, privacy: .public)")
        presenter?.presentCompleteDemo(.init())
    }
}

// MARK: - Seed (15 steps)

private extension DemoInteractor {

    static func makeSeed() -> [DemoStep] {
        // 15 шагов: главный экран → занятия → карта мира → прогресс → AR-зона
        // → настройки → специалист → награды → родительский дашборд → задания
        // → история → завершение.
        [
            DemoStep(
                id: 1,
                title: String(localized: "demo.step1.title"),
                description: String(localized: "demo.step1.desc"),
                mascotText: String(localized: "demo.step1.mascot"),
                screenEmoji: "🏠",
                highlightColor: "primary"
            ),
            DemoStep(
                id: 2,
                title: String(localized: "demo.step2.title"),
                description: String(localized: "demo.step2.desc"),
                mascotText: String(localized: "demo.step2.mascot"),
                screenEmoji: "🎯",
                highlightColor: "primary"
            ),
            DemoStep(
                id: 3,
                title: String(localized: "demo.step3.title"),
                description: String(localized: "demo.step3.desc"),
                mascotText: String(localized: "demo.step3.mascot"),
                screenEmoji: "🗺️",
                highlightColor: "sky"
            ),
            DemoStep(
                id: 4,
                title: String(localized: "demo.step4.title"),
                description: String(localized: "demo.step4.desc"),
                mascotText: String(localized: "demo.step4.mascot"),
                screenEmoji: "📈",
                highlightColor: "mint"
            ),
            DemoStep(
                id: 5,
                title: String(localized: "demo.step5.title"),
                description: String(localized: "demo.step5.desc"),
                mascotText: String(localized: "demo.step5.mascot"),
                screenEmoji: "🪞",
                highlightColor: "lilac"
            ),
            DemoStep(
                id: 6,
                title: String(localized: "demo.step6.title"),
                description: String(localized: "demo.step6.desc"),
                mascotText: String(localized: "demo.step6.mascot"),
                screenEmoji: "⚙️",
                highlightColor: "parent"
            ),
            DemoStep(
                id: 7,
                title: String(localized: "demo.step7.title"),
                description: String(localized: "demo.step7.desc"),
                mascotText: String(localized: "demo.step7.mascot"),
                screenEmoji: "🩺",
                highlightColor: "spec"
            ),
            DemoStep(
                id: 8,
                title: String(localized: "demo.step8.title"),
                description: String(localized: "demo.step8.desc"),
                mascotText: String(localized: "demo.step8.mascot"),
                screenEmoji: "🏆",
                highlightColor: "gold"
            ),
            DemoStep(
                id: 9,
                title: String(localized: "demo.step9.title"),
                description: String(localized: "demo.step9.desc"),
                mascotText: String(localized: "demo.step9.mascot"),
                screenEmoji: "👨‍👩‍👧",
                highlightColor: "parent"
            ),
            DemoStep(
                id: 10,
                title: String(localized: "demo.step10.title"),
                description: String(localized: "demo.step10.desc"),
                mascotText: String(localized: "demo.step10.mascot"),
                screenEmoji: "📋",
                highlightColor: "butter"
            ),
            DemoStep(
                id: 11,
                title: String(localized: "demo.step11.title"),
                description: String(localized: "demo.step11.desc"),
                mascotText: String(localized: "demo.step11.mascot"),
                screenEmoji: "📜",
                highlightColor: "parent"
            ),
            DemoStep(
                id: 12,
                title: String(localized: "demo.step12.title"),
                description: String(localized: "demo.step12.desc"),
                mascotText: String(localized: "demo.step12.mascot"),
                screenEmoji: "🎵",
                highlightColor: "primary"
            ),
            DemoStep(
                id: 13,
                title: String(localized: "demo.step13.title"),
                description: String(localized: "demo.step13.desc"),
                mascotText: String(localized: "demo.step13.mascot"),
                screenEmoji: "🌬️",
                highlightColor: "mint"
            ),
            DemoStep(
                id: 14,
                title: String(localized: "demo.step14.title"),
                description: String(localized: "demo.step14.desc"),
                mascotText: String(localized: "demo.step14.mascot"),
                screenEmoji: "🥁",
                highlightColor: "gold"
            ),
            DemoStep(
                id: 15,
                title: String(localized: "demo.step15.title"),
                description: String(localized: "demo.step15.desc"),
                mascotText: String(localized: "demo.step15.mascot"),
                screenEmoji: "🎉",
                highlightColor: "primary"
            )
        ]
    }
}
