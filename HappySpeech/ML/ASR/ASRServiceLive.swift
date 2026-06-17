import Foundation
import OSLog
import WhisperKit

// MARK: - LiveASRService

/// WhisperKit-based ASR service.
///
/// **Полностью offline-first.** Все модели загружаются из bundle приложения
/// (`Resources/Models/Whisper/`) по локальному пути через `WhisperKitConfig.modelFolder`
/// — никаких сетевых загрузок с HuggingFace. В bundle присутствуют:
///   - `whisper-base` (~140 MB) — лёгкая on-device модель;
///   - `whisper-small` (~460 MB) — максимальное качество для специалиста.
///
/// Tier → bundled-модель:
///   - `.kidOnDevice`       → whisper-base (offline), fallback → whisper-small
///   - `.parentQuality`     → whisper-base (offline), fallback → whisper-small
///   - `.specialistQuality` → whisper-small (offline), fallback → whisper-base
///
/// Если ни одна bundled-модель недоступна — бросается `AppError.asrModelNotLoaded`
/// (сеть НЕ задействуется ни на одном пути).
///
/// `loadModel(tier:)` пытается загрузить указанный tier, автоматически
/// откатываясь к другой bundled-модели при ошибке.
public final class LiveASRService: ASRService, @unchecked Sendable {

    // MARK: - State

    nonisolated(unsafe) private var whisper: WhisperKit?
    nonisolated(unsafe) private var _isReady: Bool = false
    nonisolated(unsafe) private var _activeTier: ASRTier = .kidOnDevice
    /// Опциональная пред-проверка (реальный VAD + SoundClassifier). При наличии —
    /// коротит ASR на уверенной тишине (см. ``SpeechPreflightGating``). nil → как раньше.
    nonisolated(unsafe) private var preflightGate: (any SpeechPreflightGating)?

    /// P2-10: in-flight задача загрузки. `loadModel` может вызываться конкурентно
    /// (`EnsembleASRService.warmUp` Tier B + `MLModelWarmupService` Tier A) — без
    /// дедупликации это создаёт два WhisperKit-инстанса и всплеск памяти. Лок
    /// защищает доступ к задаче из разных потоков; повторные вызовы во время
    /// загрузки ждут уже идущую задачу вместо старта новой.
    nonisolated(unsafe) private var loadTask: Task<Void, Error>?
    private let loadLock = NSLock()

    public var isReady: Bool { _isReady }
    public var activeTier: ASRTier { _activeTier }

    // MARK: - Bundled model paths

    /// Путь к bundled whisper-small в Resources/Models/Whisper/whisper-small/ (Tier C)
    private static var bundledSmallModelFolder: URL? {
        Bundle.main.url(
            forResource: "whisper-small",
            withExtension: nil,
            subdirectory: "Models/Whisper"
        )
    }

    /// Путь к bundled whisper-base в Resources/Models/Whisper/whisper-base/ (Tier B)
    private static var bundledBaseModelFolder: URL? {
        Bundle.main.url(
            forResource: "whisper-base",
            withExtension: nil,
            subdirectory: "Models/Whisper"
        )
    }

    /// Проверяет наличие обязательных файлов bundled модели.
    private static func isBundledModelAvailable(folder: URL?) -> Bool {
        guard let folder else { return false }
        let required = [
            "config.json",
            "AudioEncoder.mlmodelc",
            "TextDecoder.mlmodelc"
        ]
        return required.allSatisfy { name in
            FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
        }
    }

    private static func isBundledSmallAvailable() -> Bool {
        isBundledModelAvailable(folder: bundledSmallModelFolder)
    }

    private static func isBundledBaseAvailable() -> Bool {
        isBundledModelAvailable(folder: bundledBaseModelFolder)
    }

    // MARK: - Init

    public init() {}

    /// Подключает пред-проверку речи (реальный VAD + SoundClassifier). Вызывается из
    /// DI после создания сервиса. Без неё транскрипция работает как прежде.
    public func setPreflightGate(_ gate: any SpeechPreflightGating) {
        preflightGate = gate
    }

