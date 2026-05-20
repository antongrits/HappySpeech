@testable import HappySpeech
import XCTest

// MARK: - Corpus Tests

@MainActor
final class SpeechNormsEncyclopediaCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(SpeechNormsEncyclopediaCorpus.cards.isEmpty,
                       "Speech norm corpus must contain at least fallback cards")
    }

    func test_corpus_coversAllFourAges() {
        let ages = Set(SpeechNormsEncyclopediaCorpus.cards.map { $0.age })
        for age in NormAge.allCases {
            XCTAssertTrue(ages.contains(age),
                          "Corpus must cover age \(age.rawValue)")
        }
    }

    func test_corpus_filterEmptyQuery_returnsAll() {
        let input = SpeechNormsEncyclopediaCorpus.cards
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "", in: input)
        XCTAssertEqual(result.count, input.count)
    }

    func test_corpus_filterByCommonTerm_returnsSubset() {
        let input = SpeechNormsEncyclopediaCorpus.cards
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "звук", in: input)
        XCTAssertGreaterThan(result.count, 0)
        XCTAssertLessThanOrEqual(result.count, input.count)
    }

    func test_corpus_filterByNonexistent_returnsEmpty() {
        let input = SpeechNormsEncyclopediaCorpus.cards
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "xqzwvbnp", in: input)
        XCTAssertEqual(result.count, 0)
    }

    func test_corpus_filterCaseInsensitive() {
        let input = SpeechNormsEncyclopediaCorpus.cards
        let lower = SpeechNormsEncyclopediaCorpus.filter(by: "звук", in: input)
        let upper = SpeechNormsEncyclopediaCorpus.filter(by: "ЗВУК", in: input)
        XCTAssertEqual(lower.count, upper.count)
    }

    func test_corpus_cardsForAge_returnsOnlyThatAge() {
        let six = SpeechNormsEncyclopediaCorpus.cards(for: .six)
        XCTAssertFalse(six.isEmpty)
        XCTAssertTrue(six.allSatisfy { $0.age == .six })
    }

    func test_corpus_ethicsNote_isPresent() {
        XCTAssertFalse(SpeechNormsEncyclopediaCorpus.ethicsNote.isEmpty,
                       "Ethics note must always be available")
    }
}
