import Foundation
import os.signpost
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
/// - ``ASRService`` — `loadModel(tier: .kidOnDevice)` грузит **bundled whisper-base**
///   из `Resources/Models/Whisper/whisper-base/` по локальному пути (полностью offline,
///   без сетевой загрузки с HuggingFace).
/// - VAD — фабрика `makeVAD(preferFluidAudio:)` пробует поднять Silero v6 на ANE через
///   FluidAudio (`FluidAudioVADService`). **Важно:** FluidAudio скачивает CoreML-модель
///   Silero v6 с HuggingFace при первом запуске (offline-старт без кэша → инициализация
///   падает), поэтому фабрика мягко откатывается на детерминированный `AmplitudeVAD`
///   (адаптивный амплитудный детектор, ~88–92% на чистой речи, без модели и без сети).
///   `AmplitudeVAD` — фактический offline-first путь VAD; Silero v6 — апгрейд при наличии
///   кэша/сети. Прогрев инициализирует CoreML runtime.
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

        // Plan v22 Block 0.5 — MLWarmup interval (Instruments Points of Interest).
        os_signpost(.begin,
                    log: HSSignpost.pointsOfInterest,
                    name: "MLWarmup")
        defer {
            os_signpost(.end,
                        log: HSSignpost.pointsOfInterest,
                        name: "MLWarmup")
        }

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
            // Kid tier грузит bundled whisper-base (offline, лёгкая on-device модель) —
            // самый лёгкий путь для онбординга. specialistQuality (whisper-small)
            // прогревается on-demand в экране специалиста.
            try await asr.loadModel(tier: .kidOnDevice)
            HSLogger.ml.info("MLModelWarmupService: ASR (kid tier) warm")
        } catch {
            HSLogger.ml.warning(
                "MLModelWarmupService: ASR warm-up failed: \(error.localizedDescription)"
            )
        }
    }

    private func warmVAD() async {
        // Пробуем поднять Silero v6 (FluidAudio, ANE). FluidAudio скачивает модель с
        // HuggingFace при первом запуске; без кэша/сети инициализация падает и фабрика
        // мягко откатывается на детерминированный AmplitudeVAD (offline-first путь) —
        // warm-up не падает. Возвращаемый instance отбрасываем; цель warm-up —
        // инициализировать CoreML runtime.
        let vad = await makeVAD(preferFluidAudio: true)
        HSLogger.ml.info("MLModelWarmupService: VAD warm (\(String(describing: type(of: vad))))")
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
