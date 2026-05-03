import Foundation
import OSLog
import WhisperKit

// MARK: - ASRTier

/// Уровни качества ASR.
/// Tier A — быстро, для детских упражнений в реальном времени.
/// Tier B — качественно, для сводок родителей (bundled whisper-base).
/// Tier C — максимум, скачивается по запросу специалиста.
public enum ASRTier: String, Sendable, CaseIterable {
    /// Tier A: whisper-tiny — быстрый, загружается on-demand (~150 MB).
    case kidOnDevice
    /// Tier B: whisper-base bundled в bundle приложения (~150 MB).
    case parentQuality
    /// Tier C: whisper-small — скачивается по запросу (~780 MB).
    case specialistQuality

    public var displayName: String {
        switch self {
        case .kidOnDevice:     return "Быстрый (ребёнок)"
        case .parentQuality:   return "Качественный (родитель)"
        case .specialistQuality: return "Максимальный (специалист)"
        }
    }
}

// MARK: - LiveASRService

/// WhisperKit-based ASR service.
///
/// Fallback chain:
///   1. Bundled whisper-base (Resources/Models/Whisper/whisper-base) — Tier B
///   2. Downloaded whisper-tiny — Tier A
///   3. Throws AppError.asrModelNotLoaded
///
/// `loadModel(tier:)` пытается загрузить указанный tier, автоматически
/// откатываясь к следующему доступному при ошибке.
public final class LiveASRService: ASRService, @unchecked Sendable {

    // MARK: - State

    nonisolated(unsafe) private var whisper: WhisperKit?
    nonisolated(unsafe) private var _isReady: Bool = false
    nonisolated(unsafe) private var _activeTier: ASRTier = .kidOnDevice

    public var isReady: Bool { _isReady }
    public var activeTier: ASRTier { _activeTier }

    // MARK: - Bundled model paths

    /// Путь к bundled whisper-base в Resources/Models/Whisper/whisper-base/
    private static var bundledBaseModelFolder: URL? {
        Bundle.main.url(
            forResource: "whisper-base",
            withExtension: nil,
            subdirectory: "Models/Whisper"
        )
    }

    /// Проверяет наличие обязательных файлов bundled модели.
    private static func isBundledBaseAvailable() -> Bool {
        guard let folder = bundledBaseModelFolder else { return false }
        let required = [
            "config.json",
            "AudioEncoder.mlmodelc",
            "TextDecoder.mlmodelc"
        ]
        return required.allSatisfy { name in
            FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
        }
    }

    // MARK: - Init

    public init() {}

    // MARK: - Load

    /// Загрузить модель для указанного tier.
    /// При ошибке автоматически откатывается: parentQuality → kidOnDevice.
    public func loadModel(tier: ASRTier = .parentQuality) async throws {
        HSLogger.asr.info("ASRService: loading tier=\(tier.rawValue)")

        switch tier {
        case .parentQuality:
            if await tryLoadBundledBase() {
                _activeTier = .parentQuality
                return
            }
            HSLogger.asr.warning("ASRService: bundled whisper-base unavailable, falling back to tiny")
            try await loadTiny()
            _activeTier = .kidOnDevice

        case .kidOnDevice:
            try await loadTiny()
            _activeTier = .kidOnDevice

        case .specialistQuality:
            // Tier C не поддерживается в offline-bundle, используем parentQuality
            HSLogger.asr.info("ASRService: specialistQuality requested, using parentQuality fallback")
            try await loadModel(tier: .parentQuality)
        }
    }

    /// Устаревший вход (обратная совместимость) — загружает Tier A (tiny).
    public func loadModel() async throws {
        try await loadModel(tier: .parentQuality)
    }

    // MARK: - Transcribe

    public func transcribe(url: URL) async throws -> ASRResult {
        guard let whisper, _isReady else {
            throw AppError.asrModelNotLoaded
        }
        let options = DecodingOptions(
            task: .transcribe,
            language: "ru",
            temperatureFallbackCount: 2
        )
        let results = try await whisper.transcribe(audioPath: url.path, decodeOptions: options)
        let texts = results.compactMap { $0.text }
        let text = texts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let confidence: Double
        if let firstSegment = results.first?.segments.first {
            confidence = min(1.0, exp(Double(firstSegment.avgLogprob)))
        } else {
            confidence = 0.8
        }
        let timestamps: [ASRResult.WordTimestamp] = results.first?.segments.flatMap { seg -> [ASRResult.WordTimestamp] in
            guard let words = seg.words else { return [] }
            return words.map { w in
                ASRResult.WordTimestamp(
                    word: w.word,
                    startTime: Double(w.start),
                    endTime: Double(w.end)
                )
            }
        } ?? []
        return ASRResult(transcript: text, confidence: confidence, wordTimestamps: timestamps)
    }

    // MARK: - Private load helpers

    private func tryLoadBundledBase() async -> Bool {
        guard Self.isBundledBaseAvailable(),
              let folder = Self.bundledBaseModelFolder else {
            HSLogger.asr.info("ASRService: bundled whisper-base not found in bundle")
            return false
        }
        do {
            HSLogger.asr.info("ASRService: loading bundled whisper-base from \(folder.path)")
            let config = WhisperKitConfig(modelFolder: folder.path)
            let kit = try await WhisperKit(config)
            whisper = kit
            _isReady = true
            HSLogger.asr.info("ASRService: whisper-base (bundled) ready — Tier B")
            return true
        } catch {
            HSLogger.asr.error("ASRService: bundled whisper-base load failed: \(error.localizedDescription)")
            return false
        }
    }

    private func loadTiny() async throws {
        HSLogger.asr.info("ASRService: loading whisper-tiny (on-demand)")
        let kit = try await WhisperKit(model: "openai/whisper-tiny", verbose: false)
        whisper = kit
        _isReady = true
        HSLogger.asr.info("ASRService: whisper-tiny ready — Tier A")
    }
}
