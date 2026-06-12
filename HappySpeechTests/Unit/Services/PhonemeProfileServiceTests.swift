@testable import HappySpeech
import XCTest

// MARK: - PhonemeProfileServiceTests
// ==================================================================================
// Юнит-тесты «Фонемного паспорта» (v17). Покрывают:
//   • record → fetch (через Mock-репозиторий и сервис)
//   • EWMA-расчёт (детерминированный)
//   • Theil-Sen slope (детерминированные точки)
//   • <8 наблюдений → нет прогноза (insufficientData)
//   • self-baseline перцентили (внутрисубъектная нормализация)
//   • slope ≤ 0 → needsConsultation
//   • агрегация матрицы / топ-проблемы / dominantState / dominantCompetitor
//
// Все тесты детерминированы: дата инъектируется, GOP заданы вручную.
// ==================================================================================

private let kEpsilon = 1e-9

// MARK: - Фабрика наблюдений

private func makeObs(
    childId: String = "child-1",
    phoneme: String = "r",
    wordId: String = "word_x",
    position: PhonemeWordPosition = .initial,
    gop: Double,
    posterior: Double = 0.5,
    defect: String = "ok",
    competitor: String? = nil,
    daysAgo: Int = 0
) -> PhonemeObservationDTO {
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    let date = base.addingTimeInterval(TimeInterval(-daysAgo * 86_400))
    return PhonemeObservationDTO(
        childId: childId,
        phoneme: phoneme,
        wordId: wordId,
        position: position.rawValue,
        gop: gop,
        posterior: posterior,
        defect: defect,
        competitor: competitor,
        date: date
    )
}

// MARK: - Tests

final class PhonemeProfileServiceTests: XCTestCase {

    // MARK: 1. record → fetch (репозиторий)

