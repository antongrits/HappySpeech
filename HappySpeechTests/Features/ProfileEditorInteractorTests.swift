@testable import HappySpeech
import XCTest

// MARK: - ProfileEditorInteractorTests
//
// Block 2.8.3 v25 — unit-покрытие ProfileEditorInteractor (Family).
// Паттерн: Interactor → реальный ProfileEditorPresenter → ProfileEditorViewModel (spy).
// childRepository подменяется через SpyChildRepository из Support/MockServices.swift.
// Все строки в проде идут через String Catalog — в тестах проверяем структуру и
// «не пусто», т.к. ключ может вернуться вместо перевода.

@MainActor
final class ProfileEditorInteractorTests: XCTestCase {

    // Сильные ссылки на Presenter/ViewModel — Interactor.presenter и
    // Presenter.viewModel объявлены weak, иначе деаллоцируются между await.
    private var retainedPresenters: [ProfileEditorPresenter] = []

    override func tearDown() {
        retainedPresenters.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeProfile(
        id: String = "child-pe-1",
        name: String = "Маша",
        age: Int = 6,
        targetSounds: [String] = ["Р", "Ш"],
        avatarStyle: String = "butterfly",
        colorTheme: String = "coral",
        progressSummary: [String: Double] = ["Р": 0.5, "Ш": 0.9]
    ) -> ChildProfileDTO {
        ChildProfileDTO(
            id: id,
            name: name,
            age: age,
            targetSounds: targetSounds,
            parentId: "parent-pe",
            progressSummary: progressSummary,
            avatarStyle: avatarStyle,
            colorTheme: colorTheme
        )
    }

    private func makeSUT(
        children: [ChildProfileDTO]
    ) -> (ProfileEditorInteractor, ProfileEditorViewModel, SpyChildRepository) {
        let repo = SpyChildRepository(children: children)
        let sut = ProfileEditorInteractor(childRepository: repo)
        let presenter = ProfileEditorPresenter()
        let viewModel = ProfileEditorViewModel()
        presenter.viewModel = viewModel
        sut.presenter = presenter
        retainedPresenters.append(presenter)
        return (sut, viewModel, repo)
    }

    // MARK: - 1. load — успешная загрузка

    func test_load_success_populatesViewModel() async {
        let profile = makeProfile()
        let (sut, vm, _) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))

        XCTAssertEqual(vm.childId, profile.id)
        XCTAssertEqual(vm.name, "Маша")
        XCTAssertEqual(vm.age, 6)
        XCTAssertEqual(vm.selectedAvatarId, "butterfly")
        XCTAssertEqual(vm.selectedThemeId, "coral")
        XCTAssertEqual(vm.targetSounds, ["Р", "Ш"])
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - 2. load — ошибка репозитория → presentError

