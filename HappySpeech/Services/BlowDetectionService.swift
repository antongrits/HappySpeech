@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import OSLog
@preconcurrency import SoundAnalysis

// MARK: - BlowSample

/// Один кадр детекции выдоха/дутья.
///
/// Объединяет два независимых сигнала:
///   1. **Детерминированный DSP** (`AirStreamAnalyzer`) — спектральный профиль
///      буфера 16 kHz: низкочастотная (0–500 Hz) и широкополосная неголосовая
///      энергия типичны для выдоха/дутья в микрофон.
///   2. **Apple Sound Analysis** (`SNClassifySoundRequest`, встроенный классификатор
///      `version1`) — добавочная уверенность, когда среди его меток присутствует
///      релевантный класс (дыхание / ветер / дутьё).
///
/// `isBlowing` истинно, когда совокупная сила превышает порог с гистерезисом по
/// числу подряд активных кадров — один шумовой всплеск не «задувает» свечу.
public struct BlowSample: Sendable, Equatable {
    /// Идёт ли сейчас устойчивый выдох/дутьё.
    public let isBlowing: Bool
    /// Совокупная сила потока 0…1 (для анимации пламени свечи и т.п.).
    public let strength: Float
    /// Уверенность DSP-компоненты 0…1.
    public let dspConfidence: Float
    /// Добавочная уверенность встроенного классификатора 0…1 (0, если релевантной
    /// метки нет среди `knownClassifications` или классификатор недоступен).
    public let classifierConfidence: Float
    /// Время кадра от начала анализа, секунды.
    public let timestamp: TimeInterval

    public init(
        isBlowing: Bool,
        strength: Float,
        dspConfidence: Float,
        classifierConfidence: Float,
        timestamp: TimeInterval
    ) {
        self.isBlowing = isBlowing
        self.strength = strength
        self.dspConfidence = dspConfidence
        self.classifierConfidence = classifierConfidence
        self.timestamp = timestamp
    }

    /// Кадр «тишина / нет потока».
    public static let idle = BlowSample(
        isBlowing: false,
        strength: 0,
        dspConfidence: 0,
        classifierConfidence: 0,
        timestamp: 0
    )
}

// MARK: - BlowDetectionConfig

/// Параметры детекции выдоха/дутья.
public struct BlowDetectionConfig: Sendable {
    /// Порог совокупной силы (0…1), выше которого кадр считается «дутьём».
    public let strengthThreshold: Float
    /// Сколько активных кадров подряд нужно, чтобы открыть гейт (гистерезис).
    public let minSustainFrames: Int
    /// Вес встроенного классификатора в совокупной силе (0…1).
    public let classifierWeight: Float

    public static let `default` = BlowDetectionConfig(
        strengthThreshold: 0.22,
        minSustainFrames: 2,
        classifierWeight: 0.4
    )
}

// MARK: - BlowDetecting

/// Сервис акустической детекции выдоха/дутья для дыхательных упражнений.
///
/// Лицензионно чист (системные Apple `SoundAnalysis` + `Accelerate`), полностью
/// offline и on-device — никаких сетевых вызовов и сторонних весов. COPPA-safe:
/// аудио анализируется в потоке и не сохраняется.
///
/// ### Два режима
/// - **Live** (`startLive` → `liveStream` → `stopLive`) — анализ микрофона через
///   `AVAudioEngine` tap + `SNAudioStreamAnalyzer`. Требует разрешения на микрофон;
///   на симуляторе без аудиовхода поток честно отдаёт `.idle` (graceful).
/// - **File** (`analyzeFile`) — анализ готового WAV через `SNAudioFileAnalyzer`.
///   Используется для **верификации на симуляторе** и в unit-тестах: подаём
///   записанный выдох / тишину и проверяем детекцию.
///
/// Реализации:
/// - ``LiveBlowDetectionService`` — боевая, на `SoundAnalysis` + `AirStreamAnalyzer`.
/// - `MockBlowDetectionService` — для Preview и тестов (в test-таргете).
public protocol BlowDetecting: Sendable {
    /// Поток кадров детекции из живого микрофона. Завершается при `stopLive()`.
    var liveStream: AsyncStream<BlowSample> { get }

