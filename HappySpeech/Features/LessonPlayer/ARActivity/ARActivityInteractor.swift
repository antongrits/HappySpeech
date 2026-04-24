import Foundation
import OSLog

// MARK: - ARActivityBusinessLogic

@MainActor
protocol ARActivityBusinessLogic: AnyObject {
    func loadActivity(_ request: ARActivityModels.LoadActivity.Request)
    func startActivity(_ request: ARActivityModels.StartActivity.Request)
    func completeActivity(_ request: ARActivityModels.CompleteActivity.Request)
}

// MARK: - ARActivityInteractor

/// Бизнес-логика ARActivity: smart routing (какой AR-экран открыть),
/// подсчёт звёзд по итоговому score и подготовка финального сообщения.
@MainActor
final class ARActivityInteractor: ARActivityBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ARActivityPresentationLogic)?
    var router: (any ARActivityRoutingLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ARActivity")

    // MARK: - State

    private var currentRequest: ARActivityModels.LoadActivity.Request?
    private var currentActivityType: ARActivityType = .storyQuest

    // MARK: - Smart routing

    /// Определяет подходящий AR-экран по группе звуков и стадии коррекции.
    /// Правила:
    ///   - sonants / velar → всегда `mirror` (артикуляционные упражнения).
    ///   - whistling / hissing → на этапе isolated/syllables тоже `mirror`,
    ///     далее (слова и выше) — `storyQuest`.
    ///   - Пустая группа или неизвестное значение → `storyQuest` (default).
    func resolveActivityType(soundGroup: String, stage: String) -> ARActivityType {
        switch soundGroup {
        case "sonants", "sonorant", "velar":
            return .mirror
        case "whistling", "hissing":
            if stage == "isolated" || stage == "syllable" || stage == "syllables" {
                return .mirror
            }
            return .storyQuest
        default:
            return .storyQuest
        }
    }

    /// Оценочная длительность упражнения в минутах.
    private func estimatedMinutes(for type: ARActivityType) -> Int {
        switch type {
        case .mirror:     return 3
        case .storyQuest: return 5
        }
    }

    /// Подсчёт звёзд по score.
    /// Пороги: 0.9 → 3, 0.7 → 2, 0.5 → 1, иначе 0.
    private func starsFor(score: Float) -> Int {
        let clamped = max(0, min(1, score))
        if clamped >= 0.9 { return 3 }
        if clamped >= 0.7 { return 2 }
        if clamped >= 0.5 { return 1 }
        return 0
    }

    private func messageFor(stars: Int, childName: String) -> String {
        let name = childName.isEmpty ? String(localized: "Молодец") : childName
        switch stars {
        case 3: return String(localized: "Превосходно, \(name)!")
        case 2: return String(localized: "Отличная работа, \(name)!")
        case 1: return String(localized: "Хорошо, \(name)! Можно ещё лучше.")
        default: return String(localized: "Попробуй ещё раз, \(name).")
        }
    }

    // MARK: - loadActivity

    func loadActivity(_ request: ARActivityModels.LoadActivity.Request) {
        currentRequest = request
        let activityType = resolveActivityType(
            soundGroup: request.soundGroup,
            stage: request.stage
        )
        currentActivityType = activityType

        let description: String
        let icon: String
        switch activityType {
        case .mirror:
            description = String(
                localized: "Посмотри в камеру и повтори движение губ. Зеркало подскажет, когда получится."
            )
            icon = "camera.fill"
        case .storyQuest:
            description = String(
                localized: "Ляля расскажет историю. Произнеси слово со звуком чётко и ясно."
            )
            icon = "star.fill"
        }

        let response = ARActivityModels.LoadActivity.Response(
            activityType: activityType,
            description: description,
            iconSystemName: icon,
            estimatedMinutes: estimatedMinutes(for: activityType),
            targetSound: request.targetSound
        )
        logger.info("ARActivity loaded: type=\(activityType.rawValue) sound=\(request.targetSound) stage=\(request.stage)")
        presenter?.presentLoadActivity(response)
    }

    // MARK: - startActivity

    func startActivity(_ request: ARActivityModels.StartActivity.Request) {
        currentActivityType = request.activityType
        let response = ARActivityModels.StartActivity.Response(activityType: request.activityType)

        switch request.activityType {
        case .mirror:
            router?.routeToARMirror()
        case .storyQuest:
            router?.routeToARStoryQuest()
        }

        logger.info("ARActivity started: type=\(request.activityType.rawValue)")
        presenter?.presentStartActivity(response)
    }

    // MARK: - completeActivity

    func completeActivity(_ request: ARActivityModels.CompleteActivity.Request) {
        let stars = starsFor(score: request.score)
        let message = messageFor(
            stars: stars,
            childName: currentRequest?.childName ?? ""
        )
        let response = ARActivityModels.CompleteActivity.Response(
            score: request.score,
            starsEarned: stars,
            message: message
        )
        logger.info("ARActivity completed: score=\(request.score) stars=\(stars) attempts=\(request.attempts)")
        presenter?.presentCompleteActivity(response)
    }
}
