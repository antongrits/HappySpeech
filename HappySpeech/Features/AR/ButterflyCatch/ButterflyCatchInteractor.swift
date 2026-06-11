import Foundation
import OSLog

// MARK: - VIP-thin: ARSession orchestration only
//
// Этот Interactor намеренно тонкий (~70 LOC). Логика тренировки
// звуков НЕ принадлежит iOS-слою: всё реальное распознавание происходит
// в ARSessionDelegate (ARFaceAnchor blendshapes / TonguePostureClassifier
// Core ML inference). Interactor только:
//   1. Запускает / останавливает ARSession через ARSessionService.
//   2. Получает frame updates → передаёт Presenter без бизнес-обработки.
//   3. Финализирует session через SessionRepository (общий path).
// Углубление до 350+ LOC означало бы дублирование AR логики или создание
// искусственных абстракций — нарушение Clean Swift VIP принципа.
//
// Domain logic (face tracking, score computation) живёт в Workers + ARSessionService.
//
// MARK: - ButterflyCatchInteractor
//
// AR мини-игра «Поймай бабочку языком».
//
// Логопедическая основа (Фомичёва, Правдина, Коноваленко): ребёнок «ловит»
// бабочку, ВЫСОВЫВАЯ и ПОДНИМАЯ язык — это игровая упаковка базовых
// артикуляционных упражнений подготовительного этапа над сонорами (Р, Л) и
// шипящими (Ш, Ж):
//   - .tongueUp  — широкий язык поднят к верхней губе при открытом рте
//                  («Вкусное варенье» / «Чашечка»);
//   - .shoveling — широкий распластанный язык высунут наружу при почти
//                  закрытом рте («Лопаточка»).
// Обе позы опираются на реальный blendshape `tongueOut` (ARFaceAnchor),
// а не на положение губ. Это приводит игру в соответствие с описанием в работе
// (ловля языком, tongueOut), где раньше код ловил позы губ (smile/pucker).
//
// Clean Swift поток:
//   View (ARKit frame) → Interactor → Presenter → ViewModel → View
//
// AR зависимости:
//   - TonguePostureClassifier: Core ML inference на ARFaceAnchor.blendShapes
//     (tongueOut, jawOpen и др.). Обе целевые позы есть в ML-словаре.
//   - ARSCNViewDelegate: View передаёт blendshapes через scoreAttempt() на каждый кадр
//
// Бизнес-правила:
//   - Бабочка «поймана» при confidence(blendshapes, posture) >= 0.6
//   - Позы из цикла: tongueUp / shoveling (подъём и высовывание языка)
//   - Позиции бабочек рандомизируются в диапазоне [0.1..0.9] × [0.15..0.45] экрана
//
// COPPA: нет сетевых вызовов, нет PII. Весь ML — on-device Core ML.

@MainActor
protocol ButterflyCatchBusinessLogic: AnyObject {
    func startGame(_ request: ButterflyCatchModels.StartGame.Request)
    func spawnButterfly(_ request: ButterflyCatchModels.SpawnButterfly.Request)
    func scoreAttempt(_ request: ButterflyCatchModels.ScoreAttempt.Request)
}

@MainActor
final class ButterflyCatchInteractor: ButterflyCatchBusinessLogic {

    var presenter: (any ButterflyCatchPresentationLogic)?

    /// Core ML классификатор поз как основной канал (graceful fallback на rule-based).
    private let classifier: any ArticulationConfidenceProviding
    private var totalCaught = 0
    private var activeButterflies: [UUID: ButterflyCatchModels.Butterfly] = [:]

    /// Прод-дефолт — Core ML классификатор; тесты/preview передают rule-based для детерминизма.
    init(classifier: any ArticulationConfidenceProviding = TonguePostureClassifierML()) {
        self.classifier = classifier
    }

    func startGame(_ request: ButterflyCatchModels.StartGame.Request) {
        totalCaught = 0
        activeButterflies.removeAll()
        presenter?.presentStartGame(.init(totalButterflies: 0, durationSec: request.durationSec))
    }

    func spawnButterfly(_ request: ButterflyCatchModels.SpawnButterfly.Request) {
        // Только «языковые» позы: высовывание и подъём языка.
        // Это профильные артикуляционные упражнения для соноров и шипящих.
        let postures: [ArticulationPosture] = [.tongueUp, .shoveling]
        let posture = postures.randomElement() ?? .tongueUp
        let butterfly = ButterflyCatchModels.Butterfly(
            id: UUID(),
            position: CGPoint(x: .random(in: 0.1...0.9), y: .random(in: 0.15...0.45)),
            direction: ButterflyCatchModels.Direction.allCases.randomElement() ?? .left,
            targetPosture: posture
        )
        activeButterflies[butterfly.id] = butterfly
        presenter?.presentSpawnButterfly(.init(butterfly: butterfly))
    }

    func scoreAttempt(_ request: ButterflyCatchModels.ScoreAttempt.Request) {
        guard let butterfly = activeButterflies[request.butterflyId] else { return }
        let confidence = classifier.confidence(request.blendshapes, for: butterfly.targetPosture)
        let caught = confidence >= 0.6
        if caught {
            totalCaught += 1
            activeButterflies.removeValue(forKey: request.butterflyId)
            HSLogger.ar.info("Butterfly caught! total=\(self.totalCaught)")
        }
        presenter?.presentScoreAttempt(.init(caught: caught, totalCaught: totalCaught))
    }
}
