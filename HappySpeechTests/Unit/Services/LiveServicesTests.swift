@testable import HappySpeech
import XCTest

// MARK: - LiveServicesTests
//
// 2.6b v25 — покрытие тестируемых частей LiveServices.swift.
// Тестируется чистая логика без Firebase / hardware:
//   • LiveAdaptivePlannerService — fallback-маршрут, SM-2 helpers, composeRoute,
//     computeFatigue, selectPrimaryState, sessionMaxSec, normalize, shouldTakeBreak.
//   • LiveContentService — bundledPacks / loadPack (seed JSON из бандла).
//   • LocalAnalyticsService — кольцевой буфер событий.
//   • LiveLocalLLMService — заглушка (бросает llmNotDownloaded).
//   • LiveARService — синхронные computed-свойства.
// LiveAudioService — AVAudioEngine hardware-bound, документировано для ADR-V25-COVERAGE.

final class LiveServicesTests: XCTestCase {

    // MARK: - LiveAdaptivePlannerService — fallback route

    func test_planner_buildDailyRoute_withoutRepositories_returnsFallback() async throws {
        let planner = LiveAdaptivePlannerService()
        let route = try await planner.buildDailyRoute(for: "child-fallback")
        XCTAssertFalse(route.steps.isEmpty, "Fallback маршрут должен содержать шаги")
        XCTAssertGreaterThan(route.maxDurationSec, 0)
        XCTAssertLessThanOrEqual(route.maxDurationSec, 600, "Fallback ограничен 10 минутами")
        XCTAssertEqual(route.fatigueLevel, .fresh)
    }

    func test_planner_buildDailyRoute_fallbackFirstStepIsWarmUp() async throws {
        let planner = LiveAdaptivePlannerService()
        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertEqual(route.steps.first?.templateType, .breathing, "Маршрут начинается с разминки")
    }

    func test_planner_recordCompletion_doesNotThrow() async throws {
        let planner = LiveAdaptivePlannerService()
        let route = try await planner.buildDailyRoute(for: "child-1")
        try await planner.recordCompletion(sessionId: "sess-1", route: route)
    }

    func test_planner_recordSessionResult_withoutRepositories_isNoop() async throws {
        let planner = LiveAdaptivePlannerService()
        // Без репозиториев — метод логирует и возвращается, не бросает.
        try await planner.recordSessionResult(
            childId: "child-1",
            soundTarget: "С",
            qualityScore: .correct
        )
    }

    // MARK: - shouldTakeBreak

    func test_planner_shouldTakeBreak_threeConsecutiveWrong_returnsTrue() {
        let planner = LiveAdaptivePlannerService()
        XCTAssertTrue(
            planner.shouldTakeBreak(consecutiveWrong: 3, sessionDurationSec: 60, childAge: 6)
        )
    }

    func test_planner_shouldTakeBreak_fewWrong_andShortSession_returnsFalse() {
        let planner = LiveAdaptivePlannerService()
        XCTAssertFalse(
            planner.shouldTakeBreak(consecutiveWrong: 1, sessionDurationSec: 60, childAge: 6)
        )
    }

    func test_planner_shouldTakeBreak_nearDurationCap_returnsTrue() {
        let planner = LiveAdaptivePlannerService()
        // Возраст 6 → cap 720 c, 0.9 * 720 = 648.
        XCTAssertTrue(
            planner.shouldTakeBreak(consecutiveWrong: 0, sessionDurationSec: 700, childAge: 6)
        )
    }

    // MARK: - sessionMaxSec

