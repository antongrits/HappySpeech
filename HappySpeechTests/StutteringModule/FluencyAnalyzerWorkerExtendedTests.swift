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
}
