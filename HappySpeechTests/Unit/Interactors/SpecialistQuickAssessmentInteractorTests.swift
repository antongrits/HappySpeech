@testable import HappySpeech
import XCTest

// MARK: - SpecialistQuickAssessmentInteractorTests
//
// SpecialistQuickAssessmentInteractor is a thin VIP MVP variant (@Observable). It
// holds a star rating (0...5) per Category; set(_:stars:) clamps the value into
// range, locates the matching rating and invalidates the saved flag, while save()
// stamps isSaved and reset() restores the initial all-zero state. Tests cover the
// seed, clamping/guards, the save/reset transitions and the averageStars derive.
// (Category.title/.subtitle/.iconSystemName maps are presentational — skipped.)

@MainActor
final class SpecialistQuickAssessmentInteractorTests: XCTestCase {

    private typealias Category = SpecialistQuickAssessmentModels.Category

    /// Изолированный UserDefaults на тест, чтобы персистентность не протекала
    /// между прогонами и тестами.
    private func ephemeralDefaults() -> UserDefaults {
        let suite = "test.sqa.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite) ?? .standard
    }

    private func makeSUT(
        defaults: UserDefaults? = nil
    ) -> SpecialistQuickAssessmentInteractor {
        SpecialistQuickAssessmentInteractor(
            childId: "child-1",
            specialistId: "spec-1",
            defaults: defaults ?? ephemeralDefaults()
        )
    }

    // MARK: - Init / seed

    func test_init_storesIdentifiers() {
        let sut = SpecialistQuickAssessmentInteractor(childId: "c-9", specialistId: "s-3")
        XCTAssertEqual(sut.childId, "c-9")
        XCTAssertEqual(sut.specialistId, "s-3")
    }

    func test_initialState_allCategoriesZeroNotSaved() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
        XCTAssertFalse(sut.state.isSaved)
        XCTAssertEqual(Set(sut.state.ratings.map(\.id)), Set(Category.allCases))
        XCTAssertTrue(sut.state.ratings.allSatisfy { $0.stars == 0 })
    }

    // MARK: - set

    func test_set_storesStars() {
        let sut = makeSUT()
        sut.set(.articulation, stars: 4)
        XCTAssertEqual(sut.state.ratings.first { $0.id == .articulation }?.stars, 4)
    }

    func test_set_clampsAboveFive() {
        let sut = makeSUT()
        sut.set(.engagement, stars: 99)
        XCTAssertEqual(sut.state.ratings.first { $0.id == .engagement }?.stars, 5)
    }

    func test_set_clampsBelowZero() {
        let sut = makeSUT()
        sut.set(.stamina, stars: -7)
        XCTAssertEqual(sut.state.ratings.first { $0.id == .stamina }?.stars, 0)
    }

    func test_set_boundaryValuesUnchanged() {
        let sut = makeSUT()
        sut.set(.progress, stars: 0)
        XCTAssertEqual(sut.state.ratings.first { $0.id == .progress }?.stars, 0)
        sut.set(.progress, stars: 5)
        XCTAssertEqual(sut.state.ratings.first { $0.id == .progress }?.stars, 5)
    }

    func test_set_invalidatesSavedFlag() {
        let sut = makeSUT()
        sut.save()
        XCTAssertTrue(sut.state.isSaved)
        sut.set(.comprehension, stars: 3)
        XCTAssertFalse(sut.state.isSaved)
    }

    func test_set_onlyAffectsTargetCategory() {
        let sut = makeSUT()
        sut.set(.articulation, stars: 5)
        let others = sut.state.ratings.filter { $0.id != .articulation }
        XCTAssertTrue(others.allSatisfy { $0.stars == 0 })
    }

    // MARK: - save

    func test_save_setsSavedFlag() {
        let sut = makeSUT()
        sut.set(.engagement, stars: 3)
        sut.save()
        XCTAssertTrue(sut.state.isSaved)
    }

    func test_save_doesNotMutateRatings() {
        let sut = makeSUT()
        sut.set(.engagement, stars: 3)
        let before = sut.state.ratings
        sut.save()
        XCTAssertEqual(sut.state.ratings, before)
    }

    // MARK: - Persistence round-trip (реальное сохранение в UserDefaults)

    func test_save_thenReload_persistsRatings() {
        let defaults = ephemeralDefaults()
        let first = SpecialistQuickAssessmentInteractor(
            childId: "child-7", specialistId: "spec-7", defaults: defaults
        )
        first.set(.articulation, stars: 4)
        first.set(.stamina, stars: 2)
        first.save()

        // Новый интерактор с тем же хранилищем должен подхватить сохранённую оценку.
        let reloaded = SpecialistQuickAssessmentInteractor(
            childId: "child-7", specialistId: "spec-7", defaults: defaults
        )
        XCTAssertTrue(reloaded.state.isSaved)
        XCTAssertEqual(reloaded.state.ratings.first { $0.id == .articulation }?.stars, 4)
        XCTAssertEqual(reloaded.state.ratings.first { $0.id == .stamina }?.stars, 2)
    }

    func test_load_noPriorData_keepsInitial() {
        let sut = makeSUT() // свежий изолированный suite — данных нет
        XCTAssertEqual(sut.state, .initial)
    }

    // MARK: - reset

    func test_reset_restoresInitial() {
        let sut = makeSUT()
        sut.set(.engagement, stars: 4)
        sut.set(.stamina, stars: 2)
        sut.save()
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
        XCTAssertFalse(sut.state.isSaved)
        XCTAssertTrue(sut.state.ratings.allSatisfy { $0.stars == 0 })
    }

    // MARK: - averageStars

    func test_averageStars_initialIsZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.averageStars, 0, accuracy: 0.0001)
    }

    func test_averageStars_computesMean() {
        let sut = makeSUT()
        // All five categories: 5,5,5,5,5 -> 5.0
        for category in Category.allCases { sut.set(category, stars: 5) }
        XCTAssertEqual(sut.state.averageStars, 5.0, accuracy: 0.0001)
    }

    func test_averageStars_mixedValues() {
        let sut = makeSUT()
        let cats = Category.allCases
        // 4 + 0 + 0 + 0 + 0 = 4 over 5 categories = 0.8
        sut.set(cats[0], stars: 4)
        XCTAssertEqual(sut.state.averageStars, 4.0 / Double(cats.count), accuracy: 0.0001)
    }

    func test_averageStars_emptyRatings_isZero() {
        var state = SpecialistQuickAssessmentModels.ViewState.initial
        state.ratings = []
        XCTAssertEqual(state.averageStars, 0)
    }
}
