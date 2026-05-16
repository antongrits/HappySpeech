@testable import HappySpeech
import XCTest

// MARK: - ProfileEditorPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие ProfileEditorPresenter (0% → цель ≥90%).
//
// Presenter мутирует @Observable ProfileEditorViewModel напрямую.
// Тесты создают ViewModel, присоединяют и проверяют её свойства.

@MainActor
final class ProfileEditorPresenterTests: XCTestCase {

    private func makeSUT() -> (ProfileEditorPresenter, ProfileEditorViewModel) {
        let viewModel = ProfileEditorViewModel()
        let presenter = ProfileEditorPresenter()
        presenter.viewModel = viewModel
        return (presenter, viewModel)
    }

    // MARK: - presentLoaded

    func test_presentLoaded_childIdSet() {
        let (sut, vm) = makeSUT()
        sut.presentLoaded(.init(childId: "c-42", name: "Маша", age: 7, avatarStyle: "star", colorTheme: "blue", targetSounds: ["С"]))
        XCTAssertEqual(vm.childId, "c-42")
    }

    func test_presentLoaded_nameSet() {
        let (sut, vm) = makeSUT()
        sut.presentLoaded(.init(childId: "c-1", name: "Ваня", age: 6, avatarStyle: "butterfly", colorTheme: "coral", targetSounds: []))
        XCTAssertEqual(vm.name, "Ваня")
    }

    func test_presentLoaded_ageSet() {
        let (sut, vm) = makeSUT()
        sut.presentLoaded(.init(childId: "c-1", name: "Маша", age: 8, avatarStyle: "rocket", colorTheme: "green", targetSounds: []))
        XCTAssertEqual(vm.age, 8)
    }

    func test_presentLoaded_avatarStyleSet() {
        let (sut, vm) = makeSUT()
        sut.presentLoaded(.init(childId: "c-1", name: "Маша", age: 7, avatarStyle: "dragon", colorTheme: "purple", targetSounds: []))
        XCTAssertEqual(vm.selectedAvatarId, "dragon")
    }

    func test_presentLoaded_colorThemeSet() {
        let (sut, vm) = makeSUT()
        sut.presentLoaded(.init(childId: "c-1", name: "Маша", age: 6, avatarStyle: "unicorn", colorTheme: "yellow", targetSounds: []))
        XCTAssertEqual(vm.selectedThemeId, "yellow")
    }

    func test_presentLoaded_targetSoundsSet() {
        let (sut, vm) = makeSUT()
        sut.presentLoaded(.init(childId: "c-1", name: "Маша", age: 6, avatarStyle: "butterfly", colorTheme: "coral", targetSounds: ["С", "Р"]))
        XCTAssertEqual(vm.targetSounds, ["С", "Р"])
    }

    func test_presentLoaded_isLoadingSetFalse() {
        let (sut, vm) = makeSUT()
        vm.isLoading = true
        sut.presentLoaded(.init(childId: "c-1", name: "Маша", age: 6, avatarStyle: "butterfly", colorTheme: "coral", targetSounds: []))
        XCTAssertFalse(vm.isLoading)
    }

    func test_presentLoaded_errorMessageCleared() {
        let (sut, vm) = makeSUT()
        vm.errorMessage = "Старая ошибка"
        sut.presentLoaded(.init(childId: "c-1", name: "Маша", age: 6, avatarStyle: "butterfly", colorTheme: "coral", targetSounds: []))
        XCTAssertNil(vm.errorMessage)
    }

    func test_presentLoaded_noViewModel_doesNotCrash() {
        let presenter = ProfileEditorPresenter()
        presenter.viewModel = nil
        // Should not crash
        presenter.presentLoaded(.init(childId: "c-1", name: "Маша", age: 6, avatarStyle: "butterfly", colorTheme: "coral", targetSounds: []))
    }

    // MARK: - presentLoading

    func test_presentLoading_isLoadingSetTrue() {
        let (sut, vm) = makeSUT()
        sut.presentLoading()
        XCTAssertTrue(vm.isLoading)
    }

    func test_presentLoading_errorMessageCleared() {
        let (sut, vm) = makeSUT()
        vm.errorMessage = "Ошибка"
        sut.presentLoading()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - presentSaving

    func test_presentSaving_isSavingSetTrue() {
        let (sut, vm) = makeSUT()
        sut.presentSaving()
        XCTAssertTrue(vm.isSaving)
    }

    func test_presentSaving_errorMessageCleared() {
        let (sut, vm) = makeSUT()
        vm.errorMessage = "Ошибка"
        sut.presentSaving()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - presentSaved

    func test_presentSaved_success_isSavedTrue() {
        let (sut, vm) = makeSUT()
        sut.presentSaved(.init(success: true, errorMessage: nil))
        XCTAssertTrue(vm.isSaved)
    }

    func test_presentSaved_success_isSavingFalse() {
        let (sut, vm) = makeSUT()
        vm.isSaving = true
        sut.presentSaved(.init(success: true, errorMessage: nil))
        XCTAssertFalse(vm.isSaving)
    }

    func test_presentSaved_success_errorMessageNil() {
        let (sut, vm) = makeSUT()
        sut.presentSaved(.init(success: true, errorMessage: nil))
        XCTAssertNil(vm.errorMessage)
    }

    func test_presentSaved_failure_isSavingFalse() {
        let (sut, vm) = makeSUT()
        vm.isSaving = true
        sut.presentSaved(.init(success: false, errorMessage: "Ошибка сервера"))
        XCTAssertFalse(vm.isSaving)
    }

    func test_presentSaved_failure_errorMessageSet() {
        let (sut, vm) = makeSUT()
        sut.presentSaved(.init(success: false, errorMessage: "Нет соединения"))
        XCTAssertEqual(vm.errorMessage, "Нет соединения")
    }

    func test_presentSaved_failure_noErrorMessage_usesDefault() {
        let (sut, vm) = makeSUT()
        sut.presentSaved(.init(success: false, errorMessage: nil))
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_presentSaved_failure_isSavedFalse() {
        let (sut, vm) = makeSUT()
        sut.presentSaved(.init(success: false, errorMessage: "Ошибка"))
        XCTAssertFalse(vm.isSaved)
    }

    // MARK: - presentError

    func test_presentError_isLoadingFalse() {
        let (sut, vm) = makeSUT()
        vm.isLoading = true
        sut.presentError(NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка сети"]))
        XCTAssertFalse(vm.isLoading)
    }

    func test_presentError_isSavingFalse() {
        let (sut, vm) = makeSUT()
        vm.isSaving = true
        sut.presentError(NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка"]))
        XCTAssertFalse(vm.isSaving)
    }

    func test_presentError_errorMessageSet() {
        let (sut, vm) = makeSUT()
        let error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Тест ошибки"])
        sut.presentError(error)
        XCTAssertNotNil(vm.errorMessage)
    }
}
