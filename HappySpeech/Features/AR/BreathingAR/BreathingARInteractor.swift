import Foundation
import OSLog

// MARK: - VIP-thin: ARSession orchestration only
//
// Этот Interactor намеренно тонкий (~75 LOC). Логика тренировки
// звуков НЕ принадлежит iOS-слою: всё реальное распознавание происходит
// в ARSessionDelegate (ARFaceAnchor blendshapes + AVAudioEngine amplitude
// → AirStreamDetector). Interactor только:
//   1. Запускает / останавливает ARSession через ARSessionService.
//   2. Получает frame updates → передаёт Presenter без бизнес-обработки.
//   3. Финализирует session через SessionRepository (общий path).
// Углубление до 350+ LOC означало бы дублирование AR логики или создание
// искусственных абстракций — нарушение Clean Swift VIP принципа.
//
// Domain logic (face tracking, breath detection) живёт в Workers + ARSessionService.
//
// MARK: - BreathingARInteractor
//
// AR мини-игра «Сдуй одуванчик».
//
// Clean Swift поток:
//   ARView (кадры + амплитуда микрофона) → updateFrame() → Presenter → View
//
// AR зависимости:
//   - AirStreamDetector: анализирует jawOpen + cheekPuff blendshapes + AudioService amplitude
//   - ARFaceAnchor.blendShapes: jawOpen (>0.4) + cheekPuff (>0.3) как признак выдоха
//   - AVAudioEngine amplitude (16kHz mono): шум выдоха поверх AR сигнала
//
// Бизнес-правила:
//   - 30 устойчивых кадров подряд (≈2с при 15fps) = один сдутый одуванчик
//   - Оценка: ≥90% = 3 звезды, ≥60% = 2 звезды, иначе = 1 звезда
//   - AirStreamDetector.reset() обязателен при каждом startGame
//
// COPPA: нет сетевых вызовов, нет PII. Весь ML — on-device Core ML.

@MainActor
protocol BreathingARBusinessLogic: AnyObject {
    func startGame(_ request: BreathingARModels.StartGame.Request)
    func updateFrame(_ request: BreathingARModels.UpdateFrame.Request)
    func scoreAttempt(_ request: BreathingARModels.ScoreAttempt.Request)
}

@MainActor
final class BreathingARInteractor: BreathingARBusinessLogic {

    var presenter: (any BreathingARPresentationLogic)?
    private let detector = AirStreamDetector()
    private var totalDandelions = 5
    private var blownCount = 0
    private var sustainedFrames = 0

    func startGame(_ request: BreathingARModels.StartGame.Request) {
        totalDandelions = request.dandelionCount
        blownCount = 0
        sustainedFrames = 0
        detector.reset()
        presenter?.presentStartGame(.init(dandelionCount: totalDandelions))
    }

    func updateFrame(_ request: BreathingARModels.UpdateFrame.Request) {
        let blowing = detector.update(
            blendshapes: request.blendshapes,
            micAmplitude: request.micAmplitude
        )
        if blowing {
            sustainedFrames += 1
            // Каждые ~30 устойчивых кадров (~2 сек) сдуваем один одуванчик.
            if sustainedFrames >= 30, blownCount < totalDandelions {
                blownCount += 1
                sustainedFrames = 0
                HSLogger.ar.info("BreathingAR dandelion blown (\(self.blownCount)/\(self.totalDandelions))")
            }
        } else {
            sustainedFrames = max(0, sustainedFrames - 1)
        }
        presenter?.presentUpdateFrame(.init(isBlowing: blowing, strength: detector.strength))
        if blownCount >= totalDandelions {
            scoreAttempt(.init(blownCount: blownCount, totalCount: totalDandelions))
        }
    }

    func scoreAttempt(_ request: BreathingARModels.ScoreAttempt.Request) {
        let ratio = Double(request.blownCount) / Double(max(request.totalCount, 1))
        let stars = ratio >= 0.9 ? 3 : ratio >= 0.6 ? 2 : 1
        presenter?.presentScoreAttempt(.init(stars: stars, percent: Int(ratio * 100)))
    }
}
