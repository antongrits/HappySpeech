@testable import HappySpeech
import XCTest

// MARK: - AdaptivePlannerConfusionPairTests
//
// Покрывает интеграцию «Фонемного паспорта» в дневной маршрут (v17): если у
// ребёнка есть слабейшая confusion-пара (target ↔ конкурент), планировщик
// добавляет адресное упражнение minimal-pairs на эту пару. Без данных / без
// сервиса — план не меняется (graceful).

final class AdaptivePlannerConfusionPairTests: XCTestCase {

    private func child() -> ChildProfileDTO {
        ChildProfileDTO(id: "child-1", name: "Тест", age: 6, targetSounds: ["С"], parentId: "p")
    }

    /// Набор наблюдений «р→л» с низким GOP — делает 'r' слабейшей проблемой
    /// с доминирующим конкурентом 'l'.
    private func rToLObservations() -> [PhonemeObservationDTO] {
        (0..<10).map { index in
            PhonemeObservationDTO(
                id: "obs-r-\(index)",
                childId: "child-1",
                phoneme: "r",
                wordId: "word_rak",
                position: "initial",
                gop: -2.0,
                posterior: 0.1,
                defect: "age_substitution",
                competitor: "l",
                date: Date().addingTimeInterval(Double(index) * 60)
            )
        }
    }

    // MARK: - Пара добавляется в начало маршрута

    func test_weakestConfusionPair_addsMinimalPairsStep() async throws {
        let profileService = MockPhonemeProfileService(observations: rToLObservations())
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: []),
            reviewScheduler: nil,
            phonemeProfileService: profileService
        )

        let route = try await planner.buildDailyRoute(for: "child-1")

        let minimalPairsStep = route.steps.first { $0.templateType == .minimalPairs }
        let step = try XCTUnwrap(minimalPairsStep, "Должен присутствовать шаг minimal-pairs на слабейшую пару")
        XCTAssertEqual(step.targetSound, "Р-Л", "Пара r↔l → контраст 'Р-Л'")
        XCTAssertEqual(step.track, .phonemic, "Дифференциация — фонематический трек")
        // Шаг confusion-дифференциации идёт в самом начале маршрута.
        XCTAssertEqual(route.steps.first?.templateType, .minimalPairs, "Confusion-шаг ставится в начало")
    }

    // MARK: - Без профиль-сервиса план не меняется (back-compat)

    func test_noProfileService_routeUnchanged() async throws {
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: []),
            reviewScheduler: nil,
            phonemeProfileService: nil
        )

        let route = try await planner.buildDailyRoute(for: "child-1")
        // Без паспорта minimal-pairs может появиться только из штатной логики stage,
        // но НЕ как первый шаг с фонематическим треком на confusion-пару.
        XCTAssertFalse(
            route.steps.first?.track == .phonemic && route.steps.first?.templateType == .minimalPairs,
            "Без профиль-сервиса confusion-шаг не добавляется"
        )
    }

    // MARK: - Пустой профиль → план не меняется

    func test_emptyProfile_routeUnchanged() async throws {
        let profileService = MockPhonemeProfileService(observations: [])
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: []),
            reviewScheduler: nil,
            phonemeProfileService: profileService
        )

        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertFalse(
            route.steps.first?.track == .phonemic && route.steps.first?.templateType == .minimalPairs,
            "Пустой паспорт → confusion-шаг не добавляется"
        )
    }

    // MARK: - Маппинг confusion-пары в контраст с реальным контентом

    func test_minimalPairsContrast_resolvesSupportedPairs() {
        XCTAssertEqual(LiveAdaptivePlannerService.minimalPairsContrast(targetIPA: "r", competitorIPA: "l"), "Р-Л")
        XCTAssertEqual(LiveAdaptivePlannerService.minimalPairsContrast(targetIPA: "s", competitorIPA: "ʂ"), "С-Ш")
        // Обратная ориентация тоже резолвится в существующий контраст.
        XCTAssertEqual(LiveAdaptivePlannerService.minimalPairsContrast(targetIPA: "ʂ", competitorIPA: "s"), "С-Ш")
    }

    func test_minimalPairsContrast_returnsNil_whenNoContent() {
        // 'r' ↔ 'm' — пары нет в каталоге → nil (не выдумываем контент).
        XCTAssertNil(LiveAdaptivePlannerService.minimalPairsContrast(targetIPA: "r", competitorIPA: "m"))
        // Одинаковая буква (target == competitor) → nil.
        XCTAssertNil(LiveAdaptivePlannerService.minimalPairsContrast(targetIPA: "l", competitorIPA: "lʲ"))
    }
}