    /// Запрашивает разрешение на микрофон и запускает live-анализ.
    /// - Returns: `true`, если поток успешно запущен; `false` — нет разрешения
    ///   или аудиовход недоступен (например, симулятор без микрофона).
    @discardableResult
    func startLive() async -> Bool

    /// Останавливает live-анализ и завершает `liveStream`.
    func stopLive() async

    /// Анализирует WAV-файл целиком и возвращает агрегированный результат.
    /// Детерминированный путь для тестов и верификации на симуляторе.
    func analyzeFile(url: URL) async throws -> BlowFileResult
}

// MARK: - BlowFileResult

/// Агрегированный результат анализа файла.
public struct BlowFileResult: Sendable, Equatable {
    /// Все кадры детекции по ходу файла.
    public let samples: [BlowSample]
    /// Доля кадров с активным дутьём (0…1).
    public let blowingRatio: Float
    /// Длительность непрерывного выдоха (секунды) — самая длинная серия активных
    /// кадров. Метрика «плавного длительного выдоха» (методика Фомичёвой).
    public let longestBlowDuration: TimeInterval
    /// Пиковая сила потока за файл (0…1).
    public let peakStrength: Float

    /// Достаточно ли в записи устойчивого выдоха (≥ 30% активных кадров).
    public var hasSustainedBlow: Bool { blowingRatio >= 0.3 }

    public init(samples: [BlowSample]) {
        self.samples = samples
        let active = samples.filter(\.isBlowing).count
        self.blowingRatio = samples.isEmpty ? 0 : Float(active) / Float(samples.count)
        self.peakStrength = samples.map(\.strength).max() ?? 0

        // Самая длинная непрерывная серия активных кадров → секунды.
        var longestRun = 0
        var currentRun = 0
        for sample in samples {
            if sample.isBlowing {
                currentRun += 1
                longestRun = max(longestRun, currentRun)
            } else {
                currentRun = 0
            }
        }
        // Шаг кадра оцениваем по разнице меток времени соседних кадров.
        let frameStep: TimeInterval
        if samples.count >= 2 {
            frameStep = max(0, samples[1].timestamp - samples[0].timestamp)
        } else {
            frameStep = 0
        }
        self.longestBlowDuration = TimeInterval(longestRun) * frameStep
    }
}

// MARK: - BlowDetectionError

public enum BlowDetectionError: LocalizedError, Sendable {
    case fileNotReadable(String)
    case analyzerSetupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotReadable(let detail):
            return String(localized: "Не удалось прочитать аудиофайл: \(detail)")
        case .analyzerSetupFailed(let detail):
            return String(localized: "Не удалось настроить анализатор звука: \(detail)")
        }
    }
}

// MARK: - BlowSignalFusion

/// Чистая, детерминированная логика слияния DSP- и классификатор-сигналов в
/// `BlowSample` с гистерезисом. Вынесена отдельно, чтобы покрывать unit-тестами
/// без аудиостека (`AVAudioEngine`/`SoundAnalysis`).
struct BlowSignalFusion {
    let config: BlowDetectionConfig
    private(set) var sustainCounter: Int = 0

    init(config: BlowDetectionConfig = .default) {
        self.config = config
    }

