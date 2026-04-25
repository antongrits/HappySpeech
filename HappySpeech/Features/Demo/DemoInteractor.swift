import Foundation
import OSLog

// MARK: - DemoBusinessLogic

@MainActor
protocol DemoBusinessLogic: AnyObject {
    func loadDemo(_ request: DemoModels.LoadDemo.Request)
    func advanceStep(_ request: DemoModels.AdvanceStep.Request)
    func goBack(_ request: DemoModels.GoBack.Request)
    func jumpTo(_ request: DemoModels.JumpTo.Request)
    func tapInteractive(_ request: DemoModels.InteractiveTap.Request)
    func skipDemo(_ request: DemoModels.SkipDemo.Request)
    func completeDemo(_ request: DemoModels.CompleteDemo.Request)
}

// MARK: - DemoInteractor

/// Бизнес-логика 15-шагового демо-walkthrough'а.
/// Стек шагов — статический seed (определён ниже). На M8 будет вынесено
/// в content-pack `demo_tour.json`, чтобы можно было A/B-тестировать тексты.
///
/// Помимо текстов, у каждого шага хранится:
///   • `lyalyaState` — состояние маскота (waving / explaining / pointing / …);
///   • `accent` — семантический ключ цвета для градиента и кнопок;
///   • `illustrationSymbol` — SF Symbol для большой иллюстрации;
///   • `hasInteractive` + `actionTitle` — есть ли «Попробовать!»-CTA.
///
/// Sample interactive-таппинг сохраняется в `interactiveTapsRecorded`,
/// чтобы при повторном проходе тура можно было показать «Уже пробовал».
@MainActor
final class DemoInteractor: DemoBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any DemoPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Demo")

    // MARK: - State

    private var steps: [DemoStep] = []
    private var currentIndex: Int = 0
    private var interactiveTapsRecorded: Set<Int> = []

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
        logger.info(
            "advanceStep to=\(self.currentIndex, privacy: .public) completed=\(isCompleted, privacy: .public)"
        )

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

    func jumpTo(_ request: DemoModels.JumpTo.Request) {
        let lastIndex = max(0, steps.count - 1)
        let target = min(max(0, request.index), lastIndex)
        guard target != currentIndex else { return }
        currentIndex = target
        logger.info("jumpTo to=\(self.currentIndex, privacy: .public)")
        presenter?.presentJumpTo(.init(
            steps: steps,
            currentIndex: currentIndex
        ))
    }

    func tapInteractive(_ request: DemoModels.InteractiveTap.Request) {
        guard let step = steps[safe: currentIndex] else { return }
        guard step.hasInteractive else { return }
        interactiveTapsRecorded.insert(step.id)
        logger.info("tapInteractive step=\(step.id, privacy: .public)")
        presenter?.presentInteractiveTap(.init(
            stepId: step.id,
            stepTitle: step.title
        ))
    }

    func skipDemo(_ request: DemoModels.SkipDemo.Request) {
        logger.info("skipDemo at=\(self.currentIndex, privacy: .public)")
        presenter?.presentSkipDemo(.init())
    }

    func completeDemo(_ request: DemoModels.CompleteDemo.Request) {
        logger.info("completeDemo at=\(self.currentIndex, privacy: .public)")
        // Сохраняем флаг прохождения тура — UserDefaults.
        UserDefaults.standard.set(true, forKey: Self.tourCompletedKey)
        presenter?.presentCompleteDemo(.init())
    }

    // MARK: - Constants

    /// Ключ для UserDefaults: тур пройден целиком до 15-го шага.
    static let tourCompletedKey = "ru.happyspeech.demo.tourCompleted"
}

// MARK: - Seed (15 steps)

private extension DemoInteractor {

