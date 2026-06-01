import AVFoundation
import Foundation
import OSLog

// MARK: - SpeechVisualizationBusinessLogic

@MainActor
protocol SpeechVisualizationBusinessLogic: AnyObject {
    func load(request: SpeechVisualizationModels.Load.Request) async
    func setMode(request: SpeechVisualizationModels.SetMode.Request) async
    func computeScore(request: SpeechVisualizationModels.Score.Request) async

    /// Считает per-syllable accuracy из РЕАЛЬНОЙ записи речи ребёнка: энергия
    /// речи распределяется по временным окнам слогов (mel-спектрограмма, vDSP).
    /// Никакого random/псевдо-сдвига. Если записи нет — честный no-score (nil),
    /// и Presenter не показывает выдуманную точность.
    func computeScore(fromAudioURL url: URL?) async

    /// Опционально: запускает mel-spectrogram cross-correlation между записью
    /// ребёнка и эталоном. Используется в practice-режиме при наличии записи.
    ///
    /// Возвращает composite similarity ∈ `[0, 1]` (0 — нет совпадения, 1 — идеал).
    /// Если файлов нет — возвращает `nil`.
    func computeAcousticSimilarity(
        childAudioURL: URL?,
        referenceAudioURL: URL?
    ) async -> Float?
}

// MARK: - SpeechVisualizationInteractor (Clean Swift: Interactor)
//
// Block S.3 v16 — обработка слова, разбивка на слоги, подсчёт accuracy.
//
// Алгоритм:
//   1. Слова в русском разбиваются по гласным (a, я, у, ю, э, е, и, ё, о, ы).
//   2. Каждый слог получает равную долю длительности (упрощение, MVP).
//   3. После записи — comparator вычисляет per-syllable accuracy
//      (heuristic: 0.7 + random ±0.15 из диапазона placeholder; реальный
//      cross-correlation отложен в Block Q).

@MainActor
final class SpeechVisualizationInteractor: SpeechVisualizationBusinessLogic {

    // MARK: VIP

    var presenter: (any SpeechVisualizationPresentationLogic)?

    // MARK: State

    private var currentSyllables: [KaraokeSyllable] = []
    private var currentMode: VisualizationMode = .listen
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SpeechVisualization")

    // MARK: Acoustic Analysis (Block B.3 v17)

    private let melExtractor = MelSpectrogramExtractor()
    private let crossCorrelator = SpectrogramCrossCorrelator()

    // MARK: Constants

    private static let estimatedSyllableDuration: Double = 0.45

    // MARK: - Load

    func load(request: SpeechVisualizationModels.Load.Request) async {
        let syllables = Self.splitToSyllables(word: request.word)
        let total = Double(syllables.count) * Self.estimatedSyllableDuration

        var current: [KaraokeSyllable] = []
        var offset: Double = 0
        for (index, text) in syllables.enumerated() {
            let s = KaraokeSyllable(
                id: "\(request.word).\(index)",
                text: text,
                durationSeconds: Self.estimatedSyllableDuration,
                startOffset: offset
            )
            current.append(s)
            offset += Self.estimatedSyllableDuration
        }
        currentSyllables = current

        let response = SpeechVisualizationModels.Load.Response(
            word: request.word,
            syllables: current,
            totalDuration: total
        )
        await presenter?.presentLoad(response: response)
    }

    func setMode(request: SpeechVisualizationModels.SetMode.Request) async {
        currentMode = request.mode
        await presenter?.presentSetMode(mode: currentMode)
    }

    // MARK: - Scoring

    /// Резервный (без записи) путь: оценивает только ТЕМП по длительности
    /// попытки vs ожидаемой. Это честная метрика темпа (есть реальный замер
    /// времени), а НЕ выдуманная per-syllable точность: один и тот же темп-балл
    /// показывается для всех слогов, без псевдо-случайных сдвигов.
    func computeScore(request: SpeechVisualizationModels.Score.Request) async {
        guard !currentSyllables.isEmpty else { return }

        let expectedDuration = Double(currentSyllables.count) * Self.estimatedSyllableDuration
        let durationFactor = min(max(request.attemptDurationSeconds / expectedDuration, 0.3), 1.5)
        let tempoAccuracy = 1.0 - min(abs(durationFactor - 1.0), 0.5)

        let perSyllable = Array(repeating: tempoAccuracy, count: currentSyllables.count)
        let response = SpeechVisualizationModels.Score.Response(
            perSyllableAccuracy: perSyllable,
            overallAccuracy: tempoAccuracy
        )
        await presenter?.presentScore(response: response, syllables: currentSyllables)
        Self.logger.info("Karaoke tempo score: overall=\(tempoAccuracy, format: .fixed(precision: 2))")
    }

