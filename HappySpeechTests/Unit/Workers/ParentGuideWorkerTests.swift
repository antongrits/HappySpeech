@testable import HappySpeech
import XCTest

// MARK: - ParentGuideWorkerTests
//
// Фаза E, Волна 8. Покрывает реальную логику ParentGuideWorker: персистентность
// «прочитано» / «избранное» в изолированном UserDefaults (markRead идемпотентен,
// toggleFavorite возвращает новое состояние и переключается туда-обратно),
// маппинг целевых звуков ребёнка в группы (childSoundGroups, дедупликация),
// fallback при сбое профиля. Также — чистый маппинг ParentGuideCorpus.soundGroup.
// loadLessons возвращает корпус (контентный пак / fallback) — проверяем непустоту.

@MainActor
final class ParentGuideWorkerTests: XCTestCase {

    private func child(id: String = "c-1", sounds: [String]) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 6, targetSounds: sounds, parentId: "p-1")
    }

    /// Worker с изолированным UserDefaults-suite (очищается в teardown).
    private func makeSUT(children: [ChildProfileDTO] = []) -> ParentGuideWorker {
        let suiteName = "test.parentGuide.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return ParentGuideWorker(
            childRepository: MockChildRepository(children: children),
            defaults: defaults
        )
    }

    // MARK: - loadLessons (корпус / fallback)

    func test_loadLessons_returnsNonEmptyCorpus() async {
        let sut = makeSUT()
        let lessons = await sut.loadLessons()
        XCTAssertFalse(lessons.isEmpty, "Корпус уроков (пак или fallback) не пуст")
    }

    func test_loadLessons_idsAreUnique() async {
        let sut = makeSUT()
        let ids = await sut.loadLessons().map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Идентификаторы уроков уникальны")
    }

    // MARK: - readLessonIds / markRead

    func test_readLessonIds_emptyByDefault() {
        let sut = makeSUT()
        XCTAssertTrue(sut.readLessonIds().isEmpty)
    }

    func test_markRead_addsId() {
        let sut = makeSUT()
        sut.markRead("guide-1")
        XCTAssertTrue(sut.readLessonIds().contains("guide-1"))
    }

    func test_markRead_isIdempotent() {
        let sut = makeSUT()
        sut.markRead("guide-1")
        sut.markRead("guide-1")
        XCTAssertEqual(sut.readLessonIds(), ["guide-1"],
                       "Повторная отметка не дублирует и не теряет id")
    }

    func test_markRead_accumulatesMultiple() {
        let sut = makeSUT()
        sut.markRead("a")
        sut.markRead("b")
        XCTAssertEqual(sut.readLessonIds(), ["a", "b"])
    }

    // MARK: - favoriteLessonIds / toggleFavorite

    func test_favoriteLessonIds_emptyByDefault() {
        let sut = makeSUT()
        XCTAssertTrue(sut.favoriteLessonIds().isEmpty)
    }

    func test_toggleFavorite_firstCallEnables() {
        let sut = makeSUT()
        let isFavorite = sut.toggleFavorite("guide-1")
        XCTAssertTrue(isFavorite)
        XCTAssertTrue(sut.favoriteLessonIds().contains("guide-1"))
    }

    func test_toggleFavorite_secondCallDisables() {
        let sut = makeSUT()
        _ = sut.toggleFavorite("guide-1")
        let isFavorite = sut.toggleFavorite("guide-1")
        XCTAssertFalse(isFavorite)
        XCTAssertFalse(sut.favoriteLessonIds().contains("guide-1"))
    }

    func test_toggleFavorite_independentPerId() {
        let sut = makeSUT()
        _ = sut.toggleFavorite("a")
        _ = sut.toggleFavorite("b")
        _ = sut.toggleFavorite("a") // выключаем a
        XCTAssertFalse(sut.favoriteLessonIds().contains("a"))
        XCTAssertTrue(sut.favoriteLessonIds().contains("b"))
    }

    // MARK: - childSoundGroups

    func test_childSoundGroups_mapsTargetSoundsToGroups() async {
        let sut = makeSUT(children: [child(sounds: ["С", "Ш"])])
        let groups = await sut.childSoundGroups(childId: "c-1")
        XCTAssertEqual(Set(groups), ["whistling", "hissing"])
    }

    func test_childSoundGroups_deduplicatesGroup() async {
        // С и З — обе свистящие → одна группа.
        let sut = makeSUT(children: [child(sounds: ["С", "З"])])
        let groups = await sut.childSoundGroups(childId: "c-1")
        XCTAssertEqual(groups, ["whistling"])
    }

    func test_childSoundGroups_unknownSoundDropped() async {
        let sut = makeSUT(children: [child(sounds: ["Я", "Р"])])
        let groups = await sut.childSoundGroups(childId: "c-1")
        XCTAssertEqual(groups, ["sonants"], "Неизвестный звук «Я» отбрасывается")
    }

    func test_childSoundGroups_missingChild_returnsEmpty() async {
        let sut = makeSUT(children: [])
        let groups = await sut.childSoundGroups(childId: "missing")
        XCTAssertTrue(groups.isEmpty, "Сбой профиля → пустой список групп")
    }

    // MARK: - ParentGuideCorpus.soundGroup (pure mapping)

    func test_corpus_soundGroup_classifiesEachGroup() {
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "С"), "whistling")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "Ц"), "whistling")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "Щ"), "hissing")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "Р"), "sonants")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "Ль"), "sonants")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "К"), "velar")
    }

    func test_corpus_soundGroup_unknownReturnsNil() {
        XCTAssertNil(ParentGuideCorpus.soundGroup(for: "А"))
        XCTAssertNil(ParentGuideCorpus.soundGroup(for: ""))
    }

    func test_corpus_lessonForId_returnsMatchOrNil() async {
        let lessons = ParentGuideCorpus.lessons
        XCTAssertNil(ParentGuideCorpus.lesson(forId: "no-such-id"))
        if let first = lessons.first {
            XCTAssertEqual(ParentGuideCorpus.lesson(forId: first.id)?.id, first.id)
        }
    }
}