    /// Сливает один кадр спектрального профиля и опциональной уверенности
    /// классификатора в итоговый `BlowSample`, обновляя внутренний гистерезис.
    /// - Parameters:
    ///   - profile: спектральный профиль из ``AirStreamAnalyzer``.
    ///   - classifierConfidence: уверенность встроенного классификатора 0…1 (0,
    ///     если релевантной метки нет / классификатор недоступен).
    ///   - timestamp: время кадра.
    mutating func fuse(
        profile: AirStreamProfile,
        classifierConfidence: Float,
        timestamp: TimeInterval
    ) -> BlowSample {
        // DSP-уверенность «это выдох/дутьё»: дыхательная (low-freq) и шипящая
        // полосы — типичный спектр воздушного потока в микрофон; голос/тишина — нет.
        let dspConfidence: Float
        switch profile.streamType {
        case .breathing:
            dspConfidence = min(1, profile.confidence)
        case .hissing:
            // Выдох через сомкнутые губы / шумная воздушная струя.
            dspConfidence = min(1, profile.confidence * 0.8)
        case .whistling:
            dspConfidence = min(1, profile.confidence * 0.6)
        case .voice, .silence:
            dspConfidence = 0
        }

        // Совокупная сила: интенсивность потока, усиленная уверенностями.
        let clampedClassifier = max(0, min(1, classifierConfidence))
        let acoustic = profile.intensity * (0.5 + 0.5 * dspConfidence)
        let strength = max(0, min(1,
            acoustic * (1 - config.classifierWeight)
                + clampedClassifier * config.classifierWeight
        ))

        // Кадр активен, если сила превышает порог И DSP считает это воздушным
        // потоком (или классификатор уверенно подтвердил выдох).
        let frameActive = strength >= config.strengthThreshold
            && (dspConfidence > 0 || clampedClassifier >= 0.5)

        if frameActive {
            sustainCounter = min(sustainCounter + 1, config.minSustainFrames * 3)
        } else {
            sustainCounter = max(sustainCounter - 1, 0)
        }
        let isBlowing = sustainCounter >= config.minSustainFrames

        return BlowSample(
            isBlowing: isBlowing,
            strength: strength,
            dspConfidence: dspConfidence,
            classifierConfidence: clampedClassifier,
            timestamp: timestamp
        )
    }

    mutating func reset() { sustainCounter = 0 }
}

// MARK: - LiveBlowDetectionService

/// Боевая реализация ``BlowDetecting`` на `SoundAnalysis` + `AirStreamAnalyzer`.
///
/// Внутренняя синхронизация — через `actor`-изолированную сердцевину
/// (`BlowDetectionCore`), поэтому класс безопасен в конкурентном доступе.
public final class LiveBlowDetectionService: BlowDetecting, @unchecked Sendable {

    private let core: BlowDetectionCore
    private let config: BlowDetectionConfig

    public init(config: BlowDetectionConfig = .default) {
        self.config = config
        self.core = BlowDetectionCore(config: config)
    }

    public var liveStream: AsyncStream<BlowSample> {
        core.liveStream
    }

    @discardableResult
    public func startLive() async -> Bool {
        await core.startLive()
    }

    public func stopLive() async {
        await core.stopLive()
    }

    public func analyzeFile(url: URL) async throws -> BlowFileResult {
        try await core.analyzeFile(url: url)
    }
}

// MARK: - BlowDetectionCore (actor)