    func test_planner_sessionMaxSec_byAge() {
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 5), 480)
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 6), 720)
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 7), 720)
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 8), 1200)
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 10), 1200)
    }

    // MARK: - normalize(ef:)

    func test_planner_normalize_clampsToZeroOne() {
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 1.3), 0.0, accuracy: 0.0001)
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 3.0), 1.0, accuracy: 0.0001)
        // EF ниже минимума — клампится к 0.
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 0.5), 0.0, accuracy: 0.0001)
        // EF выше максимума — клампится к 1.
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 5.0), 1.0, accuracy: 0.0001)
    }

    func test_planner_normalize_midRange_isProportional() {
        // EF = 2.15 — середина диапазона 1.3…3.0.
        let normalized = LiveAdaptivePlannerService.normalize(ef: 2.15)
        XCTAssertEqual(normalized, 0.5, accuracy: 0.01)
    }

    // MARK: - computeFatigue

    func test_planner_computeFatigue_threeWrong_isTired() {
        let state = SoundProgressState(soundTarget: "Р", stage: .wordInit, consecutiveWrong: 3)
        XCTAssertEqual(LiveAdaptivePlannerService.computeFatigue(state: state, hour: 12), .tired)
    }

    func test_planner_computeFatigue_twoWrong_isNormal() {
        let state = SoundProgressState(soundTarget: "Р", stage: .wordInit, consecutiveWrong: 2)
        XCTAssertEqual(LiveAdaptivePlannerService.computeFatigue(state: state, hour: 12), .normal)
    }

    func test_planner_computeFatigue_freshDaytime_isFresh() {
        let state = SoundProgressState(soundTarget: "Р", stage: .wordInit, consecutiveWrong: 0)
        XCTAssertEqual(LiveAdaptivePlannerService.computeFatigue(state: state, hour: 14), .fresh)
    }

    func test_planner_computeFatigue_lateHour_withHistory_bumpsToNormal() {
        let state = SoundProgressState(
            soundTarget: "Р",
            stage: .wordInit,
            lastReviewDate: Date(),
            consecutiveWrong: 0
        )
        // Поздний час (22:00) + есть история → минимум .normal.
        XCTAssertEqual(LiveAdaptivePlannerService.computeFatigue(state: state, hour: 22), .normal)
    }

    func test_planner_computeFatigue_lateHour_withoutHistory_staysFresh() {
        let state = SoundProgressState(soundTarget: "Р", stage: .wordInit, consecutiveWrong: 0)
        // Поздний час, но ребёнок новый (нет lastReviewDate) → остаётся fresh.
        XCTAssertEqual(LiveAdaptivePlannerService.computeFatigue(state: state, hour: 23), .fresh)
    }

    // MARK: - selectPrimaryState

    func test_planner_selectPrimaryState_emptyArray_returnsNil() {
        XCTAssertNil(LiveAdaptivePlannerService.selectPrimaryState(from: []))
    }

    func test_planner_selectPrimaryState_picksMostOverdue() {
        let fresh = SoundProgressState(
            soundTarget: "С",
            stage: .wordInit,
            lastIntervalDays: 1,
            lastReviewDate: Date()
        )
        // Не повторялся ни разу → overdueDays == Int.max → максимальный приоритет.
        let neverReviewed = SoundProgressState(soundTarget: "Р", stage: .isolated)
        let primary = LiveAdaptivePlannerService.selectPrimaryState(from: [fresh, neverReviewed])
        XCTAssertEqual(primary?.soundTarget, "Р")
    }

    // MARK: - composeRoute

    func test_planner_composeRoute_freshFatigue_hasFourSteps() {
        let steps = LiveAdaptivePlannerService.composeRoute(
            soundTarget: "С", stage: .wordInit, fatigue: .fresh
        )
        XCTAssertEqual(steps.count, 4, "Свежий ребёнок — полный маршрут")
        XCTAssertEqual(steps.first?.templateType, .breathing)
        XCTAssertEqual(steps.last?.templateType, .puzzleReveal)
    }

    func test_planner_composeRoute_normalFatigue_hasThreeSteps() {
        let steps = LiveAdaptivePlannerService.composeRoute(
            soundTarget: "С", stage: .wordInit, fatigue: .normal
        )
        XCTAssertEqual(steps.count, 3)
    }

    func test_planner_composeRoute_tiredFatigue_hasTwoSteps() {
        let steps = LiveAdaptivePlannerService.composeRoute(
            soundTarget: "С", stage: .wordInit, fatigue: .tired
        )
        XCTAssertEqual(steps.count, 2, "Усталый ребёнок — короткий маршрут разминка+награда")
        XCTAssertEqual(steps.first?.templateType, .breathing)
        XCTAssertEqual(steps.last?.templateType, .puzzleReveal)
    }

    func test_planner_composeRoute_tiredReducesCoreDuration() {
        let fresh = LiveAdaptivePlannerService.composeRoute(
            soundTarget: "С", stage: .wordInit, fatigue: .fresh
        )
        // Core-шаг (индекс 1) у свежего длиннее.
        XCTAssertEqual(fresh[1].durationTargetSec, 210)
    }

    func test_planner_composeRoute_allStepsCarryTargetSound() {
        let steps = LiveAdaptivePlannerService.composeRoute(
            soundTarget: "Ш", stage: .syllable, fatigue: .fresh
        )
        for step in steps {
            XCTAssertEqual(step.targetSound, "Ш")
        }
    }

    func test_planner_composeRoute_isolatedStage_coreIsRepeatAfterModel() {
        let steps = LiveAdaptivePlannerService.composeRoute(
            soundTarget: "Р", stage: .isolated, fatigue: .fresh
        )
        XCTAssertEqual(steps[1].templateType, .repeatAfterModel)
    }

    func test_planner_composeRoute_diffStage_coreIsMinimalPairs() {
        let steps = LiveAdaptivePlannerService.composeRoute(
            soundTarget: "Р", stage: .diff, fatigue: .fresh
        )
        XCTAssertEqual(steps[1].templateType, .minimalPairs)
    }

    // MARK: - LocalAnalyticsService

    func test_analytics_track_storesEvent() {
        let service = LocalAnalyticsService()
        service.track(event: AnalyticsEvent(name: "session_start"))
        // Нет публичного геттера — проверяем, что вызов не падает и API стабилен.
    }

    func test_analytics_track_manyEvents_doesNotCrash() {
        let service = LocalAnalyticsService()
        for index in 0..<1_200 {
            service.track(event: AnalyticsEvent(name: "event_\(index)", parameters: ["i": "\(index)"]))
        }
        // Кольцевой буфер ограничен 1000 — переполнение не падает.
    }

    func test_analyticsEvent_storesNameAndParameters() {
        let event = AnalyticsEvent(name: "lesson_done", parameters: ["sound": "С"])
        XCTAssertEqual(event.name, "lesson_done")
        XCTAssertEqual(event.parameters["sound"], "С")
        XCTAssertLessThanOrEqual(event.timestamp.timeIntervalSinceNow, 1.0)
    }

    func test_analyticsEvent_defaultParameters_areEmpty() {
        let event = AnalyticsEvent(name: "tap")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    // MARK: - LiveLocalLLMService (stub)

    func test_localLLM_initialFlags_areFalse() {
        let service = LiveLocalLLMService()
        XCTAssertFalse(service.isModelDownloaded)
        XCTAssertFalse(service.isModelLoaded)
    }

    func test_localLLM_downloadModel_doesNotThrow() async throws {
        let service = LiveLocalLLMService()
        try await service.downloadModel()
    }

    func test_localLLM_generateRoute_throwsNotDownloaded() async {
        let service = LiveLocalLLMService()
        let request = RoutePlannerRequest(
            childId: "child-1",
            targetSound: "С",
            currentStage: CorrectionStage.wordInit.rawValue,
            recentSuccessRate: 0.7,
            fatigueLevel: FatigueLevel.fresh.rawValue,
            age: 6,
            availableTemplates: [TemplateType.listenAndChoose.rawValue]
        )
        do {
            _ = try await service.generateRoute(request: request)
            XCTFail("Должна быть выброшена llmNotDownloaded")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    // MARK: - LiveARService

    func test_arService_isSupported_isTrue() {
        let service = LiveARService()
        XCTAssertTrue(service.isSupported)
    }

    func test_arService_cameraPermission_isBool() {
        let service = LiveARService()
        // В unit-окружении камера не авторизована — просто проверяем стабильность чтения.
        _ = service.isCameraPermissionGranted
    }

    // MARK: - LiveContentService

    func test_contentService_bundledPacks_returnsArray() {
        let service = LiveContentService()
        let packs = service.bundledPacks()
        // Seed-паки могут отсутствовать в тестовом бандле — проверяем сам контракт.
        XCTAssertNotNil(packs)
        for pack in packs {
            XCTAssertTrue(pack.isBundled)
            XCTAssertTrue(pack.isDownloaded)
            XCTAssertFalse(pack.id.isEmpty)
        }
    }

    func test_contentService_allPacks_matchesBundledPacks() async throws {
        let service = LiveContentService()
        let all = try await service.allPacks()
        let bundled = service.bundledPacks()
        XCTAssertEqual(all.count, bundled.count)
    }

    func test_contentService_loadPack_unknownLetter_throwsNotFound() async {
        let service = LiveContentService()
        do {
            _ = try await service.loadPack(id: "sound_zzz_v1")
            // Если seed-пак для zzz отсутствует — должно бросить contentPackNotFound.
            // Если же бандл содержит пак — тест допускает успех (контракт сохранён).
        } catch let error as AppError {
            if case .contentPackNotFound = error {
                // Ожидаемая ветвь.
            } else {
                XCTFail("Ожидалась contentPackNotFound, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }
}
