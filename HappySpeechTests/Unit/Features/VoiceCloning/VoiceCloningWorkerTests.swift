import XCTest
@testable import HappySpeech

// MARK: - VoiceCloningWorkerTests
//
// Block AA v21 — Smoke tests для доменного слоя VoiceCloning.
// Тестируем SuggestedWordCatalog и VoiceCloning.ArchiveRow (Worker-уровень модели).

final class VoiceCloningWorkerTests: XCTestCase {

    // MARK: - SuggestedWordCatalog

    func test_suggestedWordCatalog_soundR_returnsNonEmpty() {
        let words = VoiceCloning.SuggestedWordCatalog.words(forSound: "Р")
        XCTAssertFalse(words.isEmpty, "Для звука Р должны быть слова")
    }

    func test_suggestedWordCatalog_defaultWord_returnsFirstWord() {
        let defaultWord = VoiceCloning.SuggestedWordCatalog.defaultWord(forSound: "С")
        let allWords = VoiceCloning.SuggestedWordCatalog.words(forSound: "С")
        XCTAssertEqual(defaultWord, allWords.first)
    }

    func test_suggestedWordCatalog_unknownSound_returnsFallback() {
        let words = VoiceCloning.SuggestedWordCatalog.words(forSound: "X_UNKNOWN")
        XCTAssertFalse(words.isEmpty, "Fallback слова должны возвращаться для неизвестного звука")
    }

    // MARK: - ArchiveRow

    func test_archiveRow_identifiable_idIsChildId() {
        let row = VoiceCloning.ArchiveRow(
            id: "sample-abc",
            title: "рыба",
            targetSound: "Р",
            dateText: "8 мая, 14:30",
            durationText: "0:04",
            audioFilePath: "VoiceArchive/child-1/sample.m4a"
        )
        XCTAssertEqual(row.id, "sample-abc")
    }
}
