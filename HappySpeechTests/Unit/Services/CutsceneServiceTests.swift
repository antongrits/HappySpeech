@testable import HappySpeech
import XCTest

// MARK: - CutsceneServiceTests
// ==================================================================================
// Unit-тесты для CutsceneServiceLive (система кат-сцен «Путешествие Ляли»).
//
// Покрытие:
//   • Приоритет очереди (finale > islandTriumph > islandIntro > milestone > prologue)
//   • seen-персистентность (markSeen / shouldPlay / per-child изоляция / reset)
//   • graceful-missing-video (нет видеофайла → постер-фолбэк, shouldPlay=true)
//   • маппинг триггер → сцена + дедупликация enqueue
//   • pop помечает текущую сцену seen и продвигает очередь
// ==================================================================================

@MainActor
final class CutsceneServiceTests: XCTestCase {

    // MARK: - Test doubles

    /// VideoPlayer, у которого все видео «отсутствуют» (videoURL → nil) — для
    /// проверки graceful-missing-video.
    private struct NoVideoPlayerService: VideoPlayerServiceProtocol {
        nonisolated func videoURL(for id: String) -> URL? { nil }
        nonisolated func manifest(for id: String) -> VideoManifestEntry? { nil }
    }

    /// VideoPlayer, у которого все видео «существуют» (стабовый URL).
    private struct AllVideoPlayerService: VideoPlayerServiceProtocol {
        nonisolated func videoURL(for id: String) -> URL? {
            URL(fileURLWithPath: "/tmp/\(id).mp4")
        }
        nonisolated func manifest(for id: String) -> VideoManifestEntry? { nil }
    }

    // MARK: - Helpers

    /// Изолированный UserDefaults-suite на тест — не пишем в `.standard`.
    private func makeDefaults(_ function: String = #function) -> UserDefaults {
        let name = "cutscene.tests.\(function)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeSUT(
        videos: any VideoPlayerServiceProtocol = AllVideoPlayerService(),
        defaults: UserDefaults
    ) -> CutsceneServiceLive {
        CutsceneServiceLive(videoPlayerService: videos, hapticService: nil, defaults: defaults)
    }

    // MARK: - 1. Каталог содержит все 16 кат-сцен

    func testCatalog_hasSixteenCutscenes() {
        XCTAssertEqual(CutsceneCatalog.all.count, 16)
    }

    func testCatalog_videoReadyCutscenes_matchCatalog() {
        // После волны Veo 3.1 (Sprint 12) готовы 9 кат-сцен:
        // пролог + 4 острова (whistling/hissing/affr/sonor) × in+out.
        // Тест синхронизирован с CutsceneModels.swift (videoReady: true).
        let ready = Set(CutsceneCatalog.all.filter { $0.videoReady }.map(\.id))
        let expected: Set<String> = [
            "cs-prologue",
            "cs-isl-whistling-in", "cs-isl-whistling-out",
            "cs-isl-hissing-in",   "cs-isl-hissing-out",
            "cs-isl-affr-in",      "cs-isl-affr-out",
            "cs-isl-sonor-in",     "cs-isl-sonor-out"
        ]
        XCTAssertEqual(ready, expected)
    }

    // MARK: - 2. Маппинг триггер → сцена

