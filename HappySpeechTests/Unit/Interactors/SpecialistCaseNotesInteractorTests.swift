@testable import HappySpeech
import XCTest

// MARK: - SpecialistCaseNotesInteractorTests
//
// SpecialistCaseNotesInteractor реально персистит заметки в UserDefaults
// (per specialist+child). Тесты используют изолированный suite, проверяют
// сохранение, удаление и переживание перезапуска (новый интерактор на том же
// suite читает ранее сохранённые заметки).

@MainActor
final class SpecialistCaseNotesInteractorTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "caseNotes.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeSUT(child: String = "c1", specialist: String = "s1") -> SpecialistCaseNotesInteractor {
        SpecialistCaseNotesInteractor(childId: child, specialistId: specialist, defaults: defaults)
    }

    func test_load_emptyByDefault() {
        let sut = makeSUT()
        sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertTrue(sut.state.isEmpty)
    }

    func test_saveNote_addsAndPersists() {
        let sut = makeSUT()
        sut.load()
        sut.startAdding()
        sut.state.draftBody = "Хорошее улучшение Р"
        sut.saveNote()
        XCTAssertEqual(sut.state.notes.count, 1)
        XCTAssertFalse(sut.state.isAddingNote)

        // Новый интерактор на том же suite — заметка пережила «перезапуск».
        let reopened = makeSUT()
        reopened.load()
        XCTAssertEqual(reopened.state.notes.count, 1)
        XCTAssertEqual(reopened.state.notes.first?.body, "Хорошее улучшение Р")
    }

    func test_saveNote_blankIsIgnored() {
        let sut = makeSUT()
        sut.load()
        sut.startAdding()
        sut.state.draftBody = "   \n  "
        sut.saveNote()
        XCTAssertEqual(sut.state.notes.count, 0)
    }

    func test_deleteNote_removesAndPersists() {
        let sut = makeSUT()
        sut.load()
        sut.startAdding()
        sut.state.draftBody = "Первая"
        sut.saveNote()
        let id = sut.state.notes[0].id
        sut.deleteNote(id)
        XCTAssertEqual(sut.state.notes.count, 0)

        let reopened = makeSUT()
        reopened.load()
        XCTAssertEqual(reopened.state.notes.count, 0)
    }

    func test_notes_separatedPerChild() {
        let a = makeSUT(child: "c1")
        a.load()
        a.startAdding(); a.state.draftBody = "Ребёнок А"; a.saveNote()

        let b = makeSUT(child: "c2")
        b.load()
        XCTAssertEqual(b.state.notes.count, 0)
    }

    func test_cancelAdding_clearsDraft() {
        let sut = makeSUT()
        sut.load()
        sut.startAdding()
        sut.state.draftBody = "draft"
        sut.cancelAdding()
        XCTAssertFalse(sut.state.isAddingNote)
        XCTAssertEqual(sut.state.draftBody, "")
    }
}
