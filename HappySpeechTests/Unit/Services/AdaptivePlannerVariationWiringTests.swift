@testable import HappySpeech
import XCTest

// MARK: - AdaptivePlannerVariationWiringTests (gap #2)
// ==================================================================================
// Интеграция `ContentVariationGenerator` в `LiveAdaptivePlannerService` как gate
// шага маршрута: каждый звуковой шаг наполняется РЕАЛЬНОЙ вариацией контента,
// выбранной адаптивно. Тесты используют детерминированный мок-генератор и
// мок-репозитории — без бандл-паков и без I/O.
// ==================================================================================

// MARK: - Deterministic mock generator

/// Детерминированный мок генератора вариаций: отдаёт фиксированный набор
/// активностей по звуку, заданный в инициализаторе. Считает обращения по звукам
/// — проверяем кэширование (один вызов на звук за проход).
private final class MockVariationGenerator: ContentVariationGenerating, @unchecked Sendable {
    let activitiesBySound: [String: [GeneratedActivity]]
    private(set) var callsBySound: [String: Int] = [:]
    private let lock = NSLock()

    init(activitiesBySound: [String: [GeneratedActivity]]) {
        self.activitiesBySound = activitiesBySound
    }

    func generateActivities(for sound: String) async -> [GeneratedActivity] {
        lock.withLock {
            callsBySound[sound, default: 0] += 1
        }
        return activitiesBySound[sound] ?? []
    }
}

private extension GeneratedActivity {
    static func make(
        sound: String,
        kind: Kind = .sound,
        stage: CorrectionStage,
        theme: String? = nil,
        template: TemplateType,
        minAge: Int = 5,
        difficultyBand: ClosedRange<Int> = 2...2,
        itemCount: Int = 6
    ) -> GeneratedActivity {
        let items = (0..<itemCount).map { idx in
            ContentItem(
                id: "\(sound)-\(stage.rawValue)-\(idx)",
                word: "слово\(idx)",
                imageAsset: "word_\(idx)",
                audioAsset: nil,
                hint: nil,
                stage: stage,
                difficulty: difficultyBand.lowerBound
            )
        }
        let themePart = theme.map { "_\($0)" } ?? ""
        return GeneratedActivity(
            id: "gen_\(sound)_\(stage.rawValue)\(themePart)_\(template.rawValue)",
            kind: kind,
            sound: sound,
            contrastSound: nil,
            stage: stage,
            theme: theme,
            template: template,
            minAge: minAge,
            difficultyBand: difficultyBand,
            items: items,
            requiresMic: false
        )
    }
}

private extension SessionDTO {
    static func make(
        childId: String,
        targetSound: String = "Р",
        stage: CorrectionStage = .wordInit,
        successRate: Double = 0.75,
        daysAgo: Int = 1
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let total = 10
        let correct = Int((Double(total) * successRate).rounded())
        return SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: date,
            templateType: "listen-and-choose",
            targetSound: targetSound,
            stage: stage.rawValue,
            durationSeconds: 300,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}

final class AdaptivePlannerVariationWiringTests: XCTestCase {