/// Изолированная сердцевина: управляет жизненным циклом live-сессии и файловым
/// анализом. Весь не-`Sendable` аудиостек (`AVAudioEngine`,
/// `SNAudioStreamAnalyzer`) инкапсулирован в ``BlowLiveSession`` —
/// `@unchecked Sendable`-объекте, который актор держит и адресует целиком.
actor BlowDetectionCore {

    private let config: BlowDetectionConfig
    private let logger = Logger(subsystem: "ru.happyspeech", category: "BlowDetection")

    private var liveContinuation: AsyncStream<BlowSample>.Continuation?
    private var liveSession: BlowLiveSession?
    private var isLiveRunning = false

    init(config: BlowDetectionConfig) {
        self.config = config
    }

    // MARK: Live stream

    nonisolated var liveStream: AsyncStream<BlowSample> {
        AsyncStream { continuation in
            Task { await self.attach(continuation: continuation) }
        }
    }

    private func attach(continuation: AsyncStream<BlowSample>.Continuation) {
        liveContinuation?.finish()
        liveContinuation = continuation
        continuation.onTermination = { @Sendable _ in
            Task { await self.stopLive() }
        }
    }

    func startLive() async -> Bool {
        guard !isLiveRunning else { return true }

        let granted = await BlowLiveSession.requestMicrophonePermission()
        guard granted else {
            logger.info("Микрофон не разрешён — live-детекция выдоха недоступна")
            return false
        }

        let session = BlowLiveSession(config: config) { [weak self] sample in
            Task { await self?.emit(sample) }
        }
        let started = session.start()
        guard started else {
            logger.info("Аудиовход недоступен (нет микрофона, напр. симулятор) — graceful")
            return false
        }
        liveSession = session
        isLiveRunning = true
        logger.debug("Live-детекция выдоха запущена")
        return true
    }

    func stopLive() async {
        guard isLiveRunning else {
            liveContinuation?.finish()
            liveContinuation = nil
            return
        }
        isLiveRunning = false
        liveSession?.stop()
        liveSession = nil
        liveContinuation?.finish()
        liveContinuation = nil
        logger.debug("Live-детекция выдоха остановлена")
    }

    private func emit(_ sample: BlowSample) {
        guard isLiveRunning, let continuation = liveContinuation else { return }
        continuation.yield(sample)
    }

    // MARK: File analysis (verifiable on simulator)

    func analyzeFile(url: URL) async throws -> BlowFileResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BlowDetectionError.fileNotReadable(url.lastPathComponent)
        }

        // Читаем файл и считаем детерминированный DSP-профиль покадрово.
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw BlowDetectionError.fileNotReadable(error.localizedDescription)
        }

        // Параллельно прогоняем встроенный классификатор по всему файлу (best-effort).
        let classifierTimeline = await runFileClassifier(url: url)

        let processingFormat = audioFile.processingFormat
        let sampleRate = processingFormat.sampleRate
        // Окно 32 ms (≈ chunk Silero) даёт устойчивую покадровую детекцию.
        let windowFrames = AVAudioFrameCount(max(1, Int(sampleRate * 0.032)))

        var localFusion = BlowSignalFusion(config: config)
        var samples: [BlowSample] = []
        var frameIndex = 0

        while true {
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: processingFormat,
                frameCapacity: windowFrames
            ) else { break }
            do {
                try audioFile.read(into: buffer, frameCount: windowFrames)
            } catch {
                throw BlowDetectionError.fileNotReadable(error.localizedDescription)
            }
            if buffer.frameLength == 0 { break }

            let profile = Self.profile(from: buffer)
            let timestamp = Double(frameIndex) * (Double(windowFrames) / max(sampleRate, 1))
            let classifierConf = Self.confidence(at: timestamp, in: classifierTimeline)
            samples.append(localFusion.fuse(
                profile: profile,
                classifierConfidence: classifierConf,
                timestamp: timestamp
            ))
            frameIndex += 1
            if buffer.frameLength < windowFrames { break }
        }

        return BlowFileResult(samples: samples)
    }

    // MARK: Built-in classifier (file path)

    /// Прогоняет встроенный классификатор по файлу, возвращая таймлайн
    /// (timestamp → релевантная уверенность). Best-effort: при недоступности
    /// классификатора возвращает пустой таймлайн (детекция остаётся на DSP).
    private func runFileClassifier(url: URL) async -> [(time: TimeInterval, confidence: Float)] {
        guard let fileAnalyzer = try? SNAudioFileAnalyzer(url: url),
              let request = try? SNClassifySoundRequest(classifierIdentifier: .version1)
        else { return [] }

        let labels = Self.relevantLabels(in: request.knownClassifications)
        guard !labels.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            let collector = BlowFileResultsCollector(labels: labels) { timeline in
                continuation.resume(returning: timeline)
            }
            do {
                try fileAnalyzer.add(request, withObserver: collector)
            } catch {
                continuation.resume(returning: [])
                return
            }
            // Удерживаем анализатор живым до завершения, захватив его в completion.
            fileAnalyzer.analyze(completionHandler: { [fileAnalyzer] _ in
                _ = fileAnalyzer
                collector.finish()
            })
        }
    }

    // MARK: Helpers (nonisolated, pure)

    nonisolated static func profile(from buffer: AVAudioPCMBuffer) -> AirStreamProfile {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else {
            return .silentProfile()
        }
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        return AirStreamAnalyzer.analyze(samples: samples)
    }

    /// Выбирает из набора меток те, что относятся к выдоху/дутью/ветру.
    /// Сопоставление по подстроке — список меток системного классификатора не
    /// документирован пофиксно и меняется между версиями; матчим устойчивые корни.
    nonisolated static func relevantLabels(in known: [String]) -> Set<String> {
        let needles = ["breath", "wind", "blow", "blowing", "exhal", "sigh", "whistl"]
        return Set(known.filter { label in
            let lower = label.lowercased()
            return needles.contains { lower.contains($0) }
        })
    }

    nonisolated static func relevantConfidence(
        in result: SNClassificationResult,
        labels: Set<String>
    ) -> Float {
        guard !labels.isEmpty else { return 0 }
        var best: Float = 0
        for classification in result.classifications where labels.contains(classification.identifier) {
            best = max(best, Float(classification.confidence))
        }
        return best
    }

    nonisolated private static func confidence(
        at time: TimeInterval,
        in timeline: [(time: TimeInterval, confidence: Float)]
    ) -> Float {
        guard !timeline.isEmpty else { return 0 }
        // Ближайший по времени кадр классификатора (окна перекрываются ~0.5).
        var best: Float = 0
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for entry in timeline {
            let delta = abs(entry.time - time)
            if delta < bestDelta {
                bestDelta = delta
                best = entry.confidence
            }
        }
        // Учитываем только если кадр близко (≤ 0.5 c), иначе классификатор молчал.
        return bestDelta <= 0.5 ? best : 0
    }
}

