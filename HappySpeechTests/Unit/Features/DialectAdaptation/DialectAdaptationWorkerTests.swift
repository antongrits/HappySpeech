import XCTest
@testable import HappySpeech

// MARK: - DialectAdaptationWorkerTests
//
// Block AA v21 — Smoke tests для RegionalDialect (Worker-уровень в этой фиче — UserDefaults + доменная модель).
// DialectAdaptation не имеет отдельного Worker-файла: персистенция встроена в Interactor.
// Тесты верифицируют доменную логику RegionalDialect.

final class DialectAdaptationWorkerTests: XCTestCase {

    // MARK: - Tests

    func test_regionalDialect_all_hasFiveEntries() {
        XCTAssertEqual(RegionalDialect.all.count, 5, "Должно быть ровно 5 диалектов")
    }

    func test_regionalDialect_default_isCentral() {
        XCTAssertEqual(RegionalDialect.default.id, "central", "Дефолтный диалект — central")
    }

    func test_regionalDialect_find_returnsCorrectDialect() {
        let found = RegionalDialect.find(id: "moscow")
        XCTAssertNotNil(found, "Диалект 'moscow' должен существовать")
        XCTAssertEqual(found?.id, "moscow")
    }

    func test_regionalDialect_find_unknownId_returnsNil() {
        let found = RegionalDialect.find(id: "nonexistent-dialect-id")
        XCTAssertNil(found, "Несуществующий dialectId должен вернуть nil")
    }
}
