import XCTest
@testable import HappySpeech

/// Тесты конфигурационной политики оценки детской речи.
///
/// Проверяют три ключевых поведения, обеспечивающих работу на искажённой детской
/// речи без датасета: доверительное гейтирование, толерантность к возрастным
/// заменам и возраст-адаптивные пороги.
final class ChildSpeechScoringPolicyTests: XCTestCase {

    private let policy = ChildSpeechScoringPolicy()

    // MARK: - Доверительное гейтирование

    func testLowConfidenceYieldsTryAgainNotPenalty() {
        let d = policy.evaluate(
            asrConfidence: 0.10,            // ниже любого порога
            pronunciationScore: 0.0,
            expectedWord: "рыба",
            recognizedText: "",
            targetSound: "Р",
            age: 6
        )
        XCTAssertEqual(d.verdict, .tryAgain)
        XCTAssertFalse(d.countsTowardStats, "tryAgain не должен засчитываться в статистику")
        XCTAssertEqual(d.category, ErrorAnalysis.Category.uncertain.rawValue)
    }

    func testConfidenceGateIsAgeAdaptive() {
        // Уверенность 0.33: для младших проходит гейт (0.30), для старших — нет (0.45).
        let young = policy.evaluate(
            asrConfidence: 0.33, pronunciationScore: 0.80,
            expectedWord: "", recognizedText: "", targetSound: "С", age: 5
        )
        let old = policy.evaluate(
            asrConfidence: 0.33, pronunciationScore: 0.80,
            expectedWord: "", recognizedText: "", targetSound: "С", age: 8
        )
        XCTAssertNotEqual(young.verdict, .tryAgain, "у младших более низкий гейт")
        XCTAssertEqual(old.verdict, .tryAgain, "у старших гейт строже")
    }

    // MARK: - Возрастные пороги балла

    func testYoungerChildHasLowerCorrectThreshold() {
        // score 0.58: для младших ≥ correct(0.55) → correct; для старших < 0.70 → не correct.
        let young = policy.evaluate(
            asrConfidence: 0.9, pronunciationScore: 0.58,
            expectedWord: "", recognizedText: "", targetSound: "Ш", age: 5
        )
        let old = policy.evaluate(
            asrConfidence: 0.9, pronunciationScore: 0.58,
            expectedWord: "", recognizedText: "", targetSound: "Ш", age: 8
        )
        XCTAssertEqual(young.verdict, .correct)
        XCTAssertNotEqual(old.verdict, .correct)
    }

    func testHighScoreIsCorrectForAllAges() {
        for age in [5, 7, 9] {
            let d = policy.evaluate(
                asrConfidence: 0.95, pronunciationScore: 0.92,
                expectedWord: "", recognizedText: "", targetSound: "Л", age: age
            )
            XCTAssertEqual(d.verdict, .correct, "age=\(age)")
            XCTAssertGreaterThanOrEqual(d.displayScore, 85)
        }
    }

    // MARK: - Толерантность к возрастным заменам

    func testRForLSubstitutionRecognisedAsDevelopmental() {
        // Ребёнок сказал «лыба» вместо «рыба» (ротацизм Р→Л) с хорошим баллом.
        let d = policy.evaluate(
            asrConfidence: 0.9, pronunciationScore: 0.7,
            expectedWord: "рыба", recognizedText: "лыба",
            targetSound: "Р", age: 6
        )
        XCTAssertEqual(d.verdict, .developmentalSubstitution,
                       "Р→Л должно трактоваться как возрастная замена, а не «другое слово»")
        XCTAssertTrue(d.countsTowardStats)
    }

    func testTrulyDifferentWordIsIncorrect() {
        // «кот» вместо «рыба» — это другое слово, не замена звука.
        let d = policy.evaluate(
            asrConfidence: 0.9, pronunciationScore: 0.7,
            expectedWord: "рыба", recognizedText: "кот",
            targetSound: "Р", age: 6
        )
        XCTAssertEqual(d.verdict, .incorrect)
    }

    // MARK: - Child-aware дистанция

    func testDevelopmentalSubstitutionCostIsLow() {
        // Р→Л: цена замены мягкая (0.2), не как чужая фонема.
        XCTAssertEqual(policy.childAwareSubstitutionCost("r", "l"), 0.2, accuracy: 0.001)
        // Идентичные — 0.
        XCTAssertEqual(policy.childAwareSubstitutionCost("s", "s"), 0.0, accuracy: 0.001)
        // Несвязанные фонемы — дороже.
        XCTAssertGreaterThan(policy.childAwareSubstitutionCost("r", "k"), 0.3)
    }

    func testChildAwareSimilarityToleratesSubstitution() {
        let g2p = RussianG2P()
        let ref = g2p.transcribe("рыба")
        let prod = g2p.transcribe("лыба")
        let childSim = policy.childAwareSimilarity(reference: ref, produced: prod, targetSound: "Р")
        let strictSim = g2p.phoneticSimilarity(ref, prod)
        XCTAssertGreaterThan(childSim, strictSim,
                             "child-aware метрика должна быть терпимее к Р→Л")
    }

    func testAgeBandBoundaries() {
        XCTAssertEqual(ChildAgeBand.from(age: 4), .youngest)
        XCTAssertEqual(ChildAgeBand.from(age: 5), .youngest)
        XCTAssertEqual(ChildAgeBand.from(age: 6), .middle)
        XCTAssertEqual(ChildAgeBand.from(age: 7), .middle)
        XCTAssertEqual(ChildAgeBand.from(age: 8), .oldest)
        XCTAssertEqual(ChildAgeBand.from(age: nil), .middle)
    }
}
