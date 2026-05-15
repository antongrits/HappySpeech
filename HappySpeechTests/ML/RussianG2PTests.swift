@testable import HappySpeech
import XCTest

// MARK: - RussianG2PTests
//
// Phase 2.4 v25 — покрытие RussianG2P (rule-based G2P без ML-инференса).
// Тестируется: transcribe(), transcribeIPA(), phoneticSimilarity(), phoneticAccuracy().
// Все тесты детерминированы — никаких сетевых вызовов, никакого CoreML.

final class RussianG2PTests: XCTestCase {

    private var sut: RussianG2P!

    override func setUp() {
        super.setUp()
        sut = RussianG2P()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Базовые случаи

    func test_transcribe_emptyString_returnsEmpty() {
        let result = sut.transcribe("")
        XCTAssertTrue(result.isEmpty)
    }

    func test_transcribe_singleVowel_a_returnsA() {
        let result = sut.transcribe("а")
        XCTAssertEqual(result, ["a"])
    }

    func test_transcribe_simpleSyllable_kot() {
        // «кот» = k + o (ударный) + t (финальный)
        let result = sut.transcribe("кот", stressIndex: 1)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("k"))
    }

    func test_transcribe_dom_containsD() {
        let result = sut.transcribe("дом", stressIndex: 1)
        XCTAssertTrue(result.contains("d"))
    }

    func test_transcribe_pika_startsWithPPhoneme() {
        // «пика» — первый фонем это «п» (твёрдый или мягкий)
        let result = sut.transcribe("пика")
        XCTAssertFalse(result.isEmpty)
        let first = result.first ?? ""
        XCTAssertTrue(first.hasPrefix("p"), "Первый фонем «п» должен начинаться с 'p', got: \(first)")
    }

    // MARK: - Финальное оглушение

    func test_finalDevoicing_grib_endsWith_k() {
        // «гриб» → финальный б → p (оглушение)
        let result = sut.transcribe("гриб")
        XCTAssertEqual(result.last, "p", "Финальный «б» должен оглушаться в «p»")
    }

    func test_finalDevoicing_les_endsWith_s() {
        // «лез» → финальный з → s
        let result = sut.transcribe("лез")
        XCTAssertEqual(result.last, "s", "Финальный «з» должен оглушаться в «s»")
    }

    func test_finalDevoicing_krov_endsWith_f() {
        // «кров» → финальный в → f
        let result = sut.transcribe("кров")
        XCTAssertEqual(result.last, "f", "Финальный «в» должен оглушаться в «f»")
    }

    // MARK: - Знаки мягкости/твёрдости не добавляют фонем

    func test_softSign_notInOutput() {
        let result = sut.transcribe("мышь")
        XCTAssertFalse(result.contains("ь"))
    }

    func test_hardSign_notInOutput() {
        let result = sut.transcribe("объём")
        XCTAssertFalse(result.contains("ъ"))
    }

    // MARK: - Палатализация

    func test_palatalization_si_returnsSoftS() {
        // «си» — с перед и → sʲ
        let result = sut.transcribe("си", stressIndex: 1)
        XCTAssertTrue(result.contains("sʲ"), "с перед «и» должен быть мягким")
    }

    func test_palatalization_ke_returnsSoftK() {
        // «ке» — к перед е → kʲ
        let result = sut.transcribe("ке", stressIndex: 1)
        XCTAssertTrue(result.contains("kʲ"), "к перед «е» должен быть мягким")
    }

    func test_palatalization_hard_sha_returnsHardSh() {
        // «ша» — ш всегда твёрдый
        let result = sut.transcribe("ша", stressIndex: 0)
        XCTAssertTrue(result.contains("ʂ"), "ш всегда твёрдый → ʂ")
        XCTAssertFalse(result.contains("ʂʲ"))
    }

    // MARK: - Йотированные гласные в начале слова

    func test_yotation_ya_startOfWord_twoPhonemes() {
        // «я» в начале слова → [j, a]
        let result = sut.transcribe("я", stressIndex: 0)
        XCTAssertEqual(result, ["j", "a"], "«я» в начале → [j, a]")
    }

