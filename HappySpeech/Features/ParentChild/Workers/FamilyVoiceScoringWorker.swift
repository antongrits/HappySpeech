import Accelerate
import AVFoundation
import Foundation
import OSLog

// MARK: - FamilyVoiceScoringOutcome

/// Результат оценки попытки ребёнка в семейном контуре.
///
/// `isApproximate` честно сигнализирует, что числовая оценка получена
/// энергетической эвристикой (RMS), а НЕ анализом произношения. UI обязан
/// показать пользователю соответствующую пометку, чтобы не выдавать
/// приблизительную громкость за реальную оценку чёткости звука.
struct FamilyVoiceScoringOutcome: Sendable, Equatable {

    /// Оценка в диапазоне `[0, 1]`.
    let value: Float

    /// `true` → значение получено RMS-эвристикой (нет ML-анализа произношения).
    let isApproximate: Bool

    static let zero = FamilyVoiceScoringOutcome(value: 0, isApproximate: true)
}

// MARK: - FamilyVoiceScoringWorker

/// Compares child pronunciation against parent reference recording.
///
/// Контур: родительский / семейный (parent-facing, за ParentalGate). Здесь
/// допустима более тяжёлая, точная оценка, чем в kid-контуре игры.
///
/// Порядок путей (от точного к запасному):
///   1. **Ensemble Tier B** — взвешенное голосование Whisper + PhonemeClassifier +
///      PronunciationScorer (+ Wav2Vec2 CTC). Точнее всего; используется, если
///      `ensembleASR` подключён. COPPA-ok: parent-контур.
///   2. **PronunciationScorer** — одиночная CoreML-модель по группе звука.
///   3. **RMS heuristic** — энергетический фолбэк. Считает РЕАЛЬНУЮ нормированную
///      громкость записи (не hash) и помечает результат как приблизительный
///      (`isApproximate = true`), потому что произношение тут не анализируется.
final class FamilyVoiceScoringWorker: Sendable {

    private let pronunciationScorer: (any PronunciationScorerService)?
    /// Опциональный ансамблевый ASR (Tier B). Подключается из родительского
    /// контура для более точной оценки. `nil` → используется одиночный scorer.
    private let ensembleASR: (any EnsembleASRServiceProtocol)?
    private let logger = Logger(subsystem: "com.happyspeech", category: "FamilyVoiceScoringWorker")

    init(
        pronunciationScorer: (any PronunciationScorerService)? = nil,
        ensembleASR: (any EnsembleASRServiceProtocol)? = nil
    ) {
        self.pronunciationScorer = pronunciationScorer
        self.ensembleASR = ensembleASR
    }

    // MARK: - Public API

    /// Scores child's attempt against the reference word.
    /// Возвращает `FamilyVoiceScoringOutcome`: значение `[0, 1]` + флаг `isApproximate`.
    func score(
        childAudioPath: String,
        referenceWord: String
    ) async -> FamilyVoiceScoringOutcome {
        // Determine sound group for ML scorer routing
        let group = soundGroup(for: referenceWord)

        // Путь 1: Ensemble Tier B (наиболее точный). Только parent-контур.
        if let ensembleASR {
            do {
                let audioURL = try FamilyVoiceRecorderWorker.resolveFilePath(childAudioPath)
                let result = try await ensembleASR.recognize(
                    url: audioURL,
                    tier: .b,
                    expectedWord: referenceWord.lowercased(),
                    targetSound: group ?? ""
                )
                logger.info("Ensemble Tier B score for '\(referenceWord)': conf=\(result.confidence) ph=\(result.phonemeAccuracy)")
                // Для семейного UX используем phonemeAccuracy (calibrated 0…1),
                // а если он нулевой (нет targetSound) — общую уверенность ансамбля.
                let value = result.phonemeAccuracy > 0 ? result.phonemeAccuracy : result.confidence
                return FamilyVoiceScoringOutcome(value: max(0, min(1, value)), isApproximate: false)
            } catch {
                logger.warning("Ensemble Tier B failed, falling back to single scorer: \(error)")
            }
        }

        // Путь 2: одиночный PronunciationScorer.
        if let scorer = pronunciationScorer, let targetSound = group {
            do {
                let audioURL = try FamilyVoiceRecorderWorker.resolveFilePath(childAudioPath)
                let result = try await scorer.score(
                    audioURL: audioURL,
                    targetSound: targetSound
                )
                logger.info("ML score for '\(referenceWord)': \(result.value)")
                return FamilyVoiceScoringOutcome(value: Float(result.value), isApproximate: false)
            } catch {
                logger.warning("ML scorer failed, falling back to RMS heuristic: \(error)")
            }
        }

        // Путь 3: RMS heuristic — реальная нормированная громкость записи.
        // Помечается approximate: произношение здесь НЕ анализируется.
        let value = await rmsHeuristicScore(childAudioPath: childAudioPath)
        logger.info("RMS heuristic (approximate) score for '\(referenceWord)': \(value)")
        return FamilyVoiceScoringOutcome(value: value, isApproximate: true)
    }

