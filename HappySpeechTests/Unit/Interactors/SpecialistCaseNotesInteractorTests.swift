@testable import HappySpeech
import XCTest

// MARK: - SpecialistCaseNotesInteractorTests
//
// SpecialistCaseNotesInteractor is a thin VIP MVP variant (@Observable). It keeps
// a list of dated case notes plus a draft-editing flow: startAdding/cancelAdding
// toggle the editing flag and clear the draft, while saveNote trims the draft,
// guards against an empty/whitespace body, prepends the new note and exits editing.
// Tests cover the seed, both editing transitions and the save (happy path + guards).

@MainActor
final class SpecialistCaseNotesInteractorTests: XCTestCase {

    private func makeSUT() -> SpecialistCaseNotesInteractor {
        SpecialistCaseNotesInteractor(childId: "child-1", specialistId: "spec-1")
    }

    // MARK: - Init / seed

    func test_init_storesIdentifiers() {
        let sut = SpecialistCaseNotesInteractor(childId: "c-42", specialistId: "s-7")
        XCTAssertEqual(sut.childId, "c-42")
        XCTAssertEqual(sut.specialistId, "s-7")
    }

    func test_initialState_seedNotes() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.notes.isEmpty)
        XCTAssertFalse(sut.state.isAddingNote)
        XCTAssertEqual(sut.state.draftBody, "")
        for note in sut.state.notes {
            XCTAssertFalse(note.body.isEmpty)
        }
    }

    func test_initialState_notesUniqueIds() {
        let sut = makeSUT()
        XCTAssertEqual(Set(sut.state.notes.map(\.id)).count, sut.state.notes.count)
    }

    // MARK: - startAdding / cancelAdding

    func test_startAdding_enablesEditingAndClearsDraft() {
        let sut = makeSUT()
        sut.state.draftBody = "leftover"
        sut.startAdding()
        XCTAssertTrue(sut.state.isAddingNote)
        XCTAssertEqual(sut.state.draftBody, "")
    }

    func test_cancelAdding_disablesEditingAndClearsDraft() {
        let sut = makeSUT()
        sut.startAdding()
        sut.state.draftBody = "half typed"
        sut.cancelAdding()
        XCTAssertFalse(sut.state.isAddingNote)
        XCTAssertEqual(sut.state.draftBody, "")
    }

    func test_cancelAdding_doesNotAddNote() {
        let sut = makeSUT()
        let before = sut.state.notes.count
        sut.startAdding()
        sut.state.draftBody = "не сохраняем"
        sut.cancelAdding()
        XCTAssertEqual(sut.state.notes.count, before)
    }

    // MARK: - saveNote happy path

    func test_saveNote_prependsNote() {
        let sut = makeSUT()
        let before = sut.state.notes.count
        sut.startAdding()
        sut.state.draftBody = "Новая заметка о прогрессе"
        sut.saveNote()
        XCTAssertEqual(sut.state.notes.count, before + 1)
        XCTAssertEqual(sut.state.notes.first?.body, "Новая заметка о прогрессе")
    }

    func test_saveNote_exitsEditingAndClearsDraft() {
        let sut = makeSUT()
        sut.startAdding()
        sut.state.draftBody = "Заметка"
        sut.saveNote()
        XCTAssertFalse(sut.state.isAddingNote)
        XCTAssertEqual(sut.state.draftBody, "")
    }

    func test_saveNote_trimsWhitespace() {
        let sut = makeSUT()
        sut.startAdding()
        sut.state.draftBody = "   обрезаем края  \n"
        sut.saveNote()
        XCTAssertEqual(sut.state.notes.first?.body, "обрезаем края")
    }

    func test_saveNote_stampsRecentDate() {
        let sut = makeSUT()
        sut.startAdding()
        sut.state.draftBody = "Заметка"
        let before = Date()
        sut.saveNote()
        let saved = sut.state.notes.first!
        XCTAssertGreaterThanOrEqual(saved.date, before)
    }

    // MARK: - saveNote guards

    func test_saveNote_emptyDraft_noChange() {
        let sut = makeSUT()
        let before = sut.state.notes
        sut.startAdding()
        sut.saveNote()
        XCTAssertEqual(sut.state.notes, before)
    }

    func test_saveNote_whitespaceOnly_noChange() {
        let sut = makeSUT()
        let before = sut.state.notes.count
        sut.startAdding()
        sut.state.draftBody = "   \n\t  "
        sut.saveNote()
        XCTAssertEqual(sut.state.notes.count, before)
    }

    func test_saveNote_whitespaceOnly_keepsEditingState() {
        // Guard returns before mutating isAddingNote/draftBody.
        let sut = makeSUT()
        sut.startAdding()
        sut.state.draftBody = "    "
        sut.saveNote()
        XCTAssertTrue(sut.state.isAddingNote)
    }
}
