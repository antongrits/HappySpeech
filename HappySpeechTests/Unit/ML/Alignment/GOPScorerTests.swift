import XCTest
@testable import HappySpeech

// MARK: - GOPScorerTests

/// Тесты GOP-скоринга на синтетических детерминированных логитах.
///
/// После IPA-рефактора (2026-06-12) ``PhonemeGOP/phoneme`` и
/// ``PhonemeGOP/competitorIPA`` содержат канонический IPA ("r","l","ʂ"...),
/// а НЕ кириллицу из Wav2Vec2Vocabulary.
///
/// Каждый тест конструирует точно управляемую log-prob матрицу,
/// чтобы проверить конкретный аспект GOP-формулы и выбор конкурента.
final class GOPScorerTests: XCTestCase {

    // MARK: - Helpers

    /// Строит матрицу T×37 log-prob, где целевая фонема имеет фиксированное
    /// log-prob `targetLogP`, а конкурент — `competitorLogP`, остальные — `-20`.
    private func makeLogProbs(
        timeSteps: Int,
        vocabSize: Int = 37,
        targetId: Int,
        targetLogP: Float,
        competitorId: Int,
        competitorLogP: Float,
        blankId: Int = 0,
        blankLogP: Float = -20.0
    ) -> [[Float]] {
        (0 ..< timeSteps).map { _ in
            var row = [Float](repeating: -20.0, count: vocabSize)
            row[blankId] = blankLogP
            row[targetId] = targetLogP
            if competitorId != targetId && competitorId != blankId {
                row[competitorId] = competitorLogP
            }
            return row
        }
    }

    private var rId: Int { Wav2Vec2Vocabulary.index(of: "р")! }
    private var lId: Int { Wav2Vec2Vocabulary.index(of: "л")! }
    private var aId: Int { Wav2Vec2Vocabulary.index(of: "а")! }
    private var sId: Int { Wav2Vec2Vocabulary.index(of: "с")! }
    private var kId: Int { Wav2Vec2Vocabulary.index(of: "к")! }
    private var fId: Int { Wav2Vec2Vocabulary.index(of: "ф")! }
    private var blank: Int { Wav2Vec2Vocabulary.blankIndex }

    // MARK: - Тест 10: Идеальная фонема — высокий GOP, высокий posterior