    func test_record_thenFetch_returnsObservation() async throws {
        let repo = MockPhonemeObservationRepository()
        let sut = LivePhonemeProfileService(repository: repo, now: { Date(timeIntervalSince1970: 1_700_000_000) })

        try await sut.record(
            childId: "child-1", phoneme: "r", wordId: "word_ruka",
            position: .initial, gop: 0.4, posterior: 0.6,
            defect: "distortion", competitor: "l"
        )

        let fetched = try await repo.fetch(childId: "child-1")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.phoneme, "r")
        XCTAssertEqual(fetched.first?.defect, "distortion")
        XCTAssertEqual(fetched.first?.competitor, "l")
    }

    // MARK: 2. fetch(childId:phoneme:) фильтрует по фонеме

    func test_fetchByPhoneme_filtersCorrectly() async throws {
        let repo = MockPhonemeObservationRepository(observations: [
            makeObs(phoneme: "r", gop: 0.3),
            makeObs(phoneme: "ʂ", gop: 0.7),
            makeObs(phoneme: "r", gop: 0.5)
        ])
        let onlyR = try await repo.fetch(childId: "child-1", phoneme: "r")
        XCTAssertEqual(onlyR.count, 2)
        XCTAssertTrue(onlyR.allSatisfy { $0.phoneme == "r" })
    }

    // MARK: 3. EWMA — детерминированный расчёт

    func test_ewma_isDeterministic() {
        // alpha=0.5: 0 → 0.5*0.5+0.5*0 = 0.25 → 0.5*1.0+0.5*0.25 = 0.625
        let result = PhonemeProfileMath.ewma([0.0, 0.5, 1.0], alpha: 0.5)
        XCTAssertEqual(result, 0.625, accuracy: kEpsilon)
    }

    func test_ewma_singleValue_returnsThatValue() {
        XCTAssertEqual(PhonemeProfileMath.ewma([0.73]), 0.73, accuracy: kEpsilon)
    }

    func test_ewma_empty_returnsZero() {
        XCTAssertEqual(PhonemeProfileMath.ewma([]), 0, accuracy: kEpsilon)
    }

    func test_ewma_constantSeries_equalsConstant() {
        XCTAssertEqual(PhonemeProfileMath.ewma([0.4, 0.4, 0.4, 0.4]), 0.4, accuracy: kEpsilon)
    }

    // MARK: 4. Theil-Sen slope — детерминированные данные

    func test_theilSen_perfectLine_returnsExactSlope() {
        // y = 2x: точки (0,0),(1,2),(2,4),(3,6) — все попарные наклоны = 2.
        let points = [(0.0, 0.0), (1.0, 2.0), (2.0, 4.0), (3.0, 6.0)]
            .map { (x: $0.0, y: $0.1) }
        let slope = PhonemeProfileMath.theilSenSlope(points: points)
        XCTAssertNotNil(slope)
        XCTAssertEqual(slope ?? .nan, 2.0, accuracy: kEpsilon)
    }

    func test_theilSen_robustToOutlier() {
        // y = x с одним выбросом (3, 100). Медиана наклонов остаётся ≈ 1.
        let points = [(0.0, 0.0), (1.0, 1.0), (2.0, 2.0), (3.0, 100.0)]
            .map { (x: $0.0, y: $0.1) }
        let slope = PhonemeProfileMath.theilSenSlope(points: points)
        XCTAssertNotNil(slope)
        // Наклоны: (0-1)=1,(0-2)=1,(0-3)≈33.3,(1-2)=1,(1-3)≈49.5,(2-3)=98 → median=одно из «1»-кластера/большое
        // 6 наклонов: [1,1,33.33,1,49.5,98] sorted → median = (33.33+1)/2... проверяем устойчивость диапазоном.
        XCTAssertLessThan(slope ?? .nan, 40.0)
        XCTAssertGreaterThan(slope ?? .nan, 0.5)
    }

    func test_theilSen_negativeSlope() {
        let points = [(0.0, 1.0), (1.0, 0.8), (2.0, 0.6), (3.0, 0.4)]
            .map { (x: $0.0, y: $0.1) }
        let slope = PhonemeProfileMath.theilSenSlope(points: points)
        XCTAssertEqual(slope ?? .nan, -0.2, accuracy: kEpsilon)
    }

    func test_theilSen_singlePoint_returnsNil() {
        XCTAssertNil(PhonemeProfileMath.theilSenSlope(points: [(x: 1.0, y: 1.0)]))
    }

    func test_theilSen_identicalX_returnsNil() {
        // Все x одинаковы → ни одного валидного наклона → nil.
        let points = [(x: 2.0, y: 1.0), (x: 2.0, y: 5.0)]
        XCTAssertNil(PhonemeProfileMath.theilSenSlope(points: points))
    }

    // MARK: 5. median / percentile

    func test_median_oddAndEven() {
        XCTAssertEqual(PhonemeProfileMath.median([3, 1, 2]), 2, accuracy: kEpsilon)
        XCTAssertEqual(PhonemeProfileMath.median([4, 1, 3, 2]), 2.5, accuracy: kEpsilon)
    }

    // MARK: 6. self-baseline перцентили

    func test_selfBaselinePercentile_relativeToOwnBase() {
        let baseline = [0.1, 0.2, 0.3, 0.4, 0.5]
        // value=0.3 — медиана базы → mid-rank (2 below + 0.5 equal)/5 = 0.5.
        XCTAssertEqual(
            PhonemeProfileMath.selfBaselinePercentile(0.3, baseline: baseline),
            0.5, accuracy: kEpsilon
        )
        // value выше всех → ≈1.0.
        XCTAssertEqual(
            PhonemeProfileMath.selfBaselinePercentile(0.9, baseline: baseline),
            1.0, accuracy: kEpsilon
        )
        // value ниже всех → 0.0.
        XCTAssertEqual(
            PhonemeProfileMath.selfBaselinePercentile(0.05, baseline: baseline),
            0.0, accuracy: kEpsilon
        )
    }

    func test_selfBaselinePercentile_emptyBaseline_usesLogistic() {
        // Без базы — логистическая нормализация: gop=0 → 0.5.
        XCTAssertEqual(
            PhonemeProfileMath.selfBaselinePercentile(0.0, baseline: []),
            0.5, accuracy: kEpsilon
        )
    }

    func test_selfBaseline_sameRawGop_differentChildrenDifferentPercentile() {
        // Внутрисубъектность: одинаковый сырой GOP=0.5 даёт разный перцентиль
        // в зависимости от персональной базы ребёнка.
        let lowBase = [0.1, 0.2, 0.3]    // ребёнок A: 0.5 выше всей базы → 1.0
        let highBase = [0.6, 0.7, 0.8]   // ребёнок B: 0.5 ниже всей базы → 0.0
        let pa = PhonemeProfileMath.selfBaselinePercentile(0.5, baseline: lowBase)
        let pb = PhonemeProfileMath.selfBaselinePercentile(0.5, baseline: highBase)
        XCTAssertEqual(pa, 1.0, accuracy: kEpsilon)
        XCTAssertEqual(pb, 0.0, accuracy: kEpsilon)
        XCTAssertNotEqual(pa, pb)
    }

    // MARK: 7. <8 наблюдений → нет прогноза

    func test_predict_insufficientObservations_returnsInsufficient() async throws {
        var obs: [PhonemeObservationDTO] = []
        for i in 0..<7 {  // 7 < 8
            obs.append(makeObs(phoneme: "r", gop: 0.3 + Double(i) * 0.05, daysAgo: 70 - i * 10))
        }
        let repo = MockPhonemeObservationRepository(observations: obs)
        let sut = LivePhonemeProfileService(repository: repo, now: { Date(timeIntervalSince1970: 1_700_500_000) })

        let forecast = try await sut.predict(childId: "child-1", phoneme: "r")
        XCTAssertEqual(forecast.status, .insufficientData)
        XCTAssertEqual(forecast.observationCount, 7)
        XCTAssertNil(forecast.estimatedWeeksToMastery)
    }

    func test_forecast_exactlyEight_producesForecast() {
        // 8 наблюдений с растущим GOP → improving, ETA задан.
        var obs: [PhonemeObservationDTO] = []
        for i in 0..<8 {
            obs.append(makeObs(phoneme: "r", gop: 0.2 + Double(i) * 0.08, daysAgo: (7 - i) * 3))
        }
        let baseline = obs.map(\.gop)
        let forecast = PhonemeProfileMath.forecast(
            childId: "child-1", phoneme: "r",
            observations: obs, baseline: baseline
        )
        XCTAssertEqual(forecast.observationCount, 8)
        XCTAssertGreaterThan(forecast.weeklySlope, 0)
        XCTAssertEqual(forecast.status, .improving)
        if let eta = forecast.estimatedWeeksToMastery {
            XCTAssertGreaterThanOrEqual(eta, PhonemeProfileMath.etaMinWeeks)
            XCTAssertLessThanOrEqual(eta, PhonemeProfileMath.etaMaxWeeks)
        } else {
            XCTFail("ETA должна быть задана для improving")
        }
    }

    // MARK: 8. slope ≤ 0 → консультация

    func test_forecast_flatOrDeclining_returnsNeedsConsultation() {
        // Падающий GOP во времени → slope < 0 → needsConsultation.
        var obs: [PhonemeObservationDTO] = []
        for i in 0..<10 {
            // Чем позже (меньше daysAgo), тем НИЖЕ gop → регресс.
            obs.append(makeObs(phoneme: "r", gop: 0.8 - Double(i) * 0.05, daysAgo: (9 - i) * 4))
        }
        let baseline = obs.map(\.gop)
        let forecast = PhonemeProfileMath.forecast(
            childId: "child-1", phoneme: "r",
            observations: obs, baseline: baseline
        )
        XCTAssertEqual(forecast.status, .needsConsultation)
        XCTAssertLessThanOrEqual(forecast.weeklySlope, 0)
        XCTAssertNil(forecast.estimatedWeeksToMastery)
    }

    func test_forecast_alreadyMastered_returnsMastered() {
        // Высокий стабильный уровень относительно своей базы → mastered.
        var obs: [PhonemeObservationDTO] = []
        for i in 0..<10 {
            obs.append(makeObs(phoneme: "s", gop: 0.95, daysAgo: (9 - i) * 3))
        }
        // База с разбросом, чтобы перцентиль 0.95 был на максимуме.
        let baseline = [0.1, 0.2, 0.3, 0.4, 0.5, 0.95]
        let forecast = PhonemeProfileMath.forecast(
            childId: "child-1", phoneme: "s",
            observations: obs, baseline: baseline
        )
        XCTAssertEqual(forecast.status, .mastered)
        XCTAssertGreaterThanOrEqual(forecast.currentLevel, PhonemeProfileMath.masteryThreshold)
    }

    // MARK: 9. dominantState / dominantCompetitor

    func test_dominantState_picksMostFrequent() {
        let defects = ["distortion", "distortion", "ok", "substitution"]
        XCTAssertEqual(PhonemeProfileMath.dominantState(defects: defects), .distortion)
    }

    func test_dominantState_empty_returnsNoData() {
        XCTAssertEqual(PhonemeProfileMath.dominantState(defects: []), .noData)
    }

    func test_state_mapping_ageSubstitution() {
        XCTAssertEqual(PhonemeProfileMath.state(fromDefect: "age_substitution"), .ageSubstitution)
        XCTAssertEqual(PhonemeProfileMath.state(fromDefect: "omission"), .omission)
        XCTAssertEqual(PhonemeProfileMath.state(fromDefect: "unknown_xyz"), .distortion)
    }

    func test_dominantCompetitor_picksMostFrequent() {
        XCTAssertEqual(
            PhonemeProfileMath.dominantCompetitor(["l", "l", "j", "l"]),
            "l"
        )
        XCTAssertNil(PhonemeProfileMath.dominantCompetitor([]))
    }

    // MARK: 10. buildProfile — матрица и топ-проблемы

    func test_buildProfile_buildsMatrixAndTopProblems() async throws {
        let observations: [PhonemeObservationDTO] = [
            // r — слабая (низкий gop, замена на l)
            makeObs(phoneme: "r", position: .initial, gop: 0.1, defect: "substitution", competitor: "l", daysAgo: 5),
            makeObs(phoneme: "r", position: .medial, gop: 0.15, defect: "substitution", competitor: "l", daysAgo: 4),
            // s — сильная
            makeObs(phoneme: "s", position: .initial, gop: 0.9, defect: "ok", daysAgo: 3),
            makeObs(phoneme: "s", position: .final, gop: 0.85, defect: "ok", daysAgo: 2),
            // ʂ — средняя
            makeObs(phoneme: "ʂ", position: .initial, gop: 0.5, defect: "distortion", daysAgo: 1)
        ]
        let repo = MockPhonemeObservationRepository(observations: observations)
        let sut = LivePhonemeProfileService(repository: repo, now: { Date(timeIntervalSince1970: 1_700_500_000) })

        let profile = try await sut.profile(childId: "child-1")
        XCTAssertEqual(profile.totalObservations, 5)
        // 4 уникальные ячейки фонема×позиция (r:initial, r:medial, s:initial, s:final, ʂ:initial = 5)
        XCTAssertEqual(profile.cells.count, 5)
        // Топ-проблема — самая слабая фонема r.
        XCTAssertEqual(profile.topProblems.first?.phoneme, "r")
        XCTAssertEqual(profile.topProblems.first?.dominantCompetitor, "l")
        // r-ячейка classified как substitution.
        let rInitial = profile.cells.first { $0.phoneme == "r" && $0.position == .initial }
        XCTAssertEqual(rInitial?.state, .substitution)
    }

    func test_buildProfile_empty_returnsEmpty() {
        let profile = PhonemeProfileMath.buildProfile(childId: "child-1", observations: [])
        XCTAssertEqual(profile.totalObservations, 0)
        XCTAssertTrue(profile.cells.isEmpty)
        XCTAssertTrue(profile.topProblems.isEmpty)
        XCTAssertFalse(profile.isCalibrated)
    }

    func test_buildProfile_calibratedFlag_atBaselineSize() {
        var obs: [PhonemeObservationDTO] = []
        for i in 0..<PhonemeProfileMath.baselineSampleSize {
            obs.append(makeObs(phoneme: "r", gop: 0.4, daysAgo: i))
        }
        let profile = PhonemeProfileMath.buildProfile(childId: "child-1", observations: obs)
        XCTAssertTrue(profile.isCalibrated)

        let profileShort = PhonemeProfileMath.buildProfile(
            childId: "child-1",
            observations: Array(obs.prefix(PhonemeProfileMath.baselineSampleSize - 1))
        )
        XCTAssertFalse(profileShort.isCalibrated)
    }

    // MARK: 11. clampWeeks

    func test_clampWeeks_clampsToRange() {
        XCTAssertEqual(PhonemeProfileMath.clampWeeks(0.2), PhonemeProfileMath.etaMinWeeks)
        XCTAssertEqual(PhonemeProfileMath.clampWeeks(100.0), PhonemeProfileMath.etaMaxWeeks)
        XCTAssertEqual(PhonemeProfileMath.clampWeeks(5.4), 5)
    }

    // MARK: 12. Mock-сервис record → profile сквозной

    func test_mockService_recordThenProfile() async throws {
        let sut = MockPhonemeProfileService(now: { Date(timeIntervalSince1970: 1_700_000_000) })
        try await sut.record(
            childId: "c", phoneme: "r", wordId: "w",
            position: .initial, gop: 0.5, posterior: 0.5, defect: "ok", competitor: nil
        )
        let profile = try await sut.profile(childId: "c")
        XCTAssertEqual(profile.totalObservations, 1)
        XCTAssertEqual(profile.cells.first?.phoneme, "r")
    }
}