// MARK: - BlowLiveSession

/// Инкапсулирует весь не-`Sendable` live-аудиостек: `AVAudioEngine` tap,
/// `SNAudioStreamAnalyzer` + встроенный классификатор `version1`, гистерезис
/// слияния. Эмитит готовые `BlowSample` через `@Sendable`-колбэк (актор затем
/// перекладывает их в `AsyncStream`). Помечен `@unchecked Sendable`, т.к. весь
/// доступ к аудиостеку идёт из одного потока (актора-владельца + tap-колбэка),
/// а общий счётчик защищён `NSLock`.
final class BlowLiveSession: NSObject, SNResultsObserving, @unchecked Sendable {

    private let config: BlowDetectionConfig
    private let onSample: @Sendable (BlowSample) -> Void
    private let logger = Logger(subsystem: "ru.happyspeech", category: "BlowDetection.Live")

    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var classifyRequest: SNClassifySoundRequest?
    private var relevantLabels: Set<String> = []

    private let lock = NSLock()
    private var fusion: BlowSignalFusion
    private var frameIndex = 0
    private var lastClassifierConfidence: Float = 0
    private var isRunning = false

    init(config: BlowDetectionConfig, onSample: @escaping @Sendable (BlowSample) -> Void) {
        self.config = config
        self.onSample = onSample
        self.fusion = BlowSignalFusion(config: config)
    }