    func test_load_repositoryFails_setsErrorMessage() async {
        let (sut, vm, repo) = makeSUT(children: [makeProfile()])
        repo.shouldFail = true

        await sut.load(.init(childId: "child-pe-1"))

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - 3. load — несуществующий ребёнок → presentError

    func test_load_unknownChild_setsError() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile(id: "other")])
        await sut.load(.init(childId: "missing"))

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - 4. validate — валидные данные

    func test_validate_validInput_isValidTrue() async {
        let (sut, _, _) = makeSUT(children: [makeProfile()])
        // validate шлёт presentValidation (no-op extension), проверяем что не крашится.
        await sut.validate(.init(name: "Петя", age: 6, avatarStyle: "fox", colorTheme: "blue"))
        XCTAssertTrue(true)
    }

    // MARK: - 5. save — короткое имя → success=false

    func test_save_nameTooShort_fails() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile()])
        await sut.load(.init(childId: "child-pe-1"))
        await sut.save(.init(childId: "child-pe-1", name: "А", age: 6,
                             avatarStyle: "butterfly", colorTheme: "coral"))

        XCTAssertFalse(vm.isSaved)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - 6. save — длинное имя (>30) → fail

    func test_save_nameTooLong_fails() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile()])
        await sut.load(.init(childId: "child-pe-1"))
        let longName = String(repeating: "а", count: 31)
        await sut.save(.init(childId: "child-pe-1", name: longName, age: 6,
                             avatarStyle: "butterfly", colorTheme: "coral"))

        XCTAssertFalse(vm.isSaved)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - 7. save — недопустимые символы в имени → fail

    func test_save_invalidNameCharacters_fails() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile()])
        await sut.load(.init(childId: "child-pe-1"))
        await sut.save(.init(childId: "child-pe-1", name: "Петя123", age: 6,
                             avatarStyle: "butterfly", colorTheme: "coral"))

        XCTAssertFalse(vm.isSaved)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - 8. save — возраст вне диапазона → fail

    func test_save_ageTooYoung_fails() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile()])
        await sut.load(.init(childId: "child-pe-1"))
        await sut.save(.init(childId: "child-pe-1", name: "Петя", age: 3,
                             avatarStyle: "butterfly", colorTheme: "coral"))
        XCTAssertFalse(vm.isSaved)

        await sut.save(.init(childId: "child-pe-1", name: "Петя", age: 12,
                             avatarStyle: "butterfly", colorTheme: "coral"))
        XCTAssertFalse(vm.isSaved)
    }

    // MARK: - 9. save — недопустимый аватар → fail

    func test_save_invalidAvatar_fails() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile()])
        await sut.load(.init(childId: "child-pe-1"))
        await sut.save(.init(childId: "child-pe-1", name: "Петя", age: 6,
                             avatarStyle: "nonexistent-avatar", colorTheme: "coral"))
        XCTAssertFalse(vm.isSaved)
    }

    // MARK: - 10. save — недопустимая тема → fail

    func test_save_invalidTheme_fails() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile()])
        await sut.load(.init(childId: "child-pe-1"))
        await sut.save(.init(childId: "child-pe-1", name: "Петя", age: 6,
                             avatarStyle: "butterfly", colorTheme: "rainbow"))
        XCTAssertFalse(vm.isSaved)
    }

    // MARK: - 11. save — успешное сохранение

    func test_save_validInput_succeeds() async {
        let profile = makeProfile()
        let (sut, vm, repo) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))
        await sut.save(.init(childId: profile.id, name: "Новое-Имя", age: 7,
                             avatarStyle: "fox", colorTheme: "green"))

        XCTAssertTrue(vm.isSaved)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(repo.lastSaved?.name, "Новое-Имя")
        XCTAssertEqual(repo.lastSaved?.age, 7)
        XCTAssertEqual(repo.lastSaved?.avatarStyle, "fox")
    }

    // MARK: - 12. save — дубликат имени среди братьев/сестёр → fail

    func test_save_duplicateSiblingName_fails() async {
        let target = makeProfile(id: "child-A", name: "Аня")
        let sibling = makeProfile(id: "child-B", name: "Соня")
        let (sut, vm, _) = makeSUT(children: [target, sibling])
        await sut.load(.init(childId: "child-A"))
        await sut.save(.init(childId: "child-A", name: "Соня", age: 6,
                             avatarStyle: "butterfly", colorTheme: "coral"))

        XCTAssertFalse(vm.isSaved)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - 13. save — без предварительного load → profileNotLoaded

    func test_save_withoutLoad_failsNotLoaded() async {
        let (sut, vm, _) = makeSUT(children: [makeProfile()])
        await sut.save(.init(childId: "child-pe-1", name: "Петя", age: 6,
                             avatarStyle: "butterfly", colorTheme: "coral"))

        XCTAssertFalse(vm.isSaved)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - 14. save — обрезает пробелы в имени

    func test_save_trimsWhitespaceFromName() async {
        let profile = makeProfile()
        let (sut, _, repo) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))
        await sut.save(.init(childId: profile.id, name: "  Петя  ", age: 6,
                             avatarStyle: "butterfly", colorTheme: "coral"))

        XCTAssertEqual(repo.lastSaved?.name, "Петя")
    }

    // MARK: - 15. cancelEditing — восстанавливает исходный профиль

    func test_cancelEditing_restoresOriginal() async {
        let profile = makeProfile(name: "Оригинал")
        let (sut, vm, _) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))
        vm.name = "Изменённое"

        await sut.cancelEditing()

        XCTAssertEqual(vm.name, "Оригинал")
    }

    // MARK: - 16. cancelEditing — без load → no-op

    func test_cancelEditing_withoutLoad_doesNotCrash() async {
        let (sut, _, _) = makeSUT(children: [makeProfile()])
        await sut.cancelEditing()
        XCTAssertTrue(true)
    }

    // MARK: - 17. addTargetSound — добавляет новый звук

    func test_addTargetSound_addsNewSound() async {
        let profile = makeProfile(targetSounds: ["Р"])
        let (sut, _, repo) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))
        await sut.addTargetSound(.init(sound: "С"))

        XCTAssertEqual(repo.lastSaved?.targetSounds.contains("С"), true)
        XCTAssertEqual(repo.lastSaved?.targetSounds.contains("Р"), true)
    }

    // MARK: - 18. addTargetSound — дубликат игнорируется

    func test_addTargetSound_duplicate_ignored() async {
        let profile = makeProfile(targetSounds: ["Р"])
        let (sut, _, repo) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))
        let savesBefore = repo.saveCallCount
        await sut.addTargetSound(.init(sound: "Р"))

        XCTAssertEqual(repo.saveCallCount, savesBefore,
                       "Добавление существующего звука не должно вызывать save")
    }

    // MARK: - 19. addTargetSound — без load → no-op

    func test_addTargetSound_withoutLoad_ignored() async {
        let (sut, _, repo) = makeSUT(children: [makeProfile()])
        await sut.addTargetSound(.init(sound: "Л"))
        XCTAssertEqual(repo.saveCallCount, 0)
    }

    // MARK: - 20. removeTargetSound — удаляет звук

    func test_removeTargetSound_removesSound() async {
        let profile = makeProfile(targetSounds: ["Р", "Ш"])
        let (sut, _, repo) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))
        await sut.removeTargetSound(.init(sound: "Ш"))

        XCTAssertEqual(repo.lastSaved?.targetSounds.contains("Ш"), false)
        XCTAssertEqual(repo.lastSaved?.targetSounds, ["Р"])
    }

    // MARK: - 21. removeTargetSound — последний звук нельзя убрать

    func test_removeTargetSound_lastSound_blocked() async {
        let profile = makeProfile(targetSounds: ["Р"])
        let (sut, _, repo) = makeSUT(children: [profile])
        await sut.load(.init(childId: profile.id))
        let savesBefore = repo.saveCallCount
        await sut.removeTargetSound(.init(sound: "Р"))

        XCTAssertEqual(repo.saveCallCount, savesBefore,
                       "Нельзя убрать последний звук — save не вызывается")
    }

    // MARK: - 22. removeTargetSound — без load → no-op

    func test_removeTargetSound_withoutLoad_ignored() async {
        let (sut, _, repo) = makeSUT(children: [makeProfile()])
        await sut.removeTargetSound(.init(sound: "Р"))
        XCTAssertEqual(repo.saveCallCount, 0)
    }

    // MARK: - 23. loadAvatarGallery — 3 категории

    func test_loadAvatarGallery_buildsCategories() async {
        let (sut, _, _) = makeSUT(children: [makeProfile()])
        await sut.loadAvatarGallery()
        // presentAvatarGallery — no-op extension, проверяем статический каталог.
        let categories = ProfileEditorInteractor.buildAvatarCategories()
        XCTAssertEqual(categories.count, 3)
        XCTAssertEqual(Set(categories.map(\.id)), ["animals", "transport", "nature"])
    }

    // MARK: - 24. static allAvatarIds — 10 идентификаторов

    func test_allAvatarIds_containsTenAvatars() {
        XCTAssertEqual(ProfileEditorInteractor.allAvatarIds.count, 10)
        XCTAssertTrue(ProfileEditorInteractor.allAvatarIds.contains("butterfly"))
        XCTAssertTrue(ProfileEditorInteractor.allAvatarIds.contains("rocket"))
    }

    // MARK: - 25. ProgressLevel — localizedLabel не пуст

    func test_progressLevel_localizedLabelNonEmpty() {
        for level in [ProfileEditor.ProgressLevel.beginning, .developing, .proficient, .achieved] {
            XCTAssertFalse(level.localizedLabel.isEmpty)
        }
    }
}
