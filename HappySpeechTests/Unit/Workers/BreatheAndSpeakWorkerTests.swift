@testable import HappySpeech
import XCTest

// MARK: - BreatheAndSpeakWorkerTests
//
// Фаза E, Волна 7. Покрывает подбор артикуляционно-дыхательного комплекса
// под целевые звуки ребёнка + fallback при сбое чтения профиля.

@MainActor
final class BreatheAndSpeakWorkerTests: XCTestCase {

    private func makeChild(id: String = "c-1", sounds: [String]) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 6, targetSounds: sounds, parentId: "p-1")
    }

    // MARK: - Selection by target sound

    func test_buildComplex_selectsComplexMatchingFirstTargetSound() async {
        let repo = MockChildRepository(children: [makeChild(sounds: ["Р"])])
        let sut = BreatheAndSpeakWorker(childRepository: repo)

        let response = await sut.buildComplex(childId: "c-1")

        XCTAssertEqual(response.complex.soundGroup, "Р")
        XCTAssertEqual(response.complex.id, "complex-r")
    }

    func test_buildComplex_selectsShComplex() async {
        let repo = MockChildRepository(children: [makeChild(sounds: ["Ш"])])
        let sut = BreatheAndSpeakWorker(childRepository: repo)

        let response = await sut.buildComplex(childId: "c-1")

        XCTAssertEqual(response.complex.soundGroup, "Ш")
    }

    func test_buildComplex_caseInsensitiveSoundMatch() async {
        let repo = MockChildRepository(children: [makeChild(sounds: ["л"])])
        let sut = BreatheAndSpeakWorker(childRepository: repo)

        let response = await sut.buildComplex(childId: "c-1")

        XCTAssertEqual(response.complex.soundGroup, "Л")
    }

    func test_buildComplex_picksFirstMatchingAcrossMultipleSounds() async {
        // Первый известный звук в списке определяет комплекс ("З" не имеет
        // комплекса, "С" — имеет).
        let repo = MockChildRepository(children: [makeChild(sounds: ["З", "С"])])
        let sut = BreatheAndSpeakWorker(childRepository: repo)

        let response = await sut.buildComplex(childId: "c-1")

        XCTAssertEqual(response.complex.soundGroup, "С")
    }

    // MARK: - Fallbacks

    func test_buildComplex_unknownSounds_fallsBackToFirstComplex() async {
        let repo = MockChildRepository(children: [makeChild(sounds: ["Щ", "Й"])])
        let sut = BreatheAndSpeakWorker(childRepository: repo)

        let response = await sut.buildComplex(childId: "c-1")

        // Первый комплекс корпуса — "Р".
        XCTAssertEqual(response.complex.id, "complex-r")
    }

    func test_buildComplex_repositoryFailure_usesDefaultComplex() async {
        // Несуществующий ребёнок → fetch бросает → пустые targetSounds →
        // fallback на первый комплекс корпуса.
        let repo = MockChildRepository(children: [])
        let sut = BreatheAndSpeakWorker(childRepository: repo)

        let response = await sut.buildComplex(childId: "missing")

        XCTAssertEqual(response.complex.id, "complex-r")
        XCTAssertFalse(response.complex.exercises.isEmpty)
    }

    func test_buildComplex_complexHasExercisesEndingWithBreathing() async {
        let repo = MockChildRepository(children: [makeChild(sounds: ["С"])])
        let sut = BreatheAndSpeakWorker(childRepository: repo)

        let response = await sut.buildComplex(childId: "c-1")

        XCTAssertFalse(response.complex.exercises.isEmpty)
        // Методическая прогрессия: завершается дыхательным упражнением.
        XCTAssertEqual(response.complex.exercises.last?.kind, .breathing)
    }
}