    func test_perfectPhoneme_highGOPAndPosterior() {
        // Целевой р доминирует значительно (log-prob = -0.1), конкурент л = -15.0
        let logProbs = makeLogProbs(
            timeSteps: 10,
            targetId: rId,
            targetLogP: -0.1,   // exp(-0.1) ≈ 0.9
            competitorId: lId,
            competitorLogP: -15.0
        )
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 9)
        let results = GOPScorer.score(logProbs: logProbs, spans: [span])
        XCTAssertEqual(results.count, 1)
        let gop = results[0]
        // phoneme — канонический IPA для «р»
        XCTAssertEqual(gop.phoneme, "r")
        // GOP должен быть высоким положительным: target(-0.1) - competitor(-15.0) = ~+14.9
        XCTAssertGreaterThan(gop.gop, 5.0)
        // avgPosterior ≈ exp(-0.1) ≈ 0.9
        XCTAssertGreaterThan(gop.avgPosterior, 0.7)
    }

    // MARK: - Тест 11: Замена — конкурент доминирует, GOP отрицательный

    func test_substitution_competitorDominates_negativeGOP() {
        // Целевой р = -10, конкурент л = -0.2 (л доминирует)
        let logProbs = makeLogProbs(
            timeSteps: 8,
            targetId: rId,
            targetLogP: -10.0,
            competitorId: lId,
            competitorLogP: -0.2
        )
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 7)
        let results = GOPScorer.score(logProbs: logProbs, spans: [span])
        let gop = results[0]
        // GOP < 0: target слабее конкурента
        XCTAssertLessThan(gop.gop, 0.0)
        // Конкурент — канонический IPA для «л»
        XCTAssertEqual(gop.competitorIPA, "l")
    }

    // MARK: - Тест 12: Пропуск — blank доминирует в спане

    func test_omission_blankDominates_lowPosterior() {
        // Все кадры: blank = -0.1, target = -15 (blank почти единственный),
        // competitor = -14 (немного выше target, чтобы GOP был отрицательным).
        let logProbs = makeLogProbs(
            timeSteps: 10,
            targetId: rId,
            targetLogP: -15.0,
            competitorId: lId,
            competitorLogP: -14.0,
            blankLogP: -0.1
        )
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 9)
        let results = GOPScorer.score(logProbs: logProbs, spans: [span])
        let gop = results[0]
        // posterior должен быть очень низким (target = -15 → exp(-15) ≈ 3e-7)
        XCTAssertLessThan(gop.avgPosterior, 0.01)
        // GOP отрицательный: target(-15) - competitor(-14) = -1
        XCTAssertLessThan(gop.gop, 0.0)
    }

    // MARK: - Тест 13: Конкурент корректно идентифицируется по argmax суммы

    func test_competitorIsMaxSumOverSpan() {
        // 5 кадров: л = -1, с = -2, остальные = -20
        // Конкурент должен быть л (большая сумма)
        let logProbs = makeLogProbs(
            timeSteps: 5,
            targetId: rId,
            targetLogP: -0.5,
            competitorId: lId,
            competitorLogP: -1.0
        )
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 4)
        let results = GOPScorer.score(logProbs: logProbs, spans: [span])
        // Конкурент — канонический IPA «л» → "l"
        XCTAssertEqual(results[0].competitorIPA, "l")
    }

    // MARK: - Тест 14: Пустой спан — нулевой GOP, нет конкурента

    func test_emptySpan_zeroGOPNoCompetitor() {
        let logProbs = makeLogProbs(
            timeSteps: 5,
            targetId: rId, targetLogP: -0.5,
            competitorId: lId, competitorLogP: -2.0
        )
        // Спан с endFrame < startFrame
        let span = PhonemeSpan(phoneme: "р", startFrame: 5, endFrame: 4)
        let results = GOPScorer.score(logProbs: logProbs, spans: [span])
        let gop = results[0]
        XCTAssertEqual(gop.gop, 0.0)
        XCTAssertEqual(gop.avgPosterior, 0.0)
        XCTAssertNil(gop.competitorId)
    }

    // MARK: - Тест 15: Множество фонем — GOP для каждой независимый

    func test_multiplePhonemes_independentGOPs() {
        // Спан 1: р-доминант, остальные (включая к) = -20 → GOP высокий (~19.9)
        // Спан 2: к-доминант, остальные (включая р) = -20 → GOP высокий (~19.9)
        // Конкурент -20 — реальное значение, effectiveCompetitorMax = -20,
        // GOP = target(-0.1) - competitor(-20) ≈ 19.9. Это корректно: target сильно доминирует.
        let timeSteps = 20
        var logProbs = [[Float]](repeating: [Float](repeating: -20.0, count: 37), count: timeSteps)
        for t in 0 ..< 10 { logProbs[t][rId] = -0.1 }
        for t in 10 ..< 20 { logProbs[t][kId] = -0.1 }

        let spans = [
            PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 9),
            PhonemeSpan(phoneme: "к", startFrame: 10, endFrame: 19)
        ]
        let results = GOPScorer.score(logProbs: logProbs, spans: spans)
        XCTAssertEqual(results.count, 2)
        // phoneme — канонический IPA
        XCTAssertEqual(results[0].phoneme, "r")
        XCTAssertEqual(results[1].phoneme, "k")
        // GOP высокий: target = -0.1, лучший конкурент = -20 → GOP ≈ 19.9
        XCTAssertGreaterThan(results[0].gop, 5.0)
        XCTAssertGreaterThan(results[1].gop, 5.0)
        // GOP не бесконечность (P1-B: -inf только при Float.infinity конкурентах)
        XCTAssertFalse(results[0].gop.isInfinite)
        XCTAssertFalse(results[1].gop.isInfinite)
    }

    // MARK: - Тест 16: avgPosterior в границах [0, 1]

    func test_avgPosterior_alwaysInUnitRange() {
        let logProbs = makeLogProbs(
            timeSteps: 6,
            targetId: aId, targetLogP: -0.5,
            competitorId: sId, competitorLogP: -2.0
        )
        let span = PhonemeSpan(phoneme: "а", startFrame: 0, endFrame: 5)
        let results = GOPScorer.score(logProbs: logProbs, spans: [span])
        let posterior = results[0].avgPosterior
        XCTAssertGreaterThanOrEqual(posterior, 0.0)
        XCTAssertLessThanOrEqual(posterior, 1.0)
    }

    // MARK: - Тест 17: GOP-формула: mean(logP_target - max_competitor)

    func test_gopFormula_exactValue() {
        // 3 кадра: target log-prob = -1.0, competitor = -3.0 в каждом кадре
        // GOP = mean((-1.0) - (-3.0)) = mean(2.0) = 2.0
        let logProbs = makeLogProbs(
            timeSteps: 3,
            targetId: rId, targetLogP: -1.0,
            competitorId: lId, competitorLogP: -3.0
        )
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 2)
        let results = GOPScorer.score(logProbs: logProbs, spans: [span])
        XCTAssertEqual(results[0].gop, 2.0, accuracy: 0.01)
    }

    // MARK: - Тест 43: Регрессионный — Р→Л (ротацизм) теперь developmentalSubstitution

    /// Регрессионный тест на корневой баг: до IPA-фикса `gop.phoneme` была
    /// кириллица «р», а `competitorIPA` — «л», и `isDevelopmentalSubstitution`
    /// всегда возвращало false (таблица ждёт IPA-ключи "r"/"l").
    /// После фикса GOPScorer заполняет phoneme="r", competitorIPA="l" →
    /// классификатор корректно даёт `.developmentalSubstitution`.
    func test_rRotacism_toL_classifiesAsDevelopmental() {
        // р (targetId=21) = -10 (слабая), л (competitorId=16) = -0.2 (доминирует)
        let logProbs = makeLogProbs(
            timeSteps: 8,
            targetId: rId,
            targetLogP: -10.0,
            competitorId: lId,
            competitorLogP: -0.2
        )
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 7)
        let gops = GOPScorer.score(logProbs: logProbs, spans: [span])
        XCTAssertEqual(gops.count, 1)
        let gopResult = gops[0]

        // Проверяем, что GOPScorer выставил IPA, а не кириллицу
        XCTAssertEqual(gopResult.phoneme, "r",
            "phoneme должен быть IPA 'r', а не кириллица 'р'")
        XCTAssertEqual(gopResult.competitorIPA, "l",
            "competitorIPA должен быть IPA 'l', а не кириллица 'л'")

        // Теперь классификатор должен дать developmentalSubstitution
        let blankProbs = (0 ..< 8).map { _ -> [Float] in
            var row = [Float](repeating: -20.0, count: 37)
            row[rId] = -10.0
            return row
        }
        let thresholds = DefectThresholds(tau0: -1.5, tau1: 0.5,
                                          blankOmissionThreshold: 0.6,
                                          minPosteriorForDecision: 0.03)
        let result = PhonemeDefectClassifier.classify(
            gop: gopResult, logProbs: blankProbs, thresholds: thresholds
        )
        XCTAssertEqual(result.defect, .developmentalSubstitution,
            "Ротацизм Р→Л должен давать .developmentalSubstitution, получено: \(result.defect)")
    }

    // MARK: - Тест 44: Нетипичная замена Р→Ф (не в таблице детских замен)

    func test_rToF_classifiesAsUnexpectedSubstitution() {
        // р = -10 (слабая), ф = -0.2 (доминирует); р→ф нет в таблице замен
        let logProbs = makeLogProbs(
            timeSteps: 8,
            targetId: rId,
            targetLogP: -10.0,
            competitorId: fId,
            competitorLogP: -0.2
        )
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 7)
        let gops = GOPScorer.score(logProbs: logProbs, spans: [span])
        let gopResult = gops[0]

        XCTAssertEqual(gopResult.phoneme, "r")
        XCTAssertEqual(gopResult.competitorIPA, "f")

        let blankProbs = (0 ..< 8).map { _ -> [Float] in
            var row = [Float](repeating: -20.0, count: 37)
            row[rId] = -10.0
            return row
        }
        let thresholds = DefectThresholds(tau0: -1.5, tau1: 0.5,
                                          blankOmissionThreshold: 0.6,
                                          minPosteriorForDecision: 0.03)
        let result = PhonemeDefectClassifier.classify(
            gop: gopResult, logProbs: blankProbs, thresholds: thresholds
        )
        XCTAssertEqual(result.defect, .unexpectedSubstitution,
            "Р→Ф — нетипичная замена, ожидается .unexpectedSubstitution")
    }

    // MARK: - Тест 45: P1-A — span.phoneme="<unk>" → GOP нулевой, uncertain через классификатор

    func test_unknownPhoneme_inSpan_givesUncertain() {
        let logProbs = makeLogProbs(
            timeSteps: 5,
            targetId: rId, targetLogP: -0.5,
            competitorId: lId, competitorLogP: -2.0
        )
        // "<unk>" нет в Wav2Vec2Vocabulary → GOPScorer вернёт нулевой GOP, avgPosterior=0
        let span = PhonemeSpan(phoneme: "<unk>", startFrame: 0, endFrame: 4)
        let gops = GOPScorer.score(logProbs: logProbs, spans: [span])
        XCTAssertEqual(gops.count, 1)
        let gopResult = gops[0]
        XCTAssertEqual(gopResult.gop, 0.0)
        XCTAssertEqual(gopResult.avgPosterior, 0.0)
        XCTAssertNil(gopResult.competitorId)
        XCTAssertNil(gopResult.competitorIPA)

        // Классификатор должен дать .uncertain (avgPosterior=0 < minPosteriorForDecision)
        let thresholds = DefectThresholds(tau0: -1.5, tau1: 0.5,
                                          blankOmissionThreshold: 0.6,
                                          minPosteriorForDecision: 0.03)
        let blankProbs = (0 ..< 5).map { _ in [Float](repeating: -20.0, count: 37) }
        let result = PhonemeDefectClassifier.classify(
            gop: gopResult, logProbs: blankProbs, thresholds: thresholds
        )
        XCTAssertEqual(result.defect, .uncertain,
            "Неизвестная фонема <unk> должна давать .uncertain")
    }

    // MARK: - Тест 46: P1-B — без конкурентов GOP=0 (не +inf)

    func test_noCompetitors_gopIsZeroNotInfinity() {
        // Для активации P1-B нужно literal -Float.infinity у всех конкурентов.
        // Строим матрицу: только blank и target в логитах, остальные = -Float.infinity.
        // competitorMax в каждом кадре = -Float.infinity →
        // effectiveCompetitorMax = targetLogP(-1.0) → GOP-вклад = 0.
        let negInf = -Float.infinity
        let noCompetitorProbs: [[Float]] = (0 ..< 5).map { _ in
            var row = [Float](repeating: negInf, count: 37)
            row[blank] = -20.0
            row[rId] = -1.0
            return row
        }
        let span = PhonemeSpan(phoneme: "р", startFrame: 0, endFrame: 4)
        let results = GOPScorer.score(logProbs: noCompetitorProbs, spans: [span])
        let gopVal = results[0].gop
        XCTAssertFalse(gopVal.isInfinite, "GOP не должен быть бесконечностью при отсутствии конкурентов")
        XCTAssertFalse(gopVal.isNaN, "GOP не должен быть NaN")
        // effectiveCompetitorMax = targetLogP → GOP = 0 per frame → mean = 0
        XCTAssertEqual(gopVal, 0.0, accuracy: 1e-4,
            "GOP при literal-inf конкурентах должен быть точно 0")
    }
}
