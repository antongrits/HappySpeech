@testable import HappySpeech
import XCTest

// MARK: - PhonemeReportTests
//
// Покрывает A-09 «Детальный пофонемный отчёт»: чистый агрегатор реальных
// сессий, интерактор (happy + error) и презентер (формат + охват + «нет
// данных»). Все значения проверяются против РЕАЛЬНЫХ полей SessionDTO —
// никакой фабрикации/random в продукте, поэтому числа детерминированы.

@MainActor
final class PhonemeReportTests: XCTestCase {

    // MARK: - Fixtures

    private func session(
        id: String,
        sound: String,
        date: Date,
        total: Int,
        correct: Int,
        stage: CorrectionStage = .wordInit
    ) -> SessionDTO {
        SessionDTO(
            id: id,
            childId: "child-1",
            date: date,
            templateType: TemplateType.repeatAfterModel.rawValue,
            targetSound: sound,
            stage: stage.rawValue,
            durationSeconds: 300,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    private var base: Date { Date(timeIntervalSince1970: 1_700_000_000) }
    private func day(_ offset: Int) -> Date { base.addingTimeInterval(Double(offset) * 86_400) }

    // MARK: - Aggregator: real per-sound accuracy

    func test_buildRows_aggregatesRealAccuracyPerSound() throws {
        let sessions = [
            session(id: "1", sound: "Р", date: day(0), total: 10, correct: 5),  // 0.5
            session(id: "2", sound: "Р", date: day(1), total: 10, correct: 9),  // 0.9
            session(id: "3", sound: "С", date: day(0), total: 8, correct: 8)    // 1.0
        ]
        let rows = PhonemeReportAggregator.buildRows(targetSounds: ["Р", "С"], sessions: sessions)

        let r = try XCTUnwrap(rows.first { $0.sound == "Р" })
        XCTAssertEqual(r.attempts, 20)
        XCTAssertEqual(r.successes, 14)
        XCTAssertEqual(r.sessionCount, 2)
        // accuracy = mean(0.5, 0.9) = 0.7 (mean of successRate, not pooled)
        XCTAssertEqual(r.accuracy ?? 0, 0.7, accuracy: 0.0001)
        XCTAssertEqual(r.family, .sonorant)

        let s = rows.first { $0.sound == "С" }
        XCTAssertEqual(s?.accuracy, 1.0)
        XCTAssertEqual(s?.family, .whistling)
    }

    func test_buildRows_plannedSoundWithoutSessions_isNoData() {
        let sessions = [session(id: "1", sound: "Р", date: day(0), total: 10, correct: 8)]
        // "Ш" в плане, но без сессий → честный «нет данных».
        let rows = PhonemeReportAggregator.buildRows(targetSounds: ["Р", "Ш"], sessions: sessions)

        let sh = rows.first { $0.sound == "Ш" }
        XCTAssertNotNil(sh)
        XCTAssertFalse(sh?.hasData ?? true)
        XCTAssertNil(sh?.accuracy)
        XCTAssertEqual(sh?.attempts, 0)
        XCTAssertEqual(sh?.sessionCount, 0)
        XCTAssertNil(sh?.trendDelta)
        XCTAssertTrue(sh?.history.isEmpty ?? false)
    }

    func test_buildRows_trendDelta_fromRealHistory() {
        // Ранняя половина среднее 0.4, поздняя 0.8 → дельта +0.4.
        let sessions = [
            session(id: "1", sound: "Р", date: day(0), total: 10, correct: 4),
            session(id: "2", sound: "Р", date: day(1), total: 10, correct: 4),
            session(id: "3", sound: "Р", date: day(2), total: 10, correct: 8),
            session(id: "4", sound: "Р", date: day(3), total: 10, correct: 8)
        ]
        let rows = PhonemeReportAggregator.buildRows(targetSounds: ["Р"], sessions: sessions)
        let r = rows.first { $0.sound == "Р" }
        XCTAssertEqual(r?.trendDelta ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(r?.history.count, 4)
        // история отсортирована по дате
        XCTAssertEqual(r?.history.map(\.date), [day(0), day(1), day(2), day(3)])
    }

    func test_groupByFamily_onlyNonEmptyGroups_sortedByFamilyOrder() {
        let sessions = [
            session(id: "1", sound: "С", date: day(0), total: 5, correct: 5),
            session(id: "2", sound: "Р", date: day(0), total: 5, correct: 3)
        ]
        let rows = PhonemeReportAggregator.buildRows(targetSounds: ["С", "Р"], sessions: sessions)
        let groups = PhonemeReportAggregator.groupByFamily(rows)
        // whistling (С) перед sonorant (Р) по порядку SoundFamily.allCases.
        XCTAssertEqual(groups.map(\.family), [.whistling, .sonorant])
    }

    func test_coverage_countsOnlySoundsWithData() {
        let sessions = [session(id: "1", sound: "Р", date: day(0), total: 5, correct: 3)]
        let rows = PhonemeReportAggregator.buildRows(targetSounds: ["Р", "Ш", "С"], sessions: sessions)
        let (withData, total) = PhonemeReportAggregator.coverage(rows)
        XCTAssertEqual(withData, 1)
        XCTAssertEqual(total, 3)
    }

    // MARK: - Interactor: happy path (real repositories)

    func test_interactor_load_happyPath_buildsRowsFromRealSessions() async {
        let sessions = [
            session(id: "1", sound: "Р", date: day(0), total: 10, correct: 8),
            session(id: "2", sound: "С", date: day(0), total: 6, correct: 3)
        ]
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(
                id: "child-1", name: "Миша", age: 6,
                targetSounds: ["Р", "С", "Ш"], parentId: "parent-1"
            )
        ])
        let spy = DisplaySpy()
        let presenter = PhonemeReportPresenter()
        presenter.display = spy
        let interactor = PhonemeReportInteractor(
            sessionRepository: sessionRepo,
            childRepository: childRepo
        )
        interactor.presenter = presenter

        await interactor.load(.init(childId: "child-1"))

        let vm = spy.lastVM
        XCTAssertNotNil(vm)
        XCTAssertFalse(vm?.isEmpty ?? true)
        XCTAssertNil(vm?.errorText)
        XCTAssertEqual(vm?.childNameText, "Миша")
        // Р + С отработаны, Ш — нет данных → 2 из 3.
        XCTAssertTrue(vm?.coverageText.contains("2") ?? false)

        // В интеракторе сохранены реальные строки.
        let rows = interactor._lastRows()
        XCTAssertEqual(rows.first { $0.sound == "Р" }?.attempts, 10)
        XCTAssertFalse(rows.first { $0.sound == "Ш" }?.hasData ?? true)
    }

    // MARK: - Interactor: error path

    func test_interactor_load_error_surfacesErrorState() async {
        let sessionRepo = MockSessionRepository(sessions: [])
        let childRepo = FailingChildRepository()
        let spy = DisplaySpy()
        let presenter = PhonemeReportPresenter()
        presenter.display = spy
        let interactor = PhonemeReportInteractor(
            sessionRepository: sessionRepo,
            childRepository: childRepo
        )
        interactor.presenter = presenter

        await interactor.load(.init(childId: "missing"))

        XCTAssertNotNil(spy.lastVM?.errorText)
        XCTAssertTrue(spy.lastVM?.isEmpty ?? false)
        XCTAssertTrue(spy.lastVM?.groups.isEmpty ?? false)
    }

    // MARK: - Presenter: no sessions → empty state

    func test_presenter_noSessions_emptyState() {
        let spy = DisplaySpy()
        let presenter = PhonemeReportPresenter()
        presenter.display = spy

        presenter.presentLoad(.init(
            childName: "Соня",
            targetSounds: ["С", "З"],
            sessions: []
        ))

        XCTAssertTrue(spy.lastVM?.isEmpty ?? false)
    }

    // MARK: - Presenter: formats percent + tone from real data

    func test_presenter_formatsPercentAndTone() {
        let spy = DisplaySpy()
        let presenter = PhonemeReportPresenter()
        presenter.display = spy

        let sessions = [
            session(id: "1", sound: "Р", date: day(0), total: 10, correct: 9)  // 0.9 → good
        ]
        presenter.presentLoad(.init(
            childName: "Миша",
            targetSounds: ["Р"],
            sessions: sessions
        ))

        let group = spy.lastVM?.groups.first { $0.familyRaw == SoundFamily.sonorant.rawValue }
        let row = group?.rows.first { $0.sound == "Р" }
        XCTAssertEqual(row?.accuracyPercent, 90)
        XCTAssertEqual(row?.tone, .good)
        XCTAssertNotNil(row?.accuracyText)
        XCTAssertFalse(row?.accuracyText.isEmpty ?? true)
    }

    // MARK: - Helpers

    @MainActor
    private final class DisplaySpy: PhonemeReportDisplayLogic {
        var lastVM: PhonemeReportModels.Load.ViewModel?
        func displayLoad(_ viewModel: PhonemeReportModels.Load.ViewModel) {
            lastVM = viewModel
        }
    }

    /// Child repo, который всегда бросает — для проверки error-пути.
    private final class FailingChildRepository: ChildRepository, @unchecked Sendable {
        func fetchAll() async throws -> [ChildProfileDTO] { [] }
        func fetch(id: String) async throws -> ChildProfileDTO {
            throw AppError.entityNotFound(id)
        }
        func save(_ profile: ChildProfileDTO) async throws {}
        func delete(id: String) async throws {}
        func updateProgress(childId: String, sound: String, rate: Double) async throws {}
        func updateStreak(childId: String, streak: Int) async throws {}
        func updateSessionAggregates(childId: String, lastSessionAt: Date, addedMinutes: Int, streak: Int) async throws {}
    }
}
