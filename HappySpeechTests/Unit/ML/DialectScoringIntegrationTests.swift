import XCTest
@testable import HappySpeech

/// Интеграционные тесты: выбор диалекта влияет на итоговый вердикт скоринга и на
/// phonetic accuracy ансамблевого ASR.
final class DialectScoringIntegrationTests: XCTestCase {

    // MARK: - evaluate(): корректное слово остаётся correct

    func testNorthDialectWordRecognizedAsCorrect() {
        // Северянин произносит слово верно: вердикт correct, не «звук в работе».
        let northern = ChildSpeechScoringPolicy(dialect: RegionalDialect.find(id: "ural")!)
        let decision = northern.evaluate(
            asrConfidence: 0.9,
            pronunciationScore: 0.9,
            expectedWord: "молоко",
            recognizedText: "молоко",
            targetSound: "Л",
            age: 6
        )
        XCTAssertEqual(decision.verdict, .correct)
    }

    // MARK: - Южный фрикативный г: слово «гора» узнаётся, балл выше с диалектом

    func testSouthFricativeGRaisesWordSimilarity() {
        // Эталон «гора» = [g,o,r,a]; южанин произносит фрикативный г → [x,o,r,a].
        let reference = ["g", "o", "r", "a"]
        let fricative = ["x", "o", "r", "a"]

        let literary = ChildSpeechScoringPolicy()
        let south = ChildSpeechScoringPolicy(dialect: RegionalDialect.find(id: "south")!)

        let simLiterary = literary.childAwareSimilarity(
            reference: reference, produced: fricative, targetSound: "Г"
        )
        let simSouth = south.childAwareSimilarity(
            reference: reference, produced: fricative, targetSound: "Г"
        )

        XCTAssertEqual(simSouth, 1.0, accuracy: 1e-9, "южный фрикативный г — полное совпадение")
        XCTAssertLessThan(simLiterary, simSouth, "без диалекта фрикативный г снижает сходство")
    }

    func testDialectVariantIsNotMisreadAsDevelopmentalSubstitution() {
        // С южным диалектом фрикативный г на целевом звуке НЕ помечается как
        // возрастная замена (это региональная норма, не «звук в работе»).
        let reference = ["g", "o", "r", "a"]
        let fricative = ["x", "o", "r", "a"]
        let south = RegionalDialectPhonetics.ruleset(for: "south")
        XCTAssertFalse(
            ChildSpeechScoringPolicy.targetSoundWasSubstituted(
                reference: reference, produced: fricative,
                targetSound: "Г", dialectRuleset: south
            ),
            "диалектный вариант целевого звука — норма, НЕ замена"
        )
    }

    func testLiteraryNormUnaffectedForStandardSpeech() {
        // Стандартный диалект (default = central): чёткое правильное произнесение —
        // прежнее поведение, вердикт correct.
        let literary = ChildSpeechScoringPolicy()
        let decision = literary.evaluate(
            asrConfidence: 0.9,
            pronunciationScore: 0.95,
            expectedWord: "рыба",
            recognizedText: "рыба",
            targetSound: "Р",
            age: 7
        )
        XCTAssertEqual(decision.verdict, .correct)
    }

    func testDefaultPolicyMatchesNoneRuleset() {
        // ChildSpeechScoringPolicy() и .init(dialect: .default) должны вести себя
        // одинаково — у литературной нормы поблажек нет.
        let bare = ChildSpeechScoringPolicy()
        let byDefault = ChildSpeechScoringPolicy(dialect: RegionalDialect.default)
        XCTAssertEqual(
            bare.childAwareSubstitutionCost("ʌ", "o"),
            byDefault.childAwareSubstitutionCost("ʌ", "o"),
            accuracy: 1e-9
        )
        XCTAssertGreaterThan(byDefault.childAwareSubstitutionCost("ʌ", "o"), 0.0)
    }

    // MARK: - DialectProfileStore (persistence источник правды)

    private func makeDefaults() -> UserDefaults {
        let suite = "test.dialect.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testStoreReturnsDefaultWhenNothingSaved() {
        let store = DialectProfileStore(userDefaults: makeDefaults())
        XCTAssertEqual(store.currentDialect(childId: "child-1").id, RegionalDialect.default.id)
    }

    func testStoreReadsSavedDialect() {
        let defaults = makeDefaults()
        defaults.set("south", forKey: DialectProfileStore.selectedKey(childId: "child-1"))
        let store = DialectProfileStore(userDefaults: defaults)
        XCTAssertEqual(store.currentDialect(childId: "child-1").id, "south")
    }

    func testStoreKeyMatchesInteractorKey() {
        // Контракт единого источника правды: интерактор пишет, store читает по
        // тому же ключу. Симулируем запись интерактора (тот же формат ключа).
        let defaults = makeDefaults()
        let key = "happyspeech.dialect.kid-7.id"
        defaults.set("petersburg", forKey: key)
        XCTAssertEqual(DialectProfileStore.selectedKey(childId: "kid-7"), key)
        let store = DialectProfileStore(userDefaults: defaults)
        XCTAssertEqual(store.currentDialect(childId: "kid-7").id, "petersburg")
    }

    // MARK: - ActiveChildIdHolder

    func testActiveChildIdHolderRoundTrip() {
        let holder = ActiveChildIdHolder()
        XCTAssertEqual(holder.get(), "")
        holder.set("child-42")
        XCTAssertEqual(holder.get(), "child-42")
    }

    // MARK: - EnsembleASRService.phoneticAccuracy реагирует на диалект

    func testPhoneticAccuracyHigherForSelectedDialect() {
        // «молоко»: эталон с редукцией vs северное оканье.
        let reference = ["m", "ʌ", "l", "ʌ", "k", "o"]
        let okanye = ["m", "o", "l", "o", "k", "o"]

        let defaults = UserDefaults(suiteName: "test.dialect.acc.\(UUID().uuidString)")!
        defaults.set("ural", forKey: DialectProfileStore.selectedKey(childId: "north-kid"))
        let holder = ActiveChildIdHolder()
        holder.set("north-kid")

        let northernService = LiveEnsembleASRService(
            whisperASR: MockASRService(),
            phonemeClassifier: MockPhonemeAnalysisService(),
            pronunciationScorer: MockPronunciationScorerService(),
            dialectProfileProvider: DialectProfileStore(userDefaults: defaults),
            activeChildIdProvider: { holder.get() }
        )
        let literaryService = LiveEnsembleASRService(
            whisperASR: MockASRService(),
            phonemeClassifier: MockPhonemeAnalysisService(),
            pronunciationScorer: MockPronunciationScorerService()
        )

        let accNorthern = northernService.phoneticAccuracy(child: okanye, reference: reference)
        let accLiterary = literaryService.phoneticAccuracy(child: okanye, reference: reference)

        XCTAssertGreaterThan(
            accNorthern, accLiterary,
            "выбор северного диалекта повышает phonetic accuracy для оканья"
        )
    }
}
