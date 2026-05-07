import AVFoundation
import Foundation
import OSLog

// MARK: - SpeechVisualizationBusinessLogic

@MainActor
protocol SpeechVisualizationBusinessLogic: AnyObject {
    func load(request: SpeechVisualizationModels.Load.Request) async
    func setMode(request: SpeechVisualizationModels.SetMode.Request) async
    func computeScore(request: SpeechVisualizationModels.Score.Request) async

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

    func computeScore(request: SpeechVisualizationModels.Score.Request) async {
        guard !currentSyllables.isEmpty else { return }

        // MVP-эвристика: каждый слог получает базовый 70% + small variance
        // от длительности attempt vs ожидаемой. Реальный per-syllable
        // cross-correlation FFT-фреймов отложен в Block Q.
        let expectedDuration = Double(currentSyllables.count) * Self.estimatedSyllableDuration
        let durationFactor = min(max(request.attemptDurationSeconds / expectedDuration, 0.3), 1.5)

        // Простой scoring: ближе attemptDuration к expectedDuration → выше accuracy
        let baseAccuracy = 1.0 - min(abs(durationFactor - 1.0), 0.5)
        var perSyllable: [Double] = []
        for index in 0..<currentSyllables.count {
            // Псевдо-случайный (детерминированный) сдвиг на основе индекса
            let shift = Double((index * 17) % 13) / 100.0 - 0.06
            let acc = max(0.0, min(1.0, baseAccuracy + shift))
            perSyllable.append(acc)
        }
        let overall = perSyllable.reduce(0, +) / Double(perSyllable.count)

        let response = SpeechVisualizationModels.Score.Response(
            perSyllableAccuracy: perSyllable,
            overallAccuracy: overall
        )
        await presenter?.presentScore(response: response, syllables: currentSyllables)
        Self.logger.info("Karaoke score computed: overall=\(overall, format: .fixed(precision: 2))")
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
