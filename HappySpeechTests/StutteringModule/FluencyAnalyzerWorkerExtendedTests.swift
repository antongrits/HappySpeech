@testable import HappySpeech
import XCTest

// MARK: - FluencyAnalyzerWorkerExtendedTests
//
// Дополнительные тесты для FluencyAnalyzerWorker — покрываем пути,
// не охваченные StutteringWorkerTests.swift:
//   - borderline onset classification
//   - dysfluencyRate calculations
//   - makeStubAnalysis
//   - analyzeDysfluency: пустой транскрипт, один токен
//   - estimateSyllableCount: без гласных, только английские гласные

final class FluencyAnalyzerWorkerExtendedTests: XCTestCase {

    private let worker = FluencyAnalyzerWorker()

    // MARK: - classifyOnset: borderline (50–99ms)

    func test_classifyOnset_borderline_50to99ms() {
        // 1 тик тишины, 1 тик noiseFloor, затем пик — attackTime = 1 тик = 50ms
        // (attackEnd = onsetIdx+1, attackTickCount=1 → 50ms)
        let rms: [Float] = [0.0, 0.06, 0.08, 0.09, 0.10, 0.10, 0.10, 0.10, 0.10, 0.10]
        let (classification, attackMs) = worker.classifyOnset(
            rmsBuffer: rms,
            threshold: 0.07,
            difficulty: .easy  // softThreshold=100ms для easy
        )
        XCTAssertTrue(
            classification == .borderline || classification == .soft,
            "При attackTime ≈ 50ms должно быть borderline или soft, получено: \(classification)"
        )
        XCTAssertGreaterThanOrEqual(attackMs, 0)
    }

    // MARK: - classifyOnset: peakRMS below threshold → hard

    func test_classifyOnset_peakBelowThreshold_returnsHard() {
        // Все значения ниже threshold=0.5 → peakRMS < threshold → hard
        let rms: [Float] = [0.0, 0.06, 0.07, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08]
        let (classification, attackMs) = worker.classifyOnset(
            rmsBuffer: rms,
            threshold: 0.5,
            difficulty: .medium
        )
        XCTAssertEqual(classification, .hard)
        XCTAssertEqual(attackMs, 0)
    }

    // MARK: - dysfluencyRate

    func test_dysfluencyRate_normalCase() {
        let rate = worker.dysfluencyRate(count: 5, syllables: 100)
        XCTAssertEqual(rate, 5.0, accuracy: 0.001)
    }

    func test_dysfluencyRate_zeroSyllables_returnsZero() {
        let rate = worker.dysfluencyRate(count: 10, syllables: 0)
        XCTAssertEqual(rate, 0.0, "Деление на ноль должно возвращать 0")
    }

    func test_dysfluencyRate_zeroCount_returnsZero() {
        let rate = worker.dysfluencyRate(count: 0, syllables: 50)
        XCTAssertEqual(rate, 0.0)
    }

    func test_dysfluencyRate_100percent() {
        // 100 дисфлюентностей на 100 слогов = 100%
        let rate = worker.dysfluencyRate(count: 100, syllables: 100)
        XCTAssertEqual(rate, 100.0, accuracy: 0.001)
    }

    // MARK: - makeStubAnalysis

    func test_makeStubAnalysis_isStubTrue() {
        let analysis = worker.makeStubAnalysis(text: "мама мама идёт")
        XCTAssertTrue(analysis.isStub, "makeStubAnalysis должен возвращать isStub=true")
    }

    func test_makeStubAnalysis_prolongationsZero() {
        let analysis = worker.makeStubAnalysis(text: "рыба плывёт быстро")
        XCTAssertEqual(analysis.prolongations, 0,
                       "Stub-анализ не определяет пролонгации")
    }

    func test_makeStubAnalysis_insideWordPausesZero() {
        let analysis = worker.makeStubAnalysis(text: "папа идёт домой")
        XCTAssertEqual(analysis.insideWordPauses, 0)
    }

    func test_makeStubAnalysis_rateNonNegative() {
        let analysis = worker.makeStubAnalysis(text: "аист летит")
        XCTAssertGreaterThanOrEqual(analysis.rate, 0.0)
    }

    func test_makeStubAnalysis_emptyText_doesNotCrash() {
        XCTAssertNoThrow({ _ = self.worker.makeStubAnalysis(text: "") }())
    }

    // MARK: - analyzeDysfluency: edge cases

    func test_analyzeDysfluency_emptyTranscript_zeroRepetitions() {
        let (repetitions, tokens) = worker.analyzeDysfluency(transcript: "")
        XCTAssertEqual(repetitions, 0)
        XCTAssertEqual(tokens, 0)
    }

    func test_analyzeDysfluency_singleToken_zeroRepetitions() {
        let (repetitions, tokens) = worker.analyzeDysfluency(transcript: "мама")
        XCTAssertEqual(repetitions, 0, "Одно слово — нет повторений")
        XCTAssertEqual(tokens, 1)
    }

    func test_analyzeDysfluency_noRepetitions_zeroCounted() {
        let (repetitions, _) = worker.analyzeDysfluency(transcript: "мама папа дом лес")
        XCTAssertEqual(repetitions, 0)
    }

