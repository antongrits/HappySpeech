import Foundation
import OSLog

// MARK: - MLModelWarmupServiceProtocol

/// Прогревает критичные Core ML модели заранее, во время онбординга, чтобы первая
/// игровая сессия не тратила секунды на холодную загрузку.
///
/// Plan v21 Block V — вызывается на шаге `.permissions` `OnboardingFlowView`
/// (после показа запроса микрофона, до перехода в `.modelDownload`).
///
/// ## Что прогревается
/// - ``PronunciationScorerService`` — `loadModel()` (Conv1D, 0.18 MB на группу звуков).
/// - ``ASRService`` — `loadModel(tier: .kidOnDevice)` (whisper-tiny, безопасный bundle path).
/// - VAD — фабрика `makeVAD()` пробует загрузить `SileroVAD.mlpackage` или мягко падает
///   в `AmplitudeVAD`. Сам факт первого вызова инициализирует CoreML actor.
///
/// Все три задачи выполняются параллельно через `async let`. Ошибки логируются
/// и проглатываются — warm-up не блокирует онбординг.
///
/// ## Использование
/// ```swift
/// .task {
///     if display.currentStep == .permissions {
///         await container.mlWarmupService.warmUp()
///     }
/// }
/// ```
public protocol MLModelWarmupServiceProtocol: Sendable {
    /// Прогрев критичных моделей параллельно. Не бросает — все ошибки логируются.
    func warmUp() async
}

// MARK: - LiveMLModelWarmupService

/// Real-параллельный прогрев on-device моделей. Идемпотентен: повторные вызовы
/// просто переиспользуют уже загруженные модели (внутри сервисов есть свои гарды).
public actor LiveMLModelWarmupService: MLModelWarmupServiceProtocol {

    private let pronunciation: any PronunciationScorerService
    private let asr: any ASRService
    private var didWarmUp = false

    public init(
        pronunciation: any PronunciationScorerService,
        asr: any ASRService
    ) {
        self.pronunciation = pronunciation
        self.asr = asr
    }

    public func warmUp() async {
        guard !didWarmUp else {
            HSLogger.ml.debug("MLModelWarmupService.warmUp: already warm, skipping")
            return
        }
        didWarmUp = true

        HSLogger.ml.info("MLModelWarmupService.warmUp: starting parallel preload")
        let started = Date()

        // Параллельно: Pronunciation + ASR (kid tier) + VAD factory.
        // VAD — отдельный fire-and-forget Task, т.к. makeVAD() — global func
        // и не должен блокировать main warm-up.
        async let pronunciationDone: Void = warmPronunciation()
        async let asrDone: Void = warmASR()
        async let vadDone: Void = warmVAD()

        _ = await (pronunciationDone, asrDone, vadDone)

        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        HSLogger.ml.info("MLModelWarmupService.warmUp: completed in \(elapsedMs)ms")
    }

    // MARK: - Private warmers

    private func warmPronunciation() async {
        do {
            try await pronunciation.loadModel()
            HSLogger.ml.info("MLModelWarmupService: PronunciationScorer warm")
        } catch {
            HSLogger.ml.warning(
                "MLModelWarmupService: PronunciationScorer warm-up failed: \(error.localizedDescription)"
            )
        }
    }

    private func warmASR() async {
        do {
            // Kid tier (whisper-tiny) — самый лёгкий путь для онбординга.
            // parentQuality и specialistQuality прогреваются on-demand в их экранах.
            try await asr.loadModel(tier: .kidOnDevice)
            HSLogger.ml.info("MLModelWarmupService: ASR (kid tier) warm")
        } catch {
            HSLogger.ml.warning(
                "MLModelWarmupService: ASR warm-up failed: \(error.localizedDescription)"
            )
        }
    }

    private func warmVAD() async {
        // makeVAD() сам пробует CoreML, падает на AmplitudeVAD при отсутствии модели.
        // Возвращаемый instance отбрасываем — VAD создаётся on-demand в каждом
        // вызывающем сайте; цель warm-up — лишь инициализировать CoreML runtime.
        _ = await makeVAD()
        HSLogger.ml.info("MLModelWarmupService: VAD factory warm")
    }
}

// MARK: - MockMLModelWarmupService

/// Мок для Preview/Tests — мгновенный no-op.
public struct MockMLModelWarmupService: MLModelWarmupServiceProtocol {
    public init() {}
    public func warmUp() async {
        // Intentional no-op.
    }
}
