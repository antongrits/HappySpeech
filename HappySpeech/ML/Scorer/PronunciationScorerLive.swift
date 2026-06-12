import Accelerate
@preconcurrency import AVFoundation
import CoreML
import Foundation
import OSLog

// MARK: - LivePronunciationScorerService

/// On-device pronunciation scorer (контракт ``PronunciationScorerService``),
/// работающий поверх четырёх пофонемных Core ML моделей.
///
/// Block C v23: ранее этот сервис искал единый `PronunciationScorer.mlpackage`,
/// которого в бандле НЕТ (есть только `PronunciationScorer_{whistling,hissing,sonants,velar}.mlpackage`),
/// поэтому `loadModel()`/`score()` всегда бросали `mlModelNotFound` и on-device
/// скоринг в проде не работал. Теперь сервис — тонкий адаптер поверх рабочего
/// ``LivePronunciationScorer`` (actor, вход `mfcc[1,40,150]` → `output[1,2]` logits),
/// который выбирает нужную модель по группе звука.
///
/// **Маппинг звука → модели:** `targetSound` (буква, напр. "С", "Рь") приводится к
/// ``PronunciationPhonemeGroup``. Если для звука нет соответствующей группы/модели —
/// возвращается ``PronunciationScore/notScored`` (graceful, без throw): один
/// отсутствующий звук не должен валить весь распознающий пайплайн.
public final class LivePronunciationScorerService: PronunciationScorerService, @unchecked Sendable {

    private let scorer: LivePronunciationScorer
    nonisolated(unsafe) private var _isModelLoaded: Bool = false
    private let loadedLock = NSLock()

    public var isModelLoaded: Bool {
        loadedLock.lock(); defer { loadedLock.unlock() }
        return _isModelLoaded
    }

    public init() {
        self.scorer = LivePronunciationScorer()
    }

    // MARK: - Load Model

    /// Прогрев: проверяет, что в бандле есть хотя бы одна из четырёх пофонемных
    /// моделей. Бросает `mlModelNotFound` только если НИ ОДНОЙ модели нет
    /// (полностью невалидный бандл). Отсутствие отдельной группы — не ошибка.
    public func loadModel() async throws {
        let available = PronunciationPhonemeGroup.allCases.filter { group in
            MLBundle.compiledModelURL(name: "PronunciationScorer_\(group.rawValue)") != nil
        }
        guard !available.isEmpty else {
            loadedLock.withLock { _isModelLoaded = false }
            HSLogger.ml.error("PronunciationScorer: ни одной пофонемной модели нет в бандле — inference недоступен")
            throw AppError.mlModelNotFound("PronunciationScorer_*")
        }
        loadedLock.withLock { _isModelLoaded = true }
        HSLogger.ml.info("PronunciationScorer: доступно моделей по группам — \(available.map(\.rawValue).joined(separator: ", "))")
    }

    // MARK: - Score

    public func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore {
        // Звук без поддержанной группы (напр. гласные/мягкие знаки) — не оцениваем,
        // но и не валим пайплайн: возвращаем notScored.
        guard let group = Self.phonemeGroup(for: targetSound) else {
            HSLogger.ml.debug("PronunciationScorer: для звука '\(targetSound, privacy: .public)' нет группы — notScored")
            return .notScored
        }

        // Если модель именно этой группы отсутствует в бандле — graceful notScored.
        guard MLBundle.compiledModelURL(name: "PronunciationScorer_\(group.rawValue)") != nil else {
            HSLogger.ml.warning("PronunciationScorer: модель группы '\(group.rawValue, privacy: .public)' отсутствует — notScored")
            return .notScored
        }

        let buffer = try Self.loadBuffer(from: audioURL)
        let result = try await scorer.score(audio: buffer, phonemeGroup: group)
        return PronunciationScore(rawValue: Double(result.correctProbability))
    }

    // MARK: - Private: Sound → Group Mapping

    /// Сопоставляет целевой звук (буква русского алфавита, в любом регистре,
    /// с мягким знаком или без) одной из четырёх обученных групп.
    /// Возвращает `nil`, если звук не входит ни в одну группу (модели нет).
    static func phonemeGroup(for targetSound: String) -> PronunciationPhonemeGroup? {
        // Берём первую значимую букву (Рь/Ль → Р/Л), приводим к верхнему регистру.
        let normalized = targetSound
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let first = normalized.first else { return nil }
        switch first {
        case "С", "З", "Ц":           return .whistling
        case "Ш", "Ж", "Ч", "Щ":      return .hissing
        case "Р", "Л":                return .sonants
        case "К", "Г", "Х":           return .velar
        default:                       return nil
        }
    }

    // MARK: - Private: Audio Loading

    /// Загружает аудио-файл в `AVAudioPCMBuffer` (формат файла). Ресемплинг до 16 кГц
    /// и нормализация длины выполняются внутри `MFCCExtractor.extract`.
    static func loadBuffer(from url: URL) throws -> AVAudioPCMBuffer {
        let audioFile = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else { throw AppError.audioFormatUnsupported }
        try audioFile.read(into: buffer)
        return buffer
    }
}