    func test_analyzeDysfluency_syllableRepetition_counted() {
        // "ма-ма" и "ба-ба" — одинаковый prefix(3) → счёт повторений
        let (repetitions, _) = worker.analyzeDysfluency(transcript: "мама мама")
        XCTAssertEqual(repetitions, 1)
    }

    // MARK: - estimateSyllableCount: edge cases

    func test_estimateSyllableCount_noVowels_returnsZero() {
        let count = worker.estimateSyllableCount(in: "рст")
        XCTAssertEqual(count, 0, "Строка без гласных — 0 слогов")
    }

    func test_estimateSyllableCount_emptyString_returnsZero() {
        let count = worker.estimateSyllableCount(in: "")
        XCTAssertEqual(count, 0)
    }

    func test_estimateSyllableCount_englishVowels_counted() {
        // CharacterSet включает английские гласные
        let count = worker.estimateSyllableCount(in: "apple")
        XCTAssertEqual(count, 2, "«apple» — 2 гласных (a, e)")
    }

    // MARK: - analyzeRealTranscript: повторения слов (regex)

    func test_analyzeRealTranscript_wordRepetition_counted() {
        let transcript = WhisperTranscript(
            fullText: "мама мама пошла домой",
            segments: []
        )
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.repetitions, 1, "«мама мама» — одно повторение")
        XCTAssertFalse(analysis.isStub)
    }

    func test_analyzeRealTranscript_noRepetition_zero() {
        let transcript = WhisperTranscript(
            fullText: "кот сидит на окне",
            segments: []
        )
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.repetitions, 0)
    }

    // MARK: - analyzeRealTranscript: пролонгации (короткий сегмент > 300ms)

    func test_analyzeRealTranscript_prolongation_counted() {
        let segments = [
            WhisperSegment(text: "с", startMs: 0, endMs: 500),      // 500ms, 1 символ → пролонгация
            WhisperSegment(text: "собака", startMs: 500, endMs: 900)
        ]
        let transcript = WhisperTranscript(fullText: "с собака", segments: segments)
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.prolongations, 1)
    }

    func test_analyzeRealTranscript_shortSegmentFastEnough_noProlongation() {
        let segments = [
            WhisperSegment(text: "с", startMs: 0, endMs: 100)       // 100ms < 300ms → нет
        ]
        let transcript = WhisperTranscript(fullText: "с", segments: segments)
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.prolongations, 0)
    }

    // MARK: - analyzeRealTranscript: внутрисловные паузы (> 800ms)

    func test_analyzeRealTranscript_insideWordPause_counted() {
        let segments = [
            WhisperSegment(text: "ма", startMs: 0, endMs: 200),
            WhisperSegment(text: "шина", startMs: 1100, endMs: 1500) // gap 900ms > 800ms
        ]
        let transcript = WhisperTranscript(fullText: "ма шина", segments: segments)
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.insideWordPauses, 1)
    }

    func test_analyzeRealTranscript_smallGap_noPause() {
        let segments = [
            WhisperSegment(text: "ма", startMs: 0, endMs: 200),
            WhisperSegment(text: "шина", startMs: 400, endMs: 800)  // gap 200ms < 800ms
        ]
        let transcript = WhisperTranscript(fullText: "ма шина", segments: segments)
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.insideWordPauses, 0)
    }

    func test_analyzeRealTranscript_singleSegment_noPause() {
        let segments = [WhisperSegment(text: "слово", startMs: 0, endMs: 400)]
        let transcript = WhisperTranscript(fullText: "слово", segments: segments)
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.insideWordPauses, 0)
    }

    func test_analyzeRealTranscript_emptySegments_noProlongationsOrPauses() {
        let transcript = WhisperTranscript(fullText: "просто текст", segments: [])
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.prolongations, 0)
        XCTAssertEqual(analysis.insideWordPauses, 0)
    }

    // MARK: - analyzeRealTranscript: rate и слоги

    func test_analyzeRealTranscript_emptyText_zeroRate() {
        let transcript = WhisperTranscript(fullText: "", segments: [])
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.totalSyllables, 0)
        XCTAssertEqual(analysis.rate, 0)
    }

    func test_analyzeRealTranscript_countsSyllables() {
        let transcript = WhisperTranscript(fullText: "мама", segments: [])
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.totalSyllables, 2, "«мама» — 2 гласных")
    }

    func test_analyzeRealTranscript_rateComputed() {
        // 1 повторение, «мама мама» — 4 гласных → rate = 100/4 = 25
        let transcript = WhisperTranscript(fullText: "мама мама", segments: [])
        let analysis = worker.analyzeRealTranscript(transcript)
        XCTAssertEqual(analysis.rate, 25.0, accuracy: 0.01)
    }

    // MARK: - makeStubAnalysis: дополнительные ветви

    func test_makeStubAnalysis_withRepetition_countsIt() {
        let analysis = worker.makeStubAnalysis(text: "да да да")
        XCTAssertEqual(analysis.repetitions, 2)
        XCTAssertTrue(analysis.isStub)
    }
}
