import XCTest
@testable import HappySpeech

/// Тесты диалект-толерантности скоринга произношения.
///
/// Проверяют, что выбор регионального диалекта РЕАЛЬНО влияет на оценку: нормативные
/// диалектные варианты фонем (южный фрикативный г, северное оканье, цоканье) НЕ
/// штрафуются, а при литературной норме (central/default) поведение остаётся прежним.
final class RegionalDialectPhoneticsTests: XCTestCase {

    // MARK: - Ruleset lookup

    func testCentralAndMoscowHaveNoTolerance() {
        XCTAssertTrue(RegionalDialectPhonetics.ruleset(for: "central").equivalences.isEmpty)
        XCTAssertTrue(RegionalDialectPhonetics.ruleset(for: "moscow").equivalences.isEmpty)
    }

    func testUnknownDialectFallsBackToNone() {
        XCTAssertTrue(RegionalDialectPhonetics.ruleset(for: "atlantis").equivalences.isEmpty)
    }

    func testUralUsesNorthernRuleset() {
        // Уральские говоры — северного типа (оканье): ʌ/ə ↔ o.
        let ural = RegionalDialectPhonetics.ruleset(for: "ural")
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "ʌ", produced: "o", ruleset: ural)
        )
    }

    // MARK: - Симметричность

    func testPermissibleVariantIsSymmetric() {
        let south = RegionalDialectPhonetics.ruleset(for: "south")
        // g↔x в обе стороны (ребёнок диалектизировал эталон ИЛИ наоборот).
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "g", produced: "x", ruleset: south)
        )
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "x", produced: "g", ruleset: south)
        )
    }

    // MARK: - Конкретные диалектные правила

    func testSouthAcceptsFricativeG() {
        let south = RegionalDialectPhonetics.ruleset(for: "south")
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "g", produced: "x", ruleset: south),
            "Южный фрикативный г (акустически [x]) — норма, не ошибка"
        )
    }

    func testNorthAcceptsOkanye() {
        let north = RegionalDialectPhonetics.ruleset(for: "ural")
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "ʌ", produced: "o", ruleset: north),
            "Оканье: безударное /o/ как [o], а не редуцированное [ʌ]"
        )
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "ə", produced: "o", ruleset: north)
        )
    }

    func testNorthAcceptsTsokanye() {
        let north = RegionalDialectPhonetics.ruleset(for: "ural")
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "ts", produced: "tɕ", ruleset: north),
            "Цоканье/чоканье: ц↔ч совпадают в северных говорах"
        )
    }

    func testPetersburgAcceptsEkanye() {
        let spb = RegionalDialectPhonetics.ruleset(for: "petersburg")
        XCTAssertTrue(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "ɪ", produced: "e", ruleset: spb),
            "Эканье: предударная /e/ ближе к [e]"
        )
    }

    // MARK: - Негатив: чужие замены НЕ диалектные

    func testNonDialectSubstitutionRejected() {
        let south = RegionalDialectPhonetics.ruleset(for: "south")
        // Р→Л — возрастная замена, НЕ южнодиалектная: ruleset её не покрывает.
        XCTAssertFalse(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "r", produced: "l", ruleset: south)
        )
    }

    func testOkanyeNotAcceptedInLiteraryNorm() {
        let central = RegionalDialectPhonetics.ruleset(for: "central")
        XCTAssertFalse(
            RegionalDialectPhonetics.isPermissibleVariant(reference: "ʌ", produced: "o", ruleset: central),
            "При литературной норме оканье не должно приниматься как эквивалент"
        )
    }

    // MARK: - Влияние на child-aware стоимость замены

    func testDialectVariantCostsZeroForSouth() {
        let southPolicy = ChildSpeechScoringPolicy(dialect: RegionalDialect.find(id: "south")!)
        // Южный фрикативный г: cost должен быть 0.0 (равноценно совпадению).
        XCTAssertEqual(southPolicy.childAwareSubstitutionCost("g", "x"), 0.0, accuracy: 1e-9)
    }

    func testSamePairPenalizedUnderLiteraryNorm() {
        let literary = ChildSpeechScoringPolicy()   // .none ruleset
        // Та же пара g↔x БЕЗ диалекта штрафуется по артикуляционной дистанции (>0).
        XCTAssertGreaterThan(literary.childAwareSubstitutionCost("g", "x"), 0.0)
    }

    func testStandardDevelopmentalSubstitutionUnchangedByDialect() {
        // Р→Л остаётся мягкой возрастной заменой (0.2) и при выбранном диалекте —
        // диалект не должен ломать прежнюю child-aware логику.
        let southPolicy = ChildSpeechScoringPolicy(dialect: RegionalDialect.find(id: "south")!)
        XCTAssertEqual(southPolicy.childAwareSubstitutionCost("r", "l"), 0.2, accuracy: 1e-9)
    }

    // MARK: - Влияние на childAwareSimilarity (целое слово)

    func testOkanyeRaisesSimilarityForNorthDialect() {
        // «молоко»: эталон G2P даёт редуцированные [ʌ]/[ə]; северянин произносит [o].
        let reference = ["m", "ʌ", "l", "ʌ", "k", "o"]
        let okanyeProduced = ["m", "o", "l", "o", "k", "o"]

        let literary = ChildSpeechScoringPolicy()
        let northern = ChildSpeechScoringPolicy(dialect: RegionalDialect.find(id: "ural")!)

        let simLiterary = literary.childAwareSimilarity(
            reference: reference, produced: okanyeProduced, targetSound: ""
        )
        let simNorthern = northern.childAwareSimilarity(
            reference: reference, produced: okanyeProduced, targetSound: ""
        )

        XCTAssertEqual(simNorthern, 1.0, accuracy: 1e-9, "оканье для северного диалекта — полное совпадение")
        XCTAssertLessThan(simLiterary, simNorthern, "без диалекта оканье снижает сходство")
    }
}