    func test_yotation_yo_startOfWord_containsJ() {
        let result = sut.transcribe("ёж", stressIndex: 0)
        XCTAssertTrue(result.contains("j"))
    }

    func test_yotation_yu_startOfWord_containsJ() {
        let result = sut.transcribe("юг", stressIndex: 0)
        XCTAssertTrue(result.contains("j"))
    }

    // MARK: - Редукция гласных

    func test_reduction_unstressedO_inFirstPreStress_returnsAngledBracket() {
        // «вода» — первый слог предударный: «о» → ʌ
        // Stress на «а» (индекс 3)
        let result = sut.transcribe("вода", stressIndex: 3)
        XCTAssertTrue(result.contains("ʌ"), "Безударный «о» в первом предударном → ʌ")
    }

    func test_reduction_stressedO_remainsO() {
        // «дом» — «о» ударный
        let result = sut.transcribe("дом", stressIndex: 1)
        XCTAssertTrue(result.contains("o"), "Ударный «о» остаётся «o»")
    }

    func test_reduction_unstressedE_becomesI() {
        // «мечта» — «е» безударный перед ударным «а» (stressIndex=3 → «т»? нет, «а» индекс 4)
        // Используем «лесной»: «е» ударный → проверяем что он остаётся «e», не «ɪ»
        // Безударный «е»: «река» (кириллица) с ударением на «а» (индекс 3)
        let result = sut.transcribe("река", stressIndex: 3)
        // «е» безударный → ɪ (ikan'e)
        XCTAssertTrue(result.contains("ɪ"), "Безударный «е» → ɪ")
    }

    // MARK: - Возвратное стяжение тс → ts

    func test_reflexive_contraction_tPlusS_mergesTs() {
        // applyReflexiveContraction стягивает t+s→ts
        // «надо» → без стяжения, «итс» как в «спортс» нет в русском
        // Тестируем через слово «гладкости» нет, лучше напрямую проверить что
        // результат transcribe не пустой (стяжение — постпроцессинг, не влияет на длину)
        let result = sut.transcribe("спортсмен")
        XCTAssertFalse(result.isEmpty, "Слово со стечением тс транскрибируется корректно")
        XCTAssertTrue(result.contains("ts"), "«тс» в «спортсмен» → ts")
    }

    // MARK: - Always-fixed согласные

    func test_shcha_isAlwaysSC() {
        // «щ» → ɕː всегда
        let result = sut.transcribe("щи")
        XCTAssertTrue(result.contains("ɕː"))
    }

    func test_cha_isAlwaysTsh() {
        let result = sut.transcribe("ча")
        XCTAssertTrue(result.contains("tɕ"))
    }

    func test_tsa_isAlwaysTs() {
        let result = sut.transcribe("цапля")
        XCTAssertTrue(result.contains("ts"))
    }

    // MARK: - transcribeIPA

    func test_transcribeIPA_returnsJoinedString() {
        let phonemes = sut.transcribe("кот", stressIndex: 1)
        let ipa = sut.transcribeIPA("кот", stressIndex: 1)
        XCTAssertEqual(ipa, phonemes.joined())
    }

    func test_transcribeIPA_emptyInput_emptyString() {
        XCTAssertEqual(sut.transcribeIPA(""), "")
    }

    // MARK: - phoneticSimilarity

