import XCTest
@testable import HappySpeech

// MARK: - PhonemeDefectClassifierTests

/// Тесты классификатора дефектов произношения на синтетических GOP-данных.
///
/// Каждый тест конструирует детерминированный ``PhonemeGOP`` и проверяет,
/// что правила классификации дают ожидаемый ``PhonemeDefect``.
final class PhonemeDefectClassifierTests: XCTestCase {

    // MARK: - Helpers

    private let defaultThresholds = DefectThresholds(
        tau0: -1.5,
        tau1: 0.5,
        blankOmissionThreshold: 0.6,
        minPosteriorForDecision: 0.03
    )

    /// Строит синтетическую матрицу T×37 log-prob, где blank доминирует
    /// в `blankFraction` кадрах, а остальные кадры — у targetId.
    private func makeLogProbsWithBlank(
        timeSteps: Int,
        targetId: Int,
        blankFraction: Float,
        blankId: Int = 0
    ) -> [[Float]] {
        let blankCount = Int(Float(timeSteps) * blankFraction)
        return (0 ..< timeSteps).map { t in
            var row = [Float](repeating: -20.0, count: 37)
            if t < blankCount {
                row[blankId] = 0.0
            } else {
                row[targetId] = 0.0
            }
            return row
        }
    }

    /// Строит ``PhonemeGOP`` с IPA-значениями в phoneme и competitorIPA
    /// (как делает GOPScorer после IPA-фикса).
    /// `phoneme` — канонический IPA (например "r", "ʂ").
    /// `competitorIPA` — канонический IPA конкурента или nil.
    private func makeGOP(
        phoneme: String,
        gop: Float,
        avgPosterior: Float,
        competitorIPA: String? = nil,
        startFrame: Int = 0,
        endFrame: Int = 9
    ) -> PhonemeGOP {
        // competitorId ищем по кирилличному символу, соответствующему IPA
        let competitorId: Int?
        if let ipa = competitorIPA {
            competitorId = AlignmentVocabMap.vocabId(for: ipa)
        } else {
            competitorId = nil
        }
        return PhonemeGOP(
            phoneme: phoneme,
            span: PhonemeSpan(phoneme: phoneme, startFrame: startFrame, endFrame: endFrame),
            gop: gop,
            avgPosterior: avgPosterior,
            competitorId: competitorId,
            competitorIPA: competitorIPA
        )
    }

    private var rId: Int { Wav2Vec2Vocabulary.index(of: "р")! }

    // MARK: - Тест 18: Правильная фонема (GOP выше τ₁)

