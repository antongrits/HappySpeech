import CoreVideo
import Foundation
import OSLog

// MARK: - ObjectHuntBusinessLogic

@MainActor
protocol ObjectHuntBusinessLogic: AnyObject {
    func loadRound(_ request: ObjectHuntModels.LoadRound.Request)
    func analyzeFrame(_ request: ObjectHuntModels.FrameAnalyzed.Request)
    func confirmMatch(_ request: ObjectHuntModels.CompleteRound.Request)
}

// MARK: - ObjectHuntInteractor

/// Бизнес-логика игры ObjectHunt.
///
/// Управляет тремя раундами:
///   Раунд 0: целевой звук из soundGroup[0]
///   Раунд 1: soundGroup[1]
///   Раунд 2: soundGroup[2]
///
/// Звуки выбираются из группы (шипящие/свистящие и т.д.).
/// После нахождения предмета — раунд завершается, ребёнок переходит к следующему.
/// Финальный score = (пройдено раундов / totalRounds).
@MainActor
final class ObjectHuntInteractor: ObjectHuntBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ObjectHuntPresentationLogic)?
    var router: (any ObjectHuntRoutingLogic)?

    private let detectionWorker: any ObjectDetectionWorkerProtocol

    // MARK: - State

    private var soundGroup: String = ""
    private var roundSounds: [String] = []
    private var currentRoundIndex: Int = 0
    private let totalRounds: Int = 3
    private var completedRounds: Int = 0
    private var isMatchLocked: Bool = false     // предотвращает двойной trigger при одном объекте

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ObjectHunt")

    // MARK: - Init

    init(detectionWorker: any ObjectDetectionWorkerProtocol) {
        self.detectionWorker = detectionWorker
    }

    // MARK: - loadRound

    func loadRound(_ request: ObjectHuntModels.LoadRound.Request) {
        self.soundGroup = request.soundGroup
        self.roundSounds = Self.soundsFor(group: request.soundGroup)
        self.currentRoundIndex = request.roundIndex
        self.isMatchLocked = false

        let targetSound = currentTarget()
        let prompt = String(localized: "object_hunt.find_sound \(targetSound)")
        let response = ObjectHuntModels.LoadRound.Response(
            targetSound: targetSound,
            promptText: prompt,
            roundIndex: request.roundIndex,
            totalRounds: totalRounds
        )
        logger.info("ObjectHunt: loadRound index=\(request.roundIndex) sound=\(targetSound)")
        presenter?.presentLoadRound(response)
    }

    // MARK: - analyzeFrame

    /// Вызывается каждую секунду из ObjectHuntView через Task.
    /// Делает async-запрос к ObjectDetectionWorker и передаёт результат в Presenter.
    func analyzeFrame(_ request: ObjectHuntModels.FrameAnalyzed.Request) {
        guard !isMatchLocked else { return }

        let matched = request.detectedObjects.first
        let response = ObjectHuntModels.FrameAnalyzed.Response(matchedObject: matched)

        if matched != nil {
            isMatchLocked = true
            logger.info("ObjectHunt: match found — \(matched?.russianLabel ?? "")")
        }

        presenter?.presentFrameAnalyzed(response)
    }

    // MARK: - confirmMatch

    /// Вызывается из View после того как Celebration-оверлей показан.
    func confirmMatch(_ request: ObjectHuntModels.CompleteRound.Request) {
        completedRounds += 1
        let isLast = completedRounds >= totalRounds

        let celebration = String(
            localized: "object_hunt.found \(request.matchedObject.russianLabel) \(request.matchedObject.sounds.first?.uppercased() ?? "")"
        )
        let response = ObjectHuntModels.CompleteRound.Response(
            celebrationMessage: celebration,
            isLastRound: isLast,
            roundIndex: request.roundIndex
        )
        logger.info("ObjectHunt: completeRound index=\(request.roundIndex) isLast=\(isLast)")
        presenter?.presentCompleteRound(response)

        if isLast {
            finishGame()
        }
    }

    // MARK: - Private

    private func finishGame() {
        let score = Float(completedRounds) / Float(totalRounds)
        let stars = starsFor(score: score)
        let summary = summaryText(stars: stars)
        let response = ObjectHuntModels.CompleteGame.Response(
            starsEarned: stars,
            score: score,
            summaryText: summary
        )
        logger.info("ObjectHunt: game complete score=\(score) stars=\(stars)")
        presenter?.presentCompleteGame(response)
    }

    private func currentTarget() -> String {
        guard roundSounds.indices.contains(currentRoundIndex) else {
            return roundSounds.first ?? "Ш"
        }
        return roundSounds[currentRoundIndex]
    }

    private func starsFor(score: Float) -> Int {
        switch score {
        case 0.9...:          return 3
        case 0.6..<0.9:       return 2
        case 0.3..<0.6:       return 1
        default:              return 1
        }
    }

    private func summaryText(stars: Int) -> String {
        switch stars {
        case 3: return String(localized: "object_hunt.summary.excellent")
        case 2: return String(localized: "object_hunt.summary.good")
        default: return String(localized: "object_hunt.summary.ok")
        }
    }

    // MARK: - Sound group mapping

    /// Возвращает первые `totalRounds` звуков из группы.
    private static func soundsFor(group: String) -> [String] {
        switch group {
        case "hissing":   return ["Ш", "Ж", "Ч"]
        case "whistling": return ["С", "З", "Ц"]
        case "sonorant":  return ["Р", "Л", "Р"]
        case "velar":     return ["К", "Г", "Х"]
        default:          return ["Ш", "С", "Р"]
        }
    }
}