    /// Настраивает сессию, анализатор и tap, запускает движок.
    /// - Returns: `false`, если аудиовход недоступен (симулятор без микрофона).
    func start() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: [])
        } catch {
            logger.warning("AVAudioSession настроить не удалось: \(error.localizedDescription, privacy: .public)")
            return false
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return false }

        let analyzer = SNAudioStreamAnalyzer(format: format)
        self.analyzer = analyzer
        configureBuiltInClassifier(on: analyzer)

        let sampleRate = format.sampleRate
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, time in
            self?.handleTap(buffer: buffer, framePosition: time.sampleTime, sampleRate: sampleRate)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            logger.warning("AVAudioEngine не стартовал: \(error.localizedDescription, privacy: .public)")
            return false
        }
        lock.lock(); isRunning = true; lock.unlock()
        return true
    }

    func stop() {
        lock.lock(); isRunning = false; lock.unlock()
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        analyzer?.removeAllRequests()
        analyzer = nil
        classifyRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: Tap

    private func handleTap(buffer: AVAudioPCMBuffer, framePosition: AVAudioFramePosition, sampleRate: Double) {
        // Кормим встроенный классификатор (безопасно из tap-колбэка по документации).
        analyzer?.analyze(buffer, atAudioFramePosition: framePosition)

        // Детерминированный DSP-профиль того же буфера.
        let profile = BlowDetectionCore.profile(from: buffer)
        let durationSec = Double(buffer.frameLength) / max(sampleRate, 1)

        lock.lock()
        guard isRunning else { lock.unlock(); return }
        let timestamp = Double(frameIndex) * max(durationSec, 0)
        frameIndex += 1
        let classifier = lastClassifierConfidence
        let sample = fusion.fuse(
            profile: profile,
            classifierConfidence: classifier,
            timestamp: timestamp
        )
        lock.unlock()
        onSample(sample)
    }

    // MARK: Built-in classifier

    private func configureBuiltInClassifier(on analyzer: SNAudioStreamAnalyzer) {
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            let labels = BlowDetectionCore.relevantLabels(in: request.knownClassifications)
            guard !labels.isEmpty else {
                logger.debug("Встроенный классификатор без меток выдоха — используем DSP")
                return
            }
            relevantLabels = labels
            try analyzer.add(request, withObserver: self)
            classifyRequest = request
            logger.debug("Встроенный классификатор подключён, релевантных меток: \(labels.count)")
        } catch {
            logger.debug("Встроенный классификатор недоступен (\(error.localizedDescription, privacy: .public)) — DSP-режим")
        }
    }

    // MARK: SNResultsObserving

    func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let classification = result as? SNClassificationResult else { return }
        let confidence = BlowDetectionCore.relevantConfidence(in: classification, labels: relevantLabels)
        lock.lock()
        lastClassifierConfidence = confidence
        lock.unlock()
    }

    func request(_ request: any SNRequest, didFailWithError error: any Error) {
        // Не критично: детекция продолжается на DSP-сигнале.
    }

    func requestDidComplete(_ request: any SNRequest) {}

    // MARK: Permission

    static func requestMicrophonePermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - AirStreamProfile silent helper

extension AirStreamProfile {
    /// Пустой профиль «тишина» для пустых буферов.
    static func silentProfile() -> AirStreamProfile {
        AirStreamProfile(
            streamType: .silence,
            intensity: 0,
            confidence: 1,
            breathingBandEnergy: 0,
            whistlingBandEnergy: 0,
            hissingBandEnergy: 0
        )
    }
}

// MARK: - SoundAnalysis file observer

/// Сборщик результатов файлового классификатора в таймлайн уверенностей.
final class BlowFileResultsCollector: NSObject, SNResultsObserving, @unchecked Sendable {
    private let labels: Set<String>
    private let onFinish: @Sendable ([(time: TimeInterval, confidence: Float)]) -> Void
    private var timeline: [(time: TimeInterval, confidence: Float)] = []
    private var didFinish = false
    private let lock = NSLock()

    init(
        labels: Set<String>,
        onFinish: @escaping @Sendable ([(time: TimeInterval, confidence: Float)]) -> Void
    ) {
        self.labels = labels
        self.onFinish = onFinish
    }

    func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let classification = result as? SNClassificationResult else { return }
        let time = CMTimeGetSeconds(classification.timeRange.start)
        let confidence = BlowDetectionCore.relevantConfidence(in: classification, labels: labels)
        lock.lock()
        timeline.append((time: time, confidence: confidence))
        lock.unlock()
    }

    func request(_ request: any SNRequest, didFailWithError error: any Error) {
        finish()
    }

    func requestDidComplete(_ request: any SNRequest) {
        finish()
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        didFinish = true
        onFinish(timeline)
    }
}
