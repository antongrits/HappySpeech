@testable import HappySpeech
import XCTest

// MARK: - AdaptivePlannerDisorderRouteTests (F1-021)
// ==================================================================================
// Тесты стратегии маршрута по типу речевого нарушения (DisorderRouteStrategy).
// Для каждого из 6 нарушений маршрут должен содержать ожидаемые треки/типы
// активностей и соблюдать методические запреты (заикание — без таймеров/
// соревнований; ЗРР — короткая сессия).
// ==================================================================================

final class AdaptivePlannerDisorderRouteTests: XCTestCase {

    private let sound = "Р"
    private let stage: CorrectionStage = .wordInit

    private func route(_ disorder: SpeechDisorder, fatigue: FatigueLevel = .fresh) -> [RouteStepItem] {
        DisorderRouteStrategy.composeRoute(
            soundTarget: sound,
            stage: stage,
            fatigue: fatigue,
            disorder: disorder
        )
    }

    private func tracks(_ steps: [RouteStepItem]) -> Set<RouteTrack> {
        Set(steps.map(\.track))
    }

    private func templates(_ steps: [RouteStepItem]) -> Set<TemplateType> {
        Set(steps.map(\.templateType))
    }

    // MARK: - 1. Дислалия → только звуковой трек

    func testDyslalia_onlySoundTrack() {
        let steps = route(.dyslalia)
        XCTAssertFalse(steps.isEmpty)
        XCTAssertEqual(tracks(steps), [.sound], "Дислалия — только звуковой трек")
    }

    // MARK: - 2. ФФН → звук + фонематика, есть минимальные пары

    func testFFN_hasSoundAndPhonemicTracks() {
        let steps = route(.ffn)
        let t = tracks(steps)
        XCTAssertTrue(t.contains(.sound), "ФФН должен содержать звуковой трек")
        XCTAssertTrue(t.contains(.phonemic), "ФФН должен содержать фонематический трек")
        XCTAssertTrue(templates(steps).contains(.minimalPairs),
                      "Фонематический трек должен использовать минимальные пары")
    }

    // MARK: - 3. ОНР → 4 параллельных трека (F1-013)

    func testONR_hasFourParallelTracks() {
        let steps = route(.onr)
        let t = tracks(steps)
        XCTAssertTrue(t.contains(.sound), "ОНР: произношение")
        XCTAssertTrue(t.contains(.phonemic), "ОНР: фонематика")
        XCTAssertTrue(t.contains(.grammar), "ОНР: грамматика")
        XCTAssertTrue(t.contains(.coherentSpeech), "ОНР: связная речь")
        XCTAssertEqual(t.count, 4, "ОНР: ровно 4 трека в дне")
    }

    // MARK: - 4. ОНР → грамматика и связная речь представлены ожидаемыми шаблонами

    func testONR_grammarAndCoherentTemplates() {
        let steps = route(.onr)
        let tpl = templates(steps)
        XCTAssertTrue(tpl.contains(.dragAndMatch), "Грамматический трек → drag-and-match")
        XCTAssertTrue(tpl.contains(.narrativeQuest), "Связная речь → narrative-quest")
    }

    // MARK: - 5. ЗРР → «медленный старт»: короткая сессия, имитация/называние

    func testZRR_slowStart_shortAndElicitation() {
        let steps = route(.zrr)
        XCTAssertLessThanOrEqual(steps.count, 3, "ЗРР: короткая сессия (≤3 шага)")
        let tpl = templates(steps)
        XCTAssertTrue(tpl.contains(.repeatAfterModel), "ЗРР: звукоподражание/имитация")
        // Никаких сложных дифференциаций/минимальных пар на медленном старте.
        XCTAssertFalse(tpl.contains(.minimalPairs), "ЗРР: без сложной дифференциации")
        let total = steps.reduce(0) { $0 + $1.durationTargetSec }
        XCTAssertLessThanOrEqual(total, 300, "ЗРР: суммарно ≤5 минут")
    }

    // MARK: - 6. ЗРР → cap сессии занижен до 5 минут независимо от возраста

    func testZRR_sessionCapIsFiveMinutes() {
        XCTAssertEqual(DisorderRouteStrategy.sessionCap(for: 8, disorder: .zrr), 300,
                       "ЗРР: cap = 5 мин даже для 8 лет")
        XCTAssertEqual(DisorderRouteStrategy.sessionCap(for: 6, disorder: .dyslalia), 720,
                       "Дислалия 6 лет: cap по возрасту (12 мин)")
    }