    // MARK: - Load

    /// Загрузить модель для указанного tier.
    /// При ошибке автоматически откатывается: parentQuality → kidOnDevice.
    ///
    /// P2-10: дедупликация конкурентных вызовов. Если загрузка уже идёт — ждём
    /// её результат, не запуская второй WhisperKit. Если модель уже готова —
    /// мгновенный возврат.
    public func loadModel(tier: ASRTier = .parentQuality) async throws {
        // P2-10: решение принимаем в ОДНОМ синхронном критическом участке через
        // `withLock` (Swift 6 запрещает `NSLock.lock()/unlock()` в async-контексте).
        // Все `await` — строго ВНЕ лока.
        enum LoadAction {
            case ready
            case wait(Task<Void, Error>)
            case start(Task<Void, Error>)
        }

        let action: LoadAction = loadLock.withLock {
            if _isReady, loadTask == nil { return .ready }
            if let inFlight = loadTask { return .wait(inFlight) }
            let task = Task<Void, Error> { [weak self] in
                guard let self else { return }
                try await self.performLoad(tier: tier)
            }
            loadTask = task
            return .start(task)
        }

        switch action {
        case .ready:
            return
        case .wait(let inFlight):
            try await inFlight.value
        case .start(let task):
            defer {
                loadLock.withLock { if loadTask == task { loadTask = nil } }
            }
            try await task.value
        }
    }

    /// Реальная загрузка bundled-модели с fallback на другую bundled-модель.
    /// Вызывается строго внутри одной дедуплицированной `loadTask`, поэтому не
    /// пытается взять `loadLock` повторно. Сеть не задействуется ни на одной ветке.
    private func performLoad(tier: ASRTier) async throws {
        HSLogger.asr.info("ASRService: loading tier=\(tier.rawValue)")

        switch tier {
        case .specialistQuality:
            // Tier C: максимальное качество — whisper-small, fallback на base.
            if await tryLoadBundledSmall() {
                _activeTier = .specialistQuality
                return
            }
            HSLogger.asr.warning("ASRService: bundled whisper-small unavailable, falling back to bundled whisper-base")
            if await tryLoadBundledBase() {
                _activeTier = .parentQuality
                return
            }
            throw AppError.asrModelNotLoaded

        case .parentQuality, .kidOnDevice:
            // Tier A/B: лёгкая on-device модель whisper-base (offline), fallback на small.
            // whisper-tiny НЕ используется — его нет в bundle, а сетевая загрузка с
            // HuggingFace нарушила бы offline-first.
            if await tryLoadBundledBase() {
                _activeTier = tier
                return
            }
            HSLogger.asr.warning("ASRService: bundled whisper-base unavailable, falling back to bundled whisper-small")
            if await tryLoadBundledSmall() {
                _activeTier = .specialistQuality
                return
            }
            throw AppError.asrModelNotLoaded
        }
    }

    /// Устаревший вход (обратная совместимость) — загружает on-device whisper-base.
    public func loadModel() async throws {
        try await loadModel(tier: .parentQuality)
    }

    // MARK: - Transcribe

    public func transcribe(url: URL) async throws -> ASRResult {
        try await transcribe(url: url, expectedWord: nil, childAge: nil)
    }