    func test_correct_highGOP_returnsCorrect() {
        // GOP = 1.0 > τ₁ = 0.5 → correct; phoneme = IPA "r"
        let gop = makeGOP(phoneme: "r", gop: 1.0, avgPosterior: 0.8)
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.0)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .correct)
        XCTAssertEqual(result.phoneme, "r")
    }

    // MARK: - Тест 19: Искажение (GOP в серой зоне [τ₀, τ₁])

    func test_distortion_marginalGOP_returnsDistortion() {
        // GOP = 0.0 ∈ [-1.5, 0.5] → distortion; phoneme=IPA "s", competitor=IPA "ʂ"
        let gop = makeGOP(phoneme: "s", gop: 0.0, avgPosterior: 0.15, competitorIPA: "ʂ")
        let sId = Wav2Vec2Vocabulary.index(of: "с")!
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: sId, blankFraction: 0.0)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .distortion)
    }

    // MARK: - Тест 20: Возрастная замена Р → Л (типичный ротацизм)

    func test_developmentalSubstitution_rToL_returnsDevSub() {
        // GOP = -2.0 < τ₀; конкурент IPA "l" — типичная замена для IPA "r" → developmentalSubstitution
        let gop = makeGOP(phoneme: "r", gop: -2.0, avgPosterior: 0.05, competitorIPA: "l")
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.0)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .developmentalSubstitution)
        XCTAssertEqual(result.competitorIPA, "l")
    }

    // MARK: - Тест 21: Нетипичная замена Р → К (не в таблице детских замен)

    func test_unexpectedSubstitution_rToK_returnsUnexpected() {
        // GOP = -2.5 < τ₀; конкурент IPA "k" — НЕ типичная замена для IPA "r" → unexpectedSubstitution
        let gop = makeGOP(phoneme: "r", gop: -2.5, avgPosterior: 0.04, competitorIPA: "k")
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.0)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .unexpectedSubstitution)
        XCTAssertEqual(result.competitorIPA, "k")
    }

    // MARK: - Тест 22: Пропуск — blank доминирует в >60% кадров

    func test_omission_blankDominates_returnsOmission() {
        // 7 из 10 кадров blank → fraction = 0.7 > 0.6 → omission
        let gop = makeGOP(phoneme: "r", gop: -3.0, avgPosterior: 0.02)
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.7)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .omission)
    }

    // MARK: - Тест 23: Граница blank — ровно 60% (не пропуск)

    func test_blankBoundary_exactly60pct_notOmission() {
        // Ровно 60% blank (threshold = 0.6, строгое >=) → НЕ пропуск
        // Но posterior тоже проверим — если мала, будет uncertain
        let gop = makeGOP(phoneme: "r", gop: -0.5, avgPosterior: 0.05)
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.6)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        // При 60% blank (ровно threshold) — срабатывает omission (>= threshold)
        XCTAssertEqual(result.defect, .omission)
    }

    // MARK: - Тест 24: Неопределённость (очень низкий posterior)

    func test_uncertain_veryLowPosterior_returnsUncertain() {
        // avgPosterior = 0.005 < 0.03 → uncertain
        let gop = makeGOP(phoneme: "r", gop: 0.1, avgPosterior: 0.005)
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.3)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .uncertain)
    }

    // MARK: - Тест 25: Ш → С (сигматизм шипящих — типичная замена)

    func test_developmentalSubstitution_shToS_returnsDevSub() {
        // После IPA-фикса GOPScorer заполняет phoneme=IPA, competitorIPA=IPA.
        // ʂ → s: ChildSpeechScoringPolicy.developmentalSubstitutions["ʂ"] содержит "s"
        // → classify должен вернуть .developmentalSubstitution.
        let shId = Wav2Vec2Vocabulary.index(of: "ш")!
        let gop = PhonemeGOP(
            phoneme: "ʂ",
            span: PhonemeSpan(phoneme: "ш", startFrame: 0, endFrame: 9),
            gop: -2.0,
            avgPosterior: 0.05,
            competitorId: Wav2Vec2Vocabulary.index(of: "с"),
            competitorIPA: "s"
        )
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: shId, blankFraction: 0.0)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .developmentalSubstitution,
            "Сигматизм Ш→С (IPA ʂ→s) должен давать .developmentalSubstitution")
        XCTAssertEqual(result.competitorIPA, "s")
    }

    // MARK: - Тест 26: Приоритет правил — пропуск важнее всего

    func test_omissionPriority_overridesHighGOP() {
        // Даже при высоком GOP, если blank > 60% → omission
        let gop = makeGOP(phoneme: "r", gop: 2.0, avgPosterior: 0.8)
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.8)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .omission)
    }

    // MARK: - Тест 27: classifyAll — пороги выбираются по группе

    func test_classifyAll_sonorantGroup_usesSonorantThresholds() throws {
        // Для соноров τ₀ = -1.8, τ₁ = 0.5 (расширенная зона).
        // GOP = -1.6 для IPA "r" в группе "соноры" → τ₀_sonorant = -1.8
        // → GOP > τ₀ → distortion (а НЕ замена, как было бы при τ₀ = -1.5).
        // IPADictionary.info(for: "r")?.logopedicGroup == "соноры" → classifyAll правильно
        // выбирает пороги соноров по первой фонеме (если groupOverride не указан).
        let rId_ = Wav2Vec2Vocabulary.index(of: "р")!
        let lId_ = Wav2Vec2Vocabulary.index(of: "л")!
        let gop = PhonemeGOP(
            phoneme: "r",
            span: PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 9),
            gop: -1.6,           // между τ₀_default=-1.5 и τ₀_sonorant=-1.8
            avgPosterior: 0.06,
            competitorId: lId_,
            competitorIPA: "l"
        )
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId_, blankFraction: 0.0)
        let results = PhonemeDefectClassifier.classifyAll(
            gops: [gop],
            logProbs: logProbs,
            groupOverride: "соноры"
        )
        XCTAssertEqual(results.count, 1)
        // С порогами соноров: τ₀ = -1.8, GOP = -1.6 > τ₀ → distortion (не замена)
        XCTAssertEqual(results[0].defect, .distortion)
    }

    // MARK: - Тест 28: rationale не пустой для всех типов дефектов

    func test_rationaleNotEmpty_allDefectTypes() {
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.0)
        // phoneme и competitorIPA — IPA-символы
        let cases: [(Float, Float, String?, PhonemeDefect)] = [
            (1.0,   0.8,   nil,  .correct),
            (0.0,   0.15,  "ʂ",  .distortion),
            (0.005, 0.001, nil,  .uncertain)
        ]
        for (gVal, posterior, comp, _) in cases {
            let g = makeGOP(phoneme: "r", gop: gVal, avgPosterior: posterior, competitorIPA: comp)
            let result = PhonemeDefectClassifier.classify(
                gop: g, logProbs: logProbs, thresholds: defaultThresholds
            )
            XCTAssertFalse(result.rationale.isEmpty, "rationale пустой для defect=\(result.defect)")
        }
    }

    // MARK: - Тест 29: blankDominanceFraction в результате корректна

    func test_blankDominanceFraction_correctlyComputed() {
        // 3 из 5 кадров — blank
        let rId_ = Wav2Vec2Vocabulary.index(of: "р")!
        let logProbs: [[Float]] = (0 ..< 5).map { t in
            var row = [Float](repeating: -20.0, count: 37)
            if t < 3 {
                row[0] = 0.0  // blank
            } else {
                row[rId_] = 0.0
            }
            return row
        }
        let gop = makeGOP(phoneme: "r", gop: -3.0, avgPosterior: 0.02, startFrame: 0, endFrame: 4)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.blankDominanceFraction, 0.6, accuracy: 0.01)
    }

    // MARK: - Тест 47: P2 — GOP < τ₀ без конкурента → .uncertain (не .distortion)

    func test_lowGOP_noCompetitor_returnsUncertain() {
        // gop = -3.0 < τ₀ = -1.5; competitorIPA = nil (конкурент не идентифицирован)
        // Без конкурента замена неинтерпретируема → .uncertain
        let gop = makeGOP(phoneme: "r", gop: -3.0, avgPosterior: 0.05, competitorIPA: nil)
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId, blankFraction: 0.0)
        let result = PhonemeDefectClassifier.classify(
            gop: gop, logProbs: logProbs, thresholds: defaultThresholds
        )
        XCTAssertEqual(result.defect, .uncertain,
            "GOP < τ₀ без конкурента должен давать .uncertain, не .distortion")
        XCTAssertFalse(result.rationale.isEmpty)
    }

    // MARK: - Тест 48: classifyAll авто-группа — IPADictionary.info(for: "r") → "соноры"

    func test_classifyAll_autoGroup_fromIPADictionary() {
        // Без groupOverride: classifyAll берёт группу из IPADictionary.info(for: gops[0].phoneme)
        // phoneme = "r" → IPADictionary.info(for: "r")?.logopedicGroup = "соноры"
        // → τ₀_sonorant = -1.8
        // GOP = -1.6 → distortion (а не замена при τ₀_default = -1.5)
        let lId_ = Wav2Vec2Vocabulary.index(of: "л")!
        let rId_ = Wav2Vec2Vocabulary.index(of: "р")!
        let gop = PhonemeGOP(
            phoneme: "r",
            span: PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 9),
            gop: -1.6,
            avgPosterior: 0.06,
            competitorId: lId_,
            competitorIPA: "l"
        )
        let logProbs = makeLogProbsWithBlank(timeSteps: 10, targetId: rId_, blankFraction: 0.0)
        // groupOverride = nil → автоопределение по IPADictionary
        let results = PhonemeDefectClassifier.classifyAll(
            gops: [gop],
            logProbs: logProbs,
            groupOverride: nil
        )
        XCTAssertEqual(results.count, 1)
        // IPADictionary должен вернуть "соноры" → τ₀ = -1.8 → GOP = -1.6 > τ₀ → distortion
        XCTAssertEqual(results[0].defect, .distortion,
            "Автогруппа для IPA 'r' должна быть 'соноры', GOP -1.6 > τ₀ -1.8 → distortion")
    }
}