    // swiftlint:disable function_body_length
    static func makeSeed() -> [DemoStep] {
        // 15 шагов: знакомство → главный экран → карта → шаблоны игр →
        // AR-зеркало → прогресс → задания специалиста → награды → маскот →
        // offline-режим → privacy → родительский контур → CTA.
        [
            DemoStep(
                id: 1,
                title: String(localized: "demo.step1.title"),
                subtitle: String(localized: "demo.step1.subtitle"),
                description: String(localized: "demo.step1.desc"),
                mascotText: String(localized: "demo.step1.mascot"),
                screenEmoji: "🦋",
                illustrationSymbol: "face.smiling.fill",
                highlightColor: "primary",
                accent: .primary,
                lyalyaState: .waving,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 2,
                title: String(localized: "demo.step2.title"),
                subtitle: String(localized: "demo.step2.subtitle"),
                description: String(localized: "demo.step2.desc"),
                mascotText: String(localized: "demo.step2.mascot"),
                screenEmoji: "🏠",
                illustrationSymbol: "house.fill",
                highlightColor: "primary",
                accent: .lilac,
                lyalyaState: .explaining,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 3,
                title: String(localized: "demo.step3.title"),
                subtitle: String(localized: "demo.step3.subtitle"),
                description: String(localized: "demo.step3.desc"),
                mascotText: String(localized: "demo.step3.mascot"),
                screenEmoji: "🗺️",
                illustrationSymbol: "map.fill",
                highlightColor: "sky",
                accent: .teal,
                lyalyaState: .pointing,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 4,
                title: String(localized: "demo.step4.title"),
                subtitle: String(localized: "demo.step4.subtitle"),
                description: String(localized: "demo.step4.desc"),
                mascotText: String(localized: "demo.step4.mascot"),
                screenEmoji: "🎤",
                illustrationSymbol: "mic.fill",
                highlightColor: "primary",
                accent: .orange,
                lyalyaState: .singing,
                hasInteractive: true,
                actionTitle: String(localized: "demo.try")
            ),
            DemoStep(
                id: 5,
                title: String(localized: "demo.step5.title"),
                subtitle: String(localized: "demo.step5.subtitle"),
                description: String(localized: "demo.step5.desc"),
                mascotText: String(localized: "demo.step5.mascot"),
                screenEmoji: "👂",
                illustrationSymbol: "ear.fill",
                highlightColor: "mint",
                accent: .green,
                lyalyaState: .thinking,
                hasInteractive: true,
                actionTitle: String(localized: "demo.try")
            ),
            DemoStep(
                id: 6,
                title: String(localized: "demo.step6.title"),
                subtitle: String(localized: "demo.step6.subtitle"),
                description: String(localized: "demo.step6.desc"),
                mascotText: String(localized: "demo.step6.mascot"),
                screenEmoji: "🔁",
                illustrationSymbol: "arrow.left.arrow.right",
                highlightColor: "lilac",
                accent: .purple,
                lyalyaState: .explaining,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 7,
                title: String(localized: "demo.step7.title"),
                subtitle: String(localized: "demo.step7.subtitle"),
                description: String(localized: "demo.step7.desc"),
                mascotText: String(localized: "demo.step7.mascot"),
                screenEmoji: "🪞",
                illustrationSymbol: "camera.fill",
                highlightColor: "lilac",
                accent: .teal,
                lyalyaState: .waving,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 8,
                title: String(localized: "demo.step8.title"),
                subtitle: String(localized: "demo.step8.subtitle"),
                description: String(localized: "demo.step8.desc"),
                mascotText: String(localized: "demo.step8.mascot"),
                screenEmoji: "📈",
                illustrationSymbol: "chart.line.uptrend.xyaxis",
                highlightColor: "primary",
                accent: .orange,
                lyalyaState: .celebrating,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 9,
                title: String(localized: "demo.step9.title"),
                subtitle: String(localized: "demo.step9.subtitle"),
                description: String(localized: "demo.step9.desc"),
                mascotText: String(localized: "demo.step9.mascot"),
                screenEmoji: "📋",
                illustrationSymbol: "list.clipboard.fill",
                highlightColor: "parent",
                accent: .green,
                lyalyaState: .explaining,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 10,
                title: String(localized: "demo.step10.title"),
                subtitle: String(localized: "demo.step10.subtitle"),
                description: String(localized: "demo.step10.desc"),
                mascotText: String(localized: "demo.step10.mascot"),
                screenEmoji: "🏆",
                illustrationSymbol: "star.fill",
                highlightColor: "butter",
                accent: .gold,
                lyalyaState: .celebrating,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 11,
                title: String(localized: "demo.step11.title"),
                subtitle: String(localized: "demo.step11.subtitle"),
                description: String(localized: "demo.step11.desc"),
                mascotText: String(localized: "demo.step11.mascot"),
                screenEmoji: "💜",
                illustrationSymbol: "heart.fill",
                highlightColor: "primary",
                accent: .purple,
                lyalyaState: .encouraging,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 12,
                title: String(localized: "demo.step12.title"),
                subtitle: String(localized: "demo.step12.subtitle"),
                description: String(localized: "demo.step12.desc"),
                mascotText: String(localized: "demo.step12.mascot"),
                screenEmoji: "📡",
                illustrationSymbol: "wifi.slash",
                highlightColor: "primary",
                accent: .teal,
                lyalyaState: .waving,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 13,
                title: String(localized: "demo.step13.title"),
                subtitle: String(localized: "demo.step13.subtitle"),
                description: String(localized: "demo.step13.desc"),
                mascotText: String(localized: "demo.step13.mascot"),
                screenEmoji: "🛡️",
                illustrationSymbol: "lock.shield.fill",
                highlightColor: "mint",
                accent: .green,
                lyalyaState: .explaining,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 14,
                title: String(localized: "demo.step14.title"),
                subtitle: String(localized: "demo.step14.subtitle"),
                description: String(localized: "demo.step14.desc"),
                mascotText: String(localized: "demo.step14.mascot"),
                screenEmoji: "👨‍👩‍👧",
                illustrationSymbol: "person.2.fill",
                highlightColor: "parent",
                accent: .orange,
                lyalyaState: .waving,
                hasInteractive: false,
                actionTitle: nil
            ),
            DemoStep(
                id: 15,
                title: String(localized: "demo.step15.title"),
                subtitle: String(localized: "demo.step15.subtitle"),
                description: String(localized: "demo.step15.desc"),
                mascotText: String(localized: "demo.step15.mascot"),
                screenEmoji: "🎉",
                illustrationSymbol: "sparkles",
                highlightColor: "primary",
                accent: .primary,
                lyalyaState: .celebrating,
                hasInteractive: false,
                actionTitle: nil
            )
        ]
    }
    // swiftlint:enable function_body_length
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