    /// Распознавание с word-list biasing и возрастной адаптацией под детскую речь.
    ///
    /// Усиления относительно базового пути (все настраивают `DecodingOptions`):
    /// 1. **Word-list biasing** — ожидаемое слово урока токенизируется и подаётся
    ///    как `promptTokens` (Whisper `<|startofprev|>`-prompt). Декодер смещается
    ///    к целевому слову, что критично для искажённой логопедической речи.
    /// 2. **Возрастной prompt** — для младших детей в prompt добавляется указание
    ///    на простую детскую речь, снижая «доводку» до длинных взрослых фраз.
    /// 3. **Temperature fallback** — 4 ступени (0.0→0.8) восстанавливают вывод,
    ///    когда жадное декодирование схлопывается на тихой/нечёткой речи.
    /// 4. **Повышенная толерантность** — ослаблены `compressionRatioThreshold`,
    ///    `logProbThreshold`, `noSpeechThreshold`, чтобы короткие/искажённые
    ///    детские произнесения не отбрасывались как «не речь».
    public func transcribe(url: URL, expectedWord: String?, childAge: Int?) async throws -> ASRResult {
        // Ленивая загрузка: если модель ещё не готова (warm-up не отработал или был
        // пропущен), грузим bundled-модель текущего tier перед транскрипцией вместо
        // отказа. `loadModel(tier:)` дедуплицирован (loadLock/loadTask) — конкурентные
        // вызовы из разных экранов ждут одну загрузку, второй WhisperKit не создаётся.
        if !_isReady {
            try await loadModel(tier: _activeTier)
        }
        guard let whisper, _isReady else {
            throw AppError.asrModelNotLoaded
        }

        // Пред-проверка речи (реальный VAD + SoundClassifier): коротим дорогой проход
        // WhisperKit только на уверенной тишине. Консервативно — искажённая/тихая
        // детская речь всегда проходит дальше (gate возвращает .proceed при сомнении).
        if let preflightGate, await preflightGate.evaluate(url: url) == .likelySilent {
            HSLogger.asr.info("ASRService: preflight detected silence — returning empty transcript")
            return ASRResult(transcript: "", confidence: 0.0, wordTimestamps: [])
        }

        // --- Word-list biasing: токенизируем ожидаемое слово + возрастной prompt ---
        var promptTokens: [Int]?
        if let tokenizer = whisper.tokenizer {
            var promptText = ""
            if let word = expectedWord?.trimmingCharacters(in: .whitespacesAndNewlines), !word.isEmpty {
                promptText = word
            }
            if let age = childAge, age <= 7 {
                // Короткая возрастная подсказка — простая детская речь.
                promptText = promptText.isEmpty ? "детская речь" : "\(promptText). детская речь"
            }
            if !promptText.isEmpty {
                let encoded = tokenizer.encode(text: " " + promptText)
                    .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
                if !encoded.isEmpty {
                    promptTokens = encoded
                }
            }
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: "ru",
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 4,                 // 0.0 → 0.8: восстановление на нечёткой речи
            usePrefillPrompt: true,
            wordTimestamps: true,
            promptTokens: promptTokens,                  // word-list biasing
            // Повышенная толерантность к короткой/искажённой детской речи:
            compressionRatioThreshold: 3.0,              // дефолт 2.4 — реже бракуем «повторы»
            logProbThreshold: -1.5,                      // дефолт -1.0 — принимаем менее уверенные токены
            noSpeechThreshold: 0.8                       // дефолт 0.6 — реже считаем тишиной
        )

        let results = try await whisper.transcribe(audioPath: url.path, decodeOptions: options)
        let texts = results.compactMap { $0.text }
        let text = texts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let confidence: Double
        if let firstSegment = results.first?.segments.first {
            confidence = min(1.0, exp(Double(firstSegment.avgLogprob)))
        } else {
            // Пустые segments = ничего не распознано. Уверенность 0.0, а не
            // сфабрикованные 0.8: иначе ансамбль/политики скоринга получают
            // «уверенную» оценку на фактической тишине и завышают вес Whisper.
            confidence = 0.0
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

    private func tryLoadBundledSmall() async -> Bool {
        guard Self.isBundledSmallAvailable(),
              let folder = Self.bundledSmallModelFolder else {
            HSLogger.asr.info("ASRService: bundled whisper-small not found in bundle")
            return false
        }
        do {
            HSLogger.asr.info("ASRService: loading bundled whisper-small from \(folder.path)")
            let config = WhisperKitConfig(modelFolder: folder.path)
            let kit = try await WhisperKit(config)
            whisper = kit
            _isReady = true
            HSLogger.asr.info("ASRService: whisper-small (bundled) ready — Tier C")
            return true
        } catch {
            HSLogger.asr.error("ASRService: bundled whisper-small load failed: \(error.localizedDescription)")
            return false
        }
    }

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
}