    // MARK: - 7. Заикание → дыхание/темп, без timed-mode/соревнований

    func testStuttering_breathingFluencyAndNoCompetition() {
        let steps = route(.stuttering)
        let t = tracks(steps)
        XCTAssertTrue(t.contains(.breathingFluency), "Заикание: трек дыхания/плавности")
        let tpl = templates(steps)
        XCTAssertTrue(tpl.contains(.breathing), "Заикание: дыхание")
        XCTAssertTrue(tpl.contains(.rhythm), "Заикание: ритм/темп")
        // Методический запрет: никаких соревновательных bingo и т.п. timed-режимов.
        XCTAssertFalse(tpl.contains(.bingo), "Заикание: без соревновательных таймеров")
    }

    // MARK: - 8. Заикание → hasFluencyGoal флаг проброшен в маршрут (disorder)

    func testStuttering_disorderFlagFluencyGoal() {
        XCTAssertTrue(SpeechDisorder.stuttering.hasFluencyGoal)
        XCTAssertFalse(SpeechDisorder.dyslalia.hasFluencyGoal)
    }

    // MARK: - 9. Дизартрия → артикуляция + Visual-Acoustic + звук

    func testDysarthria_articulationVisualAcousticAndSound() {
        let steps = route(.dysarthria)
        let t = tracks(steps)
        XCTAssertTrue(t.contains(.articulation), "Дизартрия: артикуляционный трек")
        XCTAssertTrue(t.contains(.sound), "Дизартрия: звуковой трек")
        let tpl = templates(steps)
        XCTAssertTrue(tpl.contains(.articulationImitation), "Дизартрия: артик. гимнастика")
        XCTAssertTrue(tpl.contains(.visualAcoustic), "Дизартрия: Visual-Acoustic биообратная связь")
    }

    // MARK: - 10. Дизартрия → артикуляция удлинена (≥180с)

    func testDysarthria_articulationIsExtended() {
        let steps = route(.dysarthria)
        let artic = steps.first { $0.templateType == .articulationImitation }
        XCTAssertNotNil(artic)
        XCTAssertGreaterThanOrEqual(artic?.durationTargetSec ?? 0, 180,
                                    "Дизартрия: артикуляция 3–4 мин")
    }

    // MARK: - 11. Любой маршрут непустой и шаги имеют положительную длительность

    func testAllDisorders_produceNonEmptyValidRoutes() {
        for disorder in SpeechDisorder.allCases {
            let steps = route(disorder)
            XCTAssertFalse(steps.isEmpty, "\(disorder.rawValue): маршрут не должен быть пустым")
            for step in steps {
                XCTAssertGreaterThan(step.durationTargetSec, 0,
                                     "\(disorder.rawValue): шаг с нулевой длительностью")
            }
        }
    }

    // MARK: - 12. Усталость сокращает ОНР-маршрут (антифатиговое правило)

    func testONR_tiredFatigue_trimmedToThreeSteps() {
        let fresh = route(.onr, fatigue: .fresh)
        let tired = route(.onr, fatigue: .tired)
        XCTAssertGreaterThan(fresh.count, tired.count, "Усталость должна сокращать ОНР-маршрут")
        XCTAssertLessThanOrEqual(tired.count, 3, "Усталость: не более 3 шагов")
    }

    // MARK: - 13. AdaptiveRoute.tracks отражает треки шагов

    func testAdaptiveRoute_tracksComputedProperty() {
        let onr = AdaptiveRoute(
            steps: route(.onr),
            maxDurationSec: 720,
            fatigueLevel: .fresh,
            disorder: .onr
        )
        XCTAssertEqual(onr.tracks.count, 4)
        XCTAssertEqual(onr.disorder, .onr)
    }

    // MARK: - 14. Все TemplateType в маршрутах валидны для SessionShell (без новых кейсов)

    func testRouteTemplates_areExistingTemplateTypes() {
        // Гарантия: стратегия не вводит TemplateType, не покрытый игровым движком.
        for disorder in SpeechDisorder.allCases {
            for step in route(disorder) {
                XCTAssertTrue(TemplateType.allCases.contains(step.templateType),
                              "\(disorder.rawValue): неизвестный шаблон \(step.templateType.rawValue)")
            }
        }
    }
}