    // MARK: - Sound group mapping

    private func soundGroup(for word: String) -> String? {
        let whistling = ["с", "з", "ц"]
        let hissing = ["ш", "ж", "ч", "щ"]
        let sonants = ["р", "л"]
        let velar = ["к", "г", "х"]

        let lower = word.lowercased()
        if whistling.contains(where: { lower.contains($0) }) { return "whistling" }
        if hissing.contains(where: { lower.contains($0) }) { return "hissing" }
        if sonants.contains(where: { lower.contains($0) }) { return "sonants" }
        if velar.contains(where: { lower.contains($0) }) { return "velar" }
        return nil
    }

    // MARK: - RMS heuristic fallback (реальная энергия сигнала)

    /// Энергетическая эвристика: измеряет РЕАЛЬНУЮ среднеквадратичную громкость
    /// (RMS) записи через PCM-семплы и нормирует её в диапазон уверенного
    /// «есть осмысленная речь» `[0, 1]`. Это НЕ оценка произношения — лишь
    /// прокси наличия и силы голосового сигнала, поэтому вызывающий помечает
    /// результат как `isApproximate`.
    ///
    /// Калибровка (типичная речь ребёнка на встроенный микрофон 16 kHz):
    ///   • RMS ≲ −45 dBFS (почти тишина) → ~0
    ///   • RMS ≈ −12 dBFS (уверенная речь) → ~1
    private func rmsHeuristicScore(childAudioPath: String) async -> Float {
        do {
            let url = try FamilyVoiceRecorderWorker.resolveFilePath(childAudioPath)
            let rmsDBFS = try Self.measureRMSdBFS(url: url)
            // Линейная нормировка по dBFS: [-45, -12] → [0, 1].
            let lower: Float = -45
            let upper: Float = -12
            let normalized = (rmsDBFS - lower) / (upper - lower)
            return max(0, min(1, normalized))
        } catch {
            logger.warning("RMS heuristic: cannot measure energy — \(error)")
            return 0
        }
    }

    /// Читает аудиофайл, сводит в моно и возвращает RMS в dBFS (−∞…0).
    private static func measureRMSdBFS(url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return -Float.infinity
        }
        try file.read(into: buffer)
        guard let channelData = buffer.floatChannelData else { return -Float.infinity }

        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return -Float.infinity }

        // Сводим каналы в моно и считаем сумму квадратов через vDSP.
        var sumOfSquares: Float = 0
        for channel in 0..<channels {
            var channelSquareSum: Float = 0
            vDSP_measqv(channelData[channel], 1, &channelSquareSum, vDSP_Length(frames))
            sumOfSquares += channelSquareSum
        }
        let meanSquare = sumOfSquares / Float(channels)
        let rms = sqrt(meanSquare)
        guard rms > 0 else { return -Float.infinity }
        // dBFS относительно полной шкалы (1.0).
        return 20 * log10(rms)
    }
}