    private func child(id: String = "child-1", age: Int = 6, sounds: [String] = ["Р"]) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: age, targetSounds: sounds, parentId: "p")
    }

    // MARK: 1. Без генератора — маршрут НЕ обогащается (back-compat)

    func testNoGenerator_stepsHaveNoVariationId() async throws {
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: [.make(childId: "child-1")])
        )
        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertTrue(route.steps.allSatisfy { $0.variationId == nil },
                      "без генератора шаги остаются базовыми (variationId == nil)")
    }

    // MARK: 2. С генератором — совместимые звуковые шаги получают реальную вариацию

    func testWithGenerator_soundStepsGetVariation() async throws {
        // Покрываем шаблоны, которыми composeRoute наполняет wordInit-маршрут:
        // warmUp=breathing(prep), core=listenAndChoose(wordInit),
        // consolidation=dragAndMatch(wordInit), reward=puzzleReveal(wordInit).
        let activities: [GeneratedActivity] = [
            .make(sound: "Р", stage: .wordInit, template: .listenAndChoose, difficultyBand: 2...2),
            .make(sound: "Р", stage: .wordInit, template: .dragAndMatch, difficultyBand: 2...2),
            .make(sound: "Р", stage: .wordInit, template: .puzzleReveal, difficultyBand: 1...1)
        ]
        let gen = MockVariationGenerator(activitiesBySound: ["Р": activities])
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: [.make(childId: "child-1", successRate: 0.75)]),
            variationGenerator: gen
        )
        let route = try await planner.buildDailyRoute(for: "child-1")

        let lacEnriched = route.steps.first { $0.templateType == .listenAndChoose && $0.track == .sound }
        XCTAssertNotNil(lacEnriched?.variationId, "listenAndChoose шаг должен получить вариацию")
        XCTAssertEqual(lacEnriched?.variationId, "gen_Р_wordInit_listen-and-choose")
        XCTAssertEqual(lacEnriched?.wordCount, 6, "wordCount синхронизирован с числом элементов вариации")
    }

    // MARK: 3. Кэширование — один вызов генератора на звук за проход

    func testGenerator_calledOncePerSound() async throws {
        let activities: [GeneratedActivity] = [
            .make(sound: "Р", stage: .wordInit, template: .listenAndChoose),
            .make(sound: "Р", stage: .wordInit, template: .dragAndMatch),
            .make(sound: "Р", stage: .wordInit, template: .puzzleReveal)
        ]
        let gen = MockVariationGenerator(activitiesBySound: ["Р": activities])
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: [.make(childId: "child-1")]),
            variationGenerator: gen
        )
        _ = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertEqual(gen.callsBySound["Р"], 1, "кандидаты звука запрашиваются один раз и кэшируются")
    }

    // MARK: 4. Контракт маршрута сохранён — те же шаблоны/этапы/треки/число шагов

    func testContractPreserved_sameTemplatesAndStages() async throws {
        let activities: [GeneratedActivity] = [
            .make(sound: "Р", stage: .wordInit, template: .listenAndChoose),
            .make(sound: "Р", stage: .wordInit, template: .dragAndMatch),
            .make(sound: "Р", stage: .wordInit, template: .puzzleReveal)
        ]
        let sessions = [SessionDTO.make(childId: "child-1", successRate: 0.75)]
        let baseline = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: sessions)
        )
        let enriched = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: sessions),
            variationGenerator: MockVariationGenerator(activitiesBySound: ["Р": activities])
        )
        let baseRoute = try await baseline.buildDailyRoute(for: "child-1")
        let enrichedRoute = try await enriched.buildDailyRoute(for: "child-1")

        XCTAssertEqual(baseRoute.steps.count, enrichedRoute.steps.count,
                       "обогащение не меняет число шагов")
        XCTAssertEqual(baseRoute.steps.map(\.templateType), enrichedRoute.steps.map(\.templateType),
                       "шаблоны шагов идентичны (потребитель не ломается)")
        XCTAssertEqual(baseRoute.steps.map(\.stage), enrichedRoute.steps.map(\.stage),
                       "этапы шагов идентичны")
        XCTAssertEqual(baseRoute.steps.map(\.track), enrichedRoute.steps.map(\.track),
                       "треки шагов идентичны")
    }

    // MARK: 5. Несовместимый пул — шаг остаётся базовым (анти-пустышка)

    func testIncompatiblePool_keepsBaseStep() async throws {
        // Генератор отдаёт только кандидата для ДРУГОГО этапа — ни один шаг
        // wordInit-маршрута не наполняется, но шаги не теряются.
        let activities: [GeneratedActivity] = [
            .make(sound: "Р", stage: .story, template: .narrativeQuest)
        ]
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child()]),
            sessionRepository: MockSessionRepository(sessions: [.make(childId: "child-1")]),
            variationGenerator: MockVariationGenerator(activitiesBySound: ["Р": activities])
        )
        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertFalse(route.steps.isEmpty, "маршрут не пустой")
        XCTAssertTrue(route.steps.allSatisfy { $0.variationId == nil },
                      "несовместимый пул — все шаги остаются базовыми (нет пустышек)")
    }

    // MARK: 6. Возрастной гейт уважается при обогащении

    func testAgeGate_blocksTooAdvancedVariation() async throws {
        let activities: [GeneratedActivity] = [
            .make(sound: "Р", stage: .wordInit, template: .listenAndChoose, minAge: 7)
        ]
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child(age: 5)]),
            sessionRepository: MockSessionRepository(sessions: [.make(childId: "child-1")]),
            variationGenerator: MockVariationGenerator(activitiesBySound: ["Р": activities])
        )
        let route = try await planner.buildDailyRoute(for: "child-1")
        let lac = route.steps.first { $0.templateType == .listenAndChoose && $0.track == .sound }
        XCTAssertNil(lac?.variationId, "вариация 7+ не наполняет шаг 5-летнего ребёнка")
    }

    // MARK: 7. applyVariation синхронизирует поля, сохраняя идентичность шага

    func testApplyVariation_keepsIdentityAdjustsContent() {
        let step = RouteStepItem(
            templateType: .memory, targetSound: "С", stage: .wordMed,
            difficulty: 1, wordCount: 4, durationTargetSec: 120,
            track: .sound, isRetrospective: true, isRollback: false
        )
        let variation = GeneratedActivity.make(
            sound: "С", kind: .themed, stage: .wordInit, theme: "food",
            template: .memory, difficultyBand: 2...3, itemCount: 8
        )
        let applied = LiveAdaptivePlannerService.applyVariation(variation, to: step)
        XCTAssertEqual(applied.templateType, .memory, "шаблон сохранён")
        XCTAssertEqual(applied.targetSound, "С", "звук сохранён")
        XCTAssertEqual(applied.stage, .wordMed, "этап шага сохранён")
        XCTAssertEqual(applied.track, .sound, "трек сохранён")
        XCTAssertTrue(applied.isRetrospective, "флаг ретроспективы сохранён")
        XCTAssertEqual(applied.durationTargetSec, 120, "длительность сохранена")
        XCTAssertEqual(applied.theme, "food", "тема вариации проставлена")
        XCTAssertEqual(applied.variationId, variation.id, "variationId проставлен")
        XCTAssertEqual(applied.wordCount, 8, "wordCount = число элементов вариации")
        XCTAssertEqual(applied.difficulty, 3, "difficulty = верх band'а вариации")
    }

    // MARK: 8. themeRotationSeed детерминирован и стабилен между запусками

    func testThemeRotationSeed_isDeterministic() {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 13)) ?? Date()
        let a = LiveAdaptivePlannerService.themeRotationSeed(childId: "child-1", now: day)
        let b = LiveAdaptivePlannerService.themeRotationSeed(childId: "child-1", now: day)
        XCTAssertEqual(a, b, "тот же ребёнок + день → тот же seed")
        let shift = LiveAdaptivePlannerService.stableShift(for: "child-1")
        XCTAssertTrue((0...6).contains(shift), "стабильный сдвиг в диапазоне 0…6")
        XCTAssertEqual(shift, LiveAdaptivePlannerService.stableShift(for: "child-1"),
                       "сдвиг детерминирован (не зависит от per-process hash seed)")
    }
}