    func test_phoneticSimilarity_identical_returnsOne() {
        let a = ["k", "o", "t"]
        let similarity = sut.phoneticSimilarity(a, a)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001)
    }

    func test_phoneticSimilarity_empty_empty_returnsOne() {
        XCTAssertEqual(sut.phoneticSimilarity([], []), 1.0, accuracy: 0.001)
    }

    func test_phoneticSimilarity_empty_nonEmpty_returnsZero() {
        XCTAssertEqual(sut.phoneticSimilarity([], ["k"]), 0.0, accuracy: 0.001)
    }

    func test_phoneticSimilarity_nonEmpty_empty_returnsZero() {
        XCTAssertEqual(sut.phoneticSimilarity(["k"], []), 0.0, accuracy: 0.001)
    }

    func test_phoneticSimilarity_oneSubstitution_lessThanOne() {
        let a = ["k", "o", "t"]
        let b = ["g", "o", "t"]
        let sim = sut.phoneticSimilarity(a, b)
        XCTAssertLessThan(sim, 1.0)
        XCTAssertGreaterThan(sim, 0.0)
    }

    func test_phoneticSimilarity_completelyDifferent_low() {
        let a = ["k", "o", "t"]
        let b = ["m", "a", "p"]
        let sim = sut.phoneticSimilarity(a, b)
        XCTAssertLessThanOrEqual(sim, 0.5)
    }

    func test_phoneticSimilarity_symmetric() {
        let a = ["k", "o", "t"]
        let b = ["g", "o", "d"]
        XCTAssertEqual(sut.phoneticSimilarity(a, b), sut.phoneticSimilarity(b, a), accuracy: 0.001)
    }

    func test_phoneticSimilarity_inRange() {
        let a = ["r", "ɨ", "b", "a"]
        let b = ["l", "ɨ", "b", "a"]
        let sim = sut.phoneticSimilarity(a, b)
        XCTAssertGreaterThanOrEqual(sim, 0.0)
        XCTAssertLessThanOrEqual(sim, 1.0)
    }

    // MARK: - phoneticAccuracy

    func test_phoneticAccuracy_perfectPronunciation_closeTo1() {
        let word = "кот"
        let expected = sut.transcribe(word)
        let accuracy = sut.phoneticAccuracy(referenceWord: word, producedPhonemes: expected)
        XCTAssertEqual(accuracy, 1.0, accuracy: 0.001)
    }

    func test_phoneticAccuracy_emptyPronunciation_zero() {
        let accuracy = sut.phoneticAccuracy(referenceWord: "кот", producedPhonemes: [])
        XCTAssertEqual(accuracy, 0.0, accuracy: 0.001)
    }

    func test_phoneticAccuracy_almostCorrect_highValue() {
        let word = "рыба"
        let correct = sut.transcribe(word)
        // Подменяем один фонем
        var produced = correct
        if !produced.isEmpty { produced[0] = "l" }
        let accuracy = sut.phoneticAccuracy(referenceWord: word, producedPhonemes: produced)
        XCTAssertGreaterThan(accuracy, 0.5)
    }

    func test_phoneticAccuracy_inRange() {
        let produced = ["r", "ɨ", "b"]
        let accuracy = sut.phoneticAccuracy(referenceWord: "рыба", producedPhonemes: produced)
        XCTAssertGreaterThanOrEqual(accuracy, 0.0)
        XCTAssertLessThanOrEqual(accuracy, 1.0)
    }

    // MARK: - transcribePhonemes

    func test_transcribePhonemes_positionsOrdered() {
        let phonemes = sut.transcribePhonemes("кот")
        for (i, ph) in phonemes.enumerated() {
            XCTAssertEqual(ph.position, i, "Позиции должны идти по порядку")
        }
    }

    func test_transcribePhonemes_count_matchesTranscribe() {
        let arr = sut.transcribe("лес")
        let phs = sut.transcribePhonemes("лес")
        XCTAssertEqual(arr.count, phs.count)
    }

    // MARK: - Строчный регистр нечувствительность

    func test_transcribe_uppercaseInput_sameAsLowercase() {
        let lower = sut.transcribe("кот", stressIndex: 1)
        let upper = sut.transcribe("КОТ", stressIndex: 1)
        XCTAssertEqual(lower, upper, "Результат не должен зависеть от регистра")
    }

    // MARK: - Небуквенные символы игнорируются

    func test_transcribe_punctuationIgnored() {
        let withPunct = sut.transcribe("кот!")
        let withoutPunct = sut.transcribe("кот")
        XCTAssertEqual(withPunct, withoutPunct, "Знаки препинания должны игнорироваться")
    }
}