    func testCutsceneForTrigger_mapsCorrectly() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        XCTAssertEqual(sut.cutscene(for: .onboardingComplete)?.id, "cs-prologue")
        XCTAssertEqual(sut.cutscene(for: .islandIntro(.whistling))?.id, "cs-isl-whistling-in")
        XCTAssertEqual(sut.cutscene(for: .islandComplete(.sonorant))?.id, "cs-isl-sonor-out")
        XCTAssertEqual(sut.cutscene(for: .allIslandsComplete)?.id, "cs-finale")
        XCTAssertEqual(sut.cutscene(for: .streak(days: 7))?.id, "cs-streak-7")
        XCTAssertEqual(sut.cutscene(for: .streak(days: 30))?.id, "cs-streak-30")
        XCTAssertNil(sut.cutscene(for: .streak(days: 99)))
    }

    // MARK: - 3. Приоритет очереди

    func testQueue_ordersByPriority_finaleFirst() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        // Ставим в очередь в «неправильном» порядке (milestone, intro, finale).
        sut.enqueue(.streak(days: 7), childId: "c1")          // milestone, prio 40
        sut.enqueue(.islandIntro(.hissing), childId: "c1")    // islandIntro, prio 60
        sut.enqueue(.allIslandsComplete, childId: "c1")       // finale, prio 100
        sut.enqueue(.islandComplete(.hissing), childId: "c1") // triumph, prio 80

        // Голова очереди — finale (наибольший приоритет).
        XCTAssertEqual(sut.pending?.id, "cs-finale")

        // Дальше по убыванию приоритета: triumph → intro → milestone.
        sut.pop()
        XCTAssertEqual(sut.pending?.id, "cs-isl-hissing-out")
        sut.pop()
        XCTAssertEqual(sut.pending?.id, "cs-isl-hissing-in")
        sut.pop()
        XCTAssertEqual(sut.pending?.id, "cs-streak-7")
        sut.pop()
        XCTAssertNil(sut.pending)
    }

    func testQueue_equalPriority_keepsFIFO() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        // Два islandIntro (равный приоритет 60) — FIFO по порядку enqueue.
        sut.enqueue(.islandIntro(.hissing), childId: "c1")
        sut.enqueue(.islandIntro(.velar), childId: "c1")

        XCTAssertEqual(sut.pending?.id, "cs-isl-hissing-in")
        sut.pop()
        XCTAssertEqual(sut.pending?.id, "cs-isl-velar-in")
    }

    func testEnqueue_deduplicatesSameCutscene() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        sut.enqueue(.islandIntro(.hissing), childId: "c1")
        sut.enqueue(.islandIntro(.hissing), childId: "c1")
        sut.enqueue(.islandIntro(.hissing), childId: "c1")

        XCTAssertEqual(sut.pending?.id, "cs-isl-hissing-in")
        sut.pop()
        XCTAssertNil(sut.pending, "Повторные enqueue одной сцены не должны дублировать её в очереди")
    }

    // MARK: - 4. seen-персистентность

    func testMarkSeen_blocksShouldPlay() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        XCTAssertTrue(sut.shouldPlay("cs-prologue", childId: "c1"))
        sut.markSeen("cs-prologue", childId: "c1")
        XCTAssertFalse(sut.shouldPlay("cs-prologue", childId: "c1"))
    }

    func testSeen_isPerChildIsolated() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        sut.markSeen("cs-prologue", childId: "c1")
        // У ребёнка c1 — просмотрено, у c2 — нет.
        XCTAssertFalse(sut.shouldPlay("cs-prologue", childId: "c1"))
        XCTAssertTrue(sut.shouldPlay("cs-prologue", childId: "c2"))
    }

    func testSeen_persistsAcrossServiceInstances() {
        let defaults = makeDefaults()
        let sut1 = makeSUT(defaults: defaults)
        sut1.markSeen("cs-prologue", childId: "c1")

        // Новый инстанс над тем же UserDefaults — seen должен сохраниться.
        let sut2 = makeSUT(defaults: defaults)
        XCTAssertFalse(sut2.shouldPlay("cs-prologue", childId: "c1"))
    }

    func testResetSeen_unblocksReplay() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        sut.markSeen("cs-prologue", childId: "c1")
        sut.markSeen("cs-isl-whistling-in", childId: "c1")
        XCTAssertFalse(sut.shouldPlay("cs-prologue", childId: "c1"))

        sut.resetSeen(childId: "c1")
        XCTAssertTrue(sut.shouldPlay("cs-prologue", childId: "c1"))
        XCTAssertTrue(sut.shouldPlay("cs-isl-whistling-in", childId: "c1"))
    }

    func testPop_marksCurrentSeen() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        sut.enqueue(.onboardingComplete, childId: "c1")
        XCTAssertEqual(sut.pending?.id, "cs-prologue")
        sut.pop()
        // После pop сцена помечена просмотренной — повторный enqueue не всплывёт.
        sut.enqueue(.onboardingComplete, childId: "c1")
        XCTAssertNil(sut.pending)
    }

    func testEnqueue_skipsAlreadySeen() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)

        sut.markSeen("cs-prologue", childId: "c1")
        sut.enqueue(.onboardingComplete, childId: "c1")
        XCTAssertNil(sut.pending, "Просмотренная сцена не должна попадать в очередь")
    }

    // MARK: - 5. graceful-missing-video

    func testShouldPlay_trueWhenVideoMissingButPosterExists() {
        let defaults = makeDefaults()
        // Видео отсутствует у всех id, но у всех каталожных сцен есть постер.
        let sut = makeSUT(videos: NoVideoPlayerService(), defaults: defaults)

        // Постер задан → graceful-фолбэк в плеере, shouldPlay = true.
        XCTAssertTrue(sut.shouldPlay("cs-prologue", childId: "c1"))
        XCTAssertTrue(sut.shouldPlay("cs-isl-hissing-in", childId: "c1"))
    }

    func testEnqueue_worksWithMissingVideo_gracefulFallback() {
        let defaults = makeDefaults()
        let sut = makeSUT(videos: NoVideoPlayerService(), defaults: defaults)

        // Даже без видеофайла сцена ставится в очередь (плеер покажет постер).
        sut.enqueue(.islandComplete(.hissing), childId: "c1")
        XCTAssertEqual(sut.pending?.id, "cs-isl-hissing-out")
    }

    func testShouldPlay_falseForUnknownId() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults)
        XCTAssertFalse(sut.shouldPlay("cs-nonexistent", childId: "c1"))
    }

    // MARK: - 6. Mock-сервис

    func testMock_defaultsToNoPlay() {
        let mock = MockCutsceneService()
        XCTAssertFalse(mock.shouldPlay("cs-prologue", childId: "c1"))
        mock.enqueue(.onboardingComplete, childId: "c1")
        XCTAssertNil(mock.pending, "Mock по умолчанию не всплывает в превью/снапшотах")
        // Но триггер записан — для проверки факта вызова в интеграционных тестах.
        XCTAssertEqual(mock.enqueuedTriggers, [.onboardingComplete])
    }

    func testMock_playsEnqueuedWhenEnabled() {
        let mock = MockCutsceneService(playsEnqueued: true)
        mock.enqueue(.onboardingComplete, childId: "c1")
        XCTAssertEqual(mock.pending?.id, "cs-prologue")
        mock.pop()
        XCTAssertNil(mock.pending)
    }
}