    /// Реальная оценка из записи речи: распределяет энергию мел-спектрограммы по
    /// временным окнам слогов. Per-syllable accuracy = насколько энергия слога
    /// близка к равномерной доле (есть звук в слоге → высокий балл; провал/тишина
    /// → ниже). Если URL нет или запись пустая — fallback на темп НЕ делаем и
    /// честно ничего не показываем (no-score).
    func computeScore(fromAudioURL url: URL?) async {
        guard !currentSyllables.isEmpty, let url else { return }

        let pcm = (try? Self.loadFloatPCM(from: url)) ?? []
        guard pcm.count > MelSpectrogramExtractor.frameSize else {
            Self.logger.info("computeScore(audio): empty/short recording → no-score")
            return
        }

        let mel = await melExtractor.extract(from: pcm)
        guard !mel.frames.isEmpty else { return }

        let perSyllable = Self.perSyllableAccuracy(
            mel: mel,
            syllableCount: currentSyllables.count
        )
        let overall = perSyllable.reduce(0, +) / Double(max(1, perSyllable.count))

        let response = SpeechVisualizationModels.Score.Response(
            perSyllableAccuracy: perSyllable,
            overallAccuracy: overall
        )
        await presenter?.presentScore(response: response, syllables: currentSyllables)
        Self.logger.info("Karaoke acoustic score: overall=\(overall, format: .fixed(precision: 2))")
    }

    /// Per-syllable accuracy из энергии мел-спектрограммы (vDSP). Кадры записи
    /// делятся на N равных окон (по числу слогов); accuracy окна — нормализованная
    /// средняя энергия речи в нём (есть голос → выше). Реальный сигнал, не random.
    static func perSyllableAccuracy(mel: MelSpectrogram, syllableCount: Int) -> [Double] {
        guard syllableCount > 0, !mel.frames.isEmpty else { return [] }

        // Энергия каждого кадра = средний log-mel по бинам.
        let frameEnergies: [Double] = mel.frames.map { frame in
            guard !frame.isEmpty else { return 0 }
            let sum = frame.reduce(Float(0), +)
            return Double(sum) / Double(frame.count)
        }

        // Нормализуем энергии в [0, 1] по min/max записи.
        let minE = frameEnergies.min() ?? 0
        let maxE = frameEnergies.max() ?? 1
        let range = max(maxE - minE, 0.0001)
        let normalized = frameEnergies.map { ($0 - minE) / range }

        // Делим кадры на syllableCount равных окон.
        let total = normalized.count
        var result: [Double] = []
        for i in 0..<syllableCount {
            let start = total * i / syllableCount
            let end = total * (i + 1) / syllableCount
            guard end > start else { result.append(0); continue }
            let window = normalized[start..<end]
            let avg = window.reduce(0, +) / Double(window.count)
            result.append(min(1, max(0, avg)))
        }
        return result
    }

    // MARK: - Acoustic Similarity (Block B.3 v17)

    /// Считает composite acoustic similarity между записью ребёнка и эталоном
    /// через ``MelSpectrogramExtractor`` + ``SpectrogramCrossCorrelator``.
    ///
    /// COPPA: вычисления локальные (vDSP, никаких сетевых вызовов).
    func computeAcousticSimilarity(
        childAudioURL: URL?,
        referenceAudioURL: URL?
    ) async -> Float? {
        guard let childURL = childAudioURL,
              let referenceURL = referenceAudioURL else {
            return nil
        }

        do {
            let childPCM = try Self.loadFloatPCM(from: childURL)
            let referencePCM = try Self.loadFloatPCM(from: referenceURL)

            let childMel = await melExtractor.extract(from: childPCM)
            let referenceMel = await melExtractor.extract(from: referencePCM)

            let result = await crossCorrelator.compare(
                child: childMel,
                reference: referenceMel
            )

            Self.logger.info(
                "Acoustic similarity: cosine=\(result.cosineSimilarity), dtw=\(result.dtwScore), composite=\(result.compositeScore)"
            )
            return result.compositeScore
        } catch {
            Self.logger.error("computeAcousticSimilarity failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Загружает Float32 mono PCM @ 16 kHz из аудиофайла.
    private static func loadFloatPCM(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            return []
        }
        try file.read(into: buffer)
        guard let channelData = buffer.floatChannelData?[0] else {
            return []
        }
        let count = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: count))
    }

    // MARK: - Pure helpers

    /// Простой алгоритм разбиения русского слова на слоги по гласным.
    /// Правило: после каждой гласной — конец слога; согласные присоединяются
    /// к следующему слогу (открытое слогоделение для логопедии).
    static func splitToSyllables(word: String) -> [String] {
        let vowels: Set<Character> = ["а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я",
                                      "А", "Е", "Ё", "И", "О", "У", "Ы", "Э", "Ю", "Я"]
        var syllables: [String] = []
        var current = ""
        for char in word {
            current.append(char)
            if vowels.contains(char) {
                syllables.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            if syllables.isEmpty {
                syllables.append(current)
            } else {
                syllables[syllables.count - 1].append(current)
            }
        }
        return syllables.isEmpty ? [word] : syllables
    }
}

// NOTE deferred to Block Q (test coverage): unit tests for splitToSyllables
// (граничные слова: "стол", "корова", "обезьяна", "лес"), accuracy heuristics.
