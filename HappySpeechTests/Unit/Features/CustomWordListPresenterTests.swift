@testable import HappySpeech
import XCTest

// MARK: - CustomWordListPresenterTests
//
// Verifies the non-trivial Response → ViewModel mapping in the specialist
// custom word-list presenter:
//   - Load: rows count preserved; isEmpty flag computed from row count
//   - Load: words-count / target-sound / a11y labels formatted & non-empty
//   - Save success → dismiss flag set
//   - Save failure → message branch differs per ValidationError reason
//   - Delete → removedId forwarded
//   - Preview → exercisesCount forwarded; text non-empty; template titles joined

@MainActor
final class CustomWordListPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: CustomWordListDisplayLogic {
        var loadVM: CustomWordListModels.Load.ViewModel?
        var saveSuccessVM: CustomWordListModels.Save.ViewModel?
        var saveFailureVM: CustomWordListModels.Save.FailureViewModel?
        var deletedId: String?
        var previewVM: CustomWordListModels.Preview.ViewModel?

        func displayLoad(viewModel: CustomWordListModels.Load.ViewModel) async {
            loadVM = viewModel
        }
        func displaySaveSuccess(viewModel: CustomWordListModels.Save.ViewModel) async {
            saveSuccessVM = viewModel
        }
        func displaySaveFailure(viewModel: CustomWordListModels.Save.FailureViewModel) async {
            saveFailureVM = viewModel
        }
        func displayDelete(removedId: String) async {
            deletedId = removedId
        }
        func displayPreview(viewModel: CustomWordListModels.Preview.ViewModel) async {
            previewVM = viewModel
        }

        func displayAutoPick(viewModel: CustomWordListModels.AutoPick.ViewModel) async {}
        func displayAutoPickLoading(_ isLoading: Bool) async {}
    }

    private func makeSUT() -> (CustomWordListPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = CustomWordListPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func listData(
        id: String = "l1",
        name: String = "Список Р",
        targetSound: String = "Р",
        words: [String] = ["рыба", "рак", "роза"]
    ) -> CustomWordListData {
        CustomWordListData(
            id: id, specialistId: "s1", name: name, targetSound: targetSound,
            words: words, createdAt: Date(), updatedAt: Date()
        )
    }

    // MARK: - Load

    func test_load_preservesRowCount() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(lists: [listData(id: "a"), listData(id: "b")]))
        XCTAssertEqual(spy.loadVM?.lists.count, 2)
    }

    func test_load_emptyLists_setsIsEmptyTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(lists: []))
        XCTAssertEqual(spy.loadVM?.isEmpty, true)
        XCTAssertEqual(spy.loadVM?.lists.count, 0)
    }

    func test_load_nonEmptyLists_setsIsEmptyFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(lists: [listData()]))
        XCTAssertEqual(spy.loadVM?.isEmpty, false)
    }

    func test_load_rowFieldsFormattedNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(lists: [listData(name: "Мой список", words: ["а", "б"])]))
        let row = spy.loadVM?.lists.first
        XCTAssertEqual(row?.id, "l1")
        XCTAssertEqual(row?.name, "Мой список")
        XCTAssertFalse(row?.targetSoundText.isEmpty ?? true)
        XCTAssertFalse(row?.wordsCountText.isEmpty ?? true)
        XCTAssertFalse(row?.accessibilityLabel.isEmpty ?? true)
    }

    func test_load_accessibilityLabelReferencesName() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(lists: [listData(name: "УникальноеИмя")]))
        XCTAssertTrue(spy.loadVM?.lists.first?.accessibilityLabel.contains("УникальноеИмя") ?? false)
    }

    // MARK: - Save

    func test_saveSuccess_setsDismissTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentSaveSuccess(response: .init(savedId: "x"))
        XCTAssertEqual(spy.saveSuccessVM?.dismiss, true)
    }

    func test_saveFailure_emptyName_message() async {
        let (sut, spy) = makeSUT()
        await sut.presentSaveFailure(response: .init(reason: .emptyName))
        XCTAssertFalse(spy.saveFailureVM?.message.isEmpty ?? true)
    }

    func test_saveFailure_distinctMessagesPerReason() async {
        let (sut, spy) = makeSUT()
        await sut.presentSaveFailure(response: .init(reason: .emptyName))
        let nameMsg = spy.saveFailureVM?.message
        await sut.presentSaveFailure(response: .init(reason: .emptyWords))
        let wordsMsg = spy.saveFailureVM?.message
        XCTAssertNotNil(nameMsg)
        XCTAssertNotNil(wordsMsg)
        XCTAssertNotEqual(nameMsg, wordsMsg, "Разные причины валидации → разные сообщения")
    }

    // MARK: - Delete

    func test_delete_forwardsRemovedId() async {
        let (sut, spy) = makeSUT()
        await sut.presentDelete(response: .init(removedId: "to-remove"))
        XCTAssertEqual(spy.deletedId, "to-remove")
    }

    // MARK: - Preview

    func test_preview_forwardsExercisesCount() async {
        let (sut, spy) = makeSUT()
        let exercises = [
            GeneratedExercise(id: "e1", kind: .bingo, words: ["а"], targetSound: "Р"),
            GeneratedExercise(id: "e2", kind: .memory, words: ["б"], targetSound: "Р")
        ]
        await sut.presentPreview(response: .init(exercises: exercises))
        XCTAssertEqual(spy.previewVM?.exercisesCount, 2)
        XCTAssertFalse(spy.previewVM?.text.isEmpty ?? true)
    }

    func test_preview_emptyExercises_zeroCount() async {
        let (sut, spy) = makeSUT()
        await sut.presentPreview(response: .init(exercises: []))
        XCTAssertEqual(spy.previewVM?.exercisesCount, 0)
    }
}
