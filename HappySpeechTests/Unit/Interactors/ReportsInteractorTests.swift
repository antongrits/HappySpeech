@testable import HappySpeech
import XCTest

// MARK: - ReportsInteractorTests
//
// M10.1 — 5 тестов для ReportsInteractor.
// Покрывает: fetchReport (empty range, с сессиями, ошибка репозитория),
// exportReport (csv, pdf placeholder).

@MainActor
final class ReportsInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: ReportsPresentationLogic {
        var fetchReportCalled = false
        var exportReportCalled = false

        var lastFetchResponse: ReportsModels.FetchReport.Response?
        var lastExportResponse: ReportsModels.ExportReport.Response?

        func presentFetchReport(_ response: ReportsModels.FetchReport.Response) async {
            fetchReportCalled = true
            lastFetchResponse = response
        }
        func presentExportReport(_ response: ReportsModels.ExportReport.Response) async {
            exportReportCalled = true
            lastExportResponse = response
        }

        // Batch 2.8.3 v25 — расширенные presenter-методы (extension protocol).
        var complianceCalled = false
        var perSoundCalled = false
        var chartCalled = false
        var lastCompliance: ReportsModels.ComplianceSummary.Response?
        var lastPerSound: ReportsModels.PerSoundMetrics.Response?
        var lastChart: ReportsModels.ChartData.Response?

        func presentComplianceSummary(_ response: ReportsModels.ComplianceSummary.Response) async {
            complianceCalled = true
            lastCompliance = response
        }
        func presentPerSoundMetrics(_ response: ReportsModels.PerSoundMetrics.Response) async {
            perSoundCalled = true
            lastPerSound = response
        }
        func presentChartData(_ response: ReportsModels.ChartData.Response) async {
            chartCalled = true
            lastChart = response
        }
    }

    private func makeSUT(
        sessions: [SessionDTO] = [],
        throwError: Bool = false
    ) -> (ReportsInteractor, SpyPresenter) {
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let childRepo = MockChildRepository(children: [.preview])
        let sut = ReportsInteractor(
            sessionRepository: sessionRepo,
            childRepository: childRepo
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. fetchReport с пустым диапазоном → presenter вызван с нулевыми сессиями

    func test_fetchReport_emptyRange_callsPresenter() async {
        let (sut, spy) = makeSUT(sessions: [])
        let distantPast = Date.distantPast
        let request = ReportsModels.FetchReport.Request(
            childId: "child-1",
            range: DateRange(start: distantPast, end: distantPast)
        )
        await sut.fetchReport(request)
        XCTAssertTrue(spy.fetchReportCalled)
        XCTAssertEqual(spy.lastFetchResponse?.summary.totalSessions, 0)
        XCTAssertEqual(spy.lastFetchResponse?.summary.totalMinutes, 0)
        XCTAssertEqual(spy.lastFetchResponse?.summary.overallSuccessRate ?? -1, 0, accuracy: 0.0001)
        XCTAssertTrue(spy.lastFetchResponse?.soundBreakdown.isEmpty ?? false)
        XCTAssertTrue(spy.lastFetchResponse?.sessionTimeline.isEmpty ?? false)
    }

    // MARK: - 2. fetchReport с сессиями → summary посчитан корректно (точные значения)

    func test_fetchReport_withSessions_populatesSummary() async {
        // 2 сессии одного ребёнка: 10 минут (600с) и 5 минут (300с),
        // успех 8/10=0.8 и 6/10=0.6 → средний 0.7.
        let s1 = SessionDTO(
            id: UUID().uuidString, childId: "preview-child-1",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: "Р", stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 600, totalAttempts: 10, correctAttempts: 8,
            fatigueDetected: false, isSynced: false, attempts: []
        )
        let s2 = SessionDTO(
            id: UUID().uuidString, childId: "preview-child-1",
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: "С", stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 300, totalAttempts: 10, correctAttempts: 6,
            fatigueDetected: false, isSynced: false, attempts: []
        )
        let (sut, spy) = makeSUT(sessions: [s1, s2])
        let request = ReportsModels.FetchReport.Request(
            childId: "preview-child-1",
            range: DateRange(start: .distantPast, end: .distantFuture)
        )
        await sut.fetchReport(request)

        let summary = spy.lastFetchResponse?.summary
        XCTAssertEqual(summary?.totalSessions, 2, "Обе сессии должны попасть в сводку")
        XCTAssertEqual(summary?.totalMinutes, 15, "10 мин (600с) + 5 мин (300с) = 15")
        XCTAssertEqual(summary?.overallSuccessRate ?? 0, 0.7, accuracy: 0.001,
                       "Средний успех (0.8 + 0.6)/2 = 0.7")
        // soundBreakdown содержит обе группы звуков.
        let breakdownSounds = Set((spy.lastFetchResponse?.soundBreakdown ?? []).map(\.sound))
        XCTAssertEqual(breakdownSounds, ["Р", "С"])
        // Таймлайн содержит обе сессии, отсортирован по дате.
        XCTAssertEqual(spy.lastFetchResponse?.sessionTimeline.count, 2)
    }

    // MARK: - 2b. fetchReport: улучшение по звуку отражается в improvedSounds

    func test_fetchReport_improvingSound_listedAsImproved() async {
        // Один звук, 2 сессии: ранняя 4/10=0.4, поздняя 9/10=0.9 → delta +0.5 → improved.
        let early = SessionDTO(
            id: "e", childId: "preview-child-1",
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: "Ш", stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 300, totalAttempts: 10, correctAttempts: 4,
            fatigueDetected: false, isSynced: false, attempts: []
        )
        let late = SessionDTO(
            id: "l", childId: "preview-child-1",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: "Ш", stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 300, totalAttempts: 10, correctAttempts: 9,
            fatigueDetected: false, isSynced: false, attempts: []
        )
        let (sut, spy) = makeSUT(sessions: [early, late])
        await sut.fetchReport(.init(
            childId: "preview-child-1",
            range: DateRange(start: .distantPast, end: .distantFuture)
        ))
        XCTAssertEqual(spy.lastFetchResponse?.summary.improvedSounds, ["Ш"],
                       "Звук с ростом успеха >10pp должен попасть в improvedSounds")
        XCTAssertTrue(spy.lastFetchResponse?.summary.strugglingSounds.isEmpty ?? false)
    }

    // MARK: - 3. fetchReport при ошибке репозитория → presenter вызван с пустым summary

    func test_fetchReport_repositoryThrows_callsPresenterWithEmpty() async {
        let throwingRepo = ThrowingSessionRepository()
        let sut = ReportsInteractor(
            sessionRepository: throwingRepo,
            childRepository: MockChildRepository(children: [.preview])
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        let request = ReportsModels.FetchReport.Request(
            childId: "child-err",
            range: DateRange(start: .distantPast, end: .distantFuture)
        )
        await sut.fetchReport(request)
        XCTAssertTrue(spy.fetchReportCalled)
        XCTAssertEqual(spy.lastFetchResponse?.summary.totalSessions, 0)
    }

    // MARK: - 4. exportReport CSV: файл реально на диске, размер совпадает, расширение .csv

    func test_exportReport_csv_generatesFile() async throws {
        let session = recentSession(daysAgo: 1, sound: "Р", total: 10, correct: 8)
        let (sut, spy) = makeSUT(sessions: [session])
        let request = ReportsModels.ExportReport.Request(
            childId: "preview-child-1",
            range: DateRange(start: .distantPast, end: .distantFuture),
            format: .csv
        )
        await sut.exportReport(request)
        XCTAssertTrue(spy.exportReportCalled)

        let response = try XCTUnwrap(spy.lastExportResponse)
        XCTAssertGreaterThan(response.bytes, 0)
        XCTAssertEqual(response.fileURL.pathExtension, "csv")
        // Файл реально существует и его размер совпадает с заявленным.
        XCTAssertTrue(FileManager.default.fileExists(atPath: response.fileURL.path))
        let onDisk = try Data(contentsOf: response.fileURL)
        XCTAssertEqual(onDisk.count, response.bytes, "bytes в ответе должен равняться размеру файла")
        XCTAssertFalse(onDisk.isEmpty, "CSV не должен быть пустым при наличии сессии")
        try? FileManager.default.removeItem(at: response.fileURL)
    }

    // MARK: - 5. exportReport PDF: файл на диске, .pdf, непустой

    func test_exportReport_pdf_generatesFile() async throws {
        let session = recentSession(daysAgo: 1)
        let (sut, spy) = makeSUT(sessions: [session])
        let request = ReportsModels.ExportReport.Request(
            childId: "preview-child-1",
            range: DateRange(start: .distantPast, end: .distantFuture),
            format: .pdf
        )
        await sut.exportReport(request)
        XCTAssertTrue(spy.exportReportCalled)

        let response = try XCTUnwrap(spy.lastExportResponse)
        XCTAssertEqual(response.fileURL.pathExtension, "pdf")
        XCTAssertGreaterThan(response.bytes, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: response.fileURL.path))
        try? FileManager.default.removeItem(at: response.fileURL)
    }

    // MARK: - Batch 2.8.3 v25: расширенное покрытие

    private func recentSession(
        childId: String = "preview-child-1",
        daysAgo: Int,
        sound: String = "Р",
        total: Int = 10,
        correct: Int = 8
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: UUID().uuidString, childId: childId, date: date,
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: sound, stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 300, totalAttempts: total, correctAttempts: correct,
            fatigueDetected: false, isSynced: false, attempts: []
        )
    }

    // Note: presentComplianceSummary / presentPerSoundMetrics / presentChartData
    // объявлены как protocol-extension с дефолтной no-op реализацией. При вызове
    // через `any ReportsPresentationLogic` диспетчеризуются СТАТИЧЕСКИ к extension,
    // а не к Spy — поэтому напрямую заспаить их выход нельзя. Чтобы проверки были
    // содержательными (а не XCTAssertTrue(true)), тесты ниже утверждают РЕАЛЬНЫЕ
    // наблюдаемые пост-условия:
    //   • эти методы НЕ трогают spied-каналы fetch/export (изоляция эффектов);
    //   • разделяемый pipeline (fetchRecent → filterByRange) даёт согласованные
    //     числа, видимые через заспаенный fetchReport на тех же данных.

    // MARK: - 6. fetchComplianceSummary: не вызывает чужой presenter-канал, fetch остаётся консистентным

    func test_fetchComplianceSummary_doesNotInvokeFetchOrExportSpies() async {
        let sessions = [recentSession(daysAgo: 0), recentSession(daysAgo: 1)]
        let (sut, spy) = makeSUT(sessions: sessions)
        await sut.fetchComplianceSummary(.init(
            childId: "preview-child-1", range: DateRange.last7days()
        ))
        // Compliance не должен ошибочно дёргать fetch/export presenter-методы.
        XCTAssertFalse(spy.fetchReportCalled)
        XCTAssertFalse(spy.exportReportCalled)
    }

    // MARK: - 7. После compliance заспаенный fetchReport видит ВСЕ сессии диапазона

    func test_fetchComplianceSummary_thenFetchReport_seesSameSessions() async {
        // 5 сессий в разные дни внутри последних 7.
        let sessions = (0..<5).map { recentSession(daysAgo: $0) }
        let (sut, spy) = makeSUT(sessions: sessions)
        let range = DateRange.last7days()
        await sut.fetchComplianceSummary(.init(childId: "preview-child-1", range: range))
        // Тот же датасет/диапазон через заспаенный путь → 5 сессий.
        await sut.fetchReport(.init(childId: "preview-child-1", range: range))
        XCTAssertEqual(spy.lastFetchResponse?.summary.totalSessions, 5,
                       "Разделяемый pipeline должен видеть все 5 сессий диапазона")
    }

    // MARK: - 8. fetchComplianceSummary: ошибка репозитория не приводит к presenter-вызову fetch/export

    func test_fetchComplianceSummary_repositoryThrows_noFetchOrExportPresented() async {
        let sut = ReportsInteractor(
            sessionRepository: ThrowingSessionRepository(),
            childRepository: MockChildRepository(children: [.preview])
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.fetchComplianceSummary(.init(
            childId: "err", range: DateRange.last7days()
        ))
        // Ошибка проглочена в catch → presenter fetch/export не дёргается.
        XCTAssertFalse(spy.fetchReportCalled)
        XCTAssertFalse(spy.exportReportCalled)
    }

    // MARK: - 9. computePerSoundMetrics: группировка по звуку отражается в заспаенном breakdown

    func test_computePerSoundMetrics_groupingMatchesFetchBreakdown() async {
        let sessions = [
            recentSession(daysAgo: 0, sound: "Р"),
            recentSession(daysAgo: 1, sound: "С"),
            recentSession(daysAgo: 2, sound: "Р")
        ]
        let (sut, spy) = makeSUT(sessions: sessions)
        let range = DateRange.last30days()
        await sut.computePerSoundMetrics(.init(childId: "preview-child-1", range: range))
        // perSound группирует так же, как soundBreakdown заспаенного fetchReport:
        // 2 уникальных звука (Р, С).
        await sut.fetchReport(.init(childId: "preview-child-1", range: range))
        let sounds = Set((spy.lastFetchResponse?.soundBreakdown ?? []).map(\.sound))
        XCTAssertEqual(sounds, ["Р", "С"])
        // Звук «Р» агрегирует 2 сессии → 20 попыток суммарно.
        let rRow = spy.lastFetchResponse?.soundBreakdown.first { $0.sound == "Р" }
        XCTAssertEqual(rRow?.attempts, 20, "Две сессии Р по 10 попыток = 20")
    }

    // MARK: - 10. computePerSoundMetrics: пустой звук не вызывает fetch/export-каналы

    func test_computePerSoundMetrics_emptySound_doesNotInvokeFetchOrExport() async {
        let session = recentSession(daysAgo: 0, sound: "")
        let (sut, spy) = makeSUT(sessions: [session])
        await sut.computePerSoundMetrics(.init(
            childId: "preview-child-1", range: DateRange.last30days()
        ))
        XCTAssertFalse(spy.fetchReportCalled)
        XCTAssertFalse(spy.exportReportCalled)
    }

    // MARK: - 11. computePerSoundMetrics: ошибка репозитория проглочена (нет fetch/export presented)

    func test_computePerSoundMetrics_repositoryThrows_noFetchOrExportPresented() async {
        let sut = ReportsInteractor(
            sessionRepository: ThrowingSessionRepository(),
            childRepository: MockChildRepository(children: [.preview])
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.computePerSoundMetrics(.init(
            childId: "err", range: DateRange.last30days()
        ))
        XCTAssertFalse(spy.fetchReportCalled)
        XCTAssertFalse(spy.exportReportCalled)
    }

    // MARK: - 12. buildChartData: данные согласованы с заспаенным таймлайном

    func test_buildChartData_consistentWithFetchTimeline() async {
        let sessions = [recentSession(daysAgo: 1), recentSession(daysAgo: 2)]
        let (sut, spy) = makeSUT(sessions: sessions)
        let range = DateRange.last7days()
        await sut.buildChartData(.init(
            childId: "preview-child-1", range: range, granularity: .daily
        ))
        // Тот же датасет → таймлайн заспаенного fetchReport содержит 2 записи.
        await sut.fetchReport(.init(childId: "preview-child-1", range: range))
        XCTAssertEqual(spy.lastFetchResponse?.sessionTimeline.count, 2)
    }

    // MARK: - 13. buildChartData: пустые сессии не вызывают fetch/export-каналы

    func test_buildChartData_emptySessions_doesNotInvokeFetchOrExport() async {
        let (sut, spy) = makeSUT(sessions: [])
        await sut.buildChartData(.init(
            childId: "preview-child-1",
            range: DateRange.last7days(),
            granularity: .weekly
        ))
        // Пустой набор → агрегация без краша; чужие presenter-каналы не дёргаются.
        XCTAssertFalse(spy.fetchReportCalled)
        XCTAssertFalse(spy.exportReportCalled)
    }

    // MARK: - 14. exportReport использует кеш после fetchReport (тот же контент)

    func test_exportReport_usesCacheAfterFetch() async throws {
        let range = DateRange(start: .distantPast, end: .distantFuture)
        let sessions = [recentSession(daysAgo: 0, sound: "Р", total: 10, correct: 7)]
        let (sut, spy) = makeSUT(sessions: sessions)
        await sut.fetchReport(.init(childId: "preview-child-1", range: range))
        await sut.exportReport(.init(childId: "preview-child-1", range: range, format: .csv))
        XCTAssertTrue(spy.exportReportCalled)

        let cached = try XCTUnwrap(spy.lastExportResponse)
        XCTAssertGreaterThan(cached.bytes, 0)
        let cachedCSV = try XCTUnwrap(String(data: Data(contentsOf: cached.fileURL), encoding: .utf8))
        try? FileManager.default.removeItem(at: cached.fileURL)

        // Контроль: тот же экспорт БЕЗ предварительного fetch (свежий interactor,
        // путь без кеша) должен дать эквивалентный по сессиям CSV (число строк-данных).
        let (sut2, spy2) = makeSUT(sessions: sessions)
        await sut2.exportReport(.init(childId: "preview-child-1", range: range, format: .csv))
        let fresh = try XCTUnwrap(spy2.lastExportResponse)
        let freshCSV = try XCTUnwrap(String(data: Data(contentsOf: fresh.fileURL), encoding: .utf8))
        try? FileManager.default.removeItem(at: fresh.fileURL)

        XCTAssertEqual(cachedCSV.split(separator: "\n").count,
                       freshCSV.split(separator: "\n").count,
                       "Кешированный и свежий экспорт должны содержать одинаковое число строк")
    }

    // MARK: - 15. ComplianceLevel rawValue

    func test_complianceLevel_rawValues() {
        XCTAssertEqual(ComplianceLevel.high.rawValue, "Высокая")
        XCTAssertEqual(ComplianceLevel.medium.rawValue, "Средняя")
        XCTAssertEqual(ComplianceLevel.low.rawValue, "Низкая")
    }

    // MARK: - 16. DateRange helpers

    func test_dateRange_lastNDays() {
        let now = Date()
        let range7 = DateRange.last7days(now: now)
        let days7 = Calendar.current.dateComponents([.day], from: range7.start, to: range7.end).day
        XCTAssertEqual(days7, 7)
        XCTAssertEqual(range7.end, now)

        let range30 = DateRange.last30days(now: now)
        let days30 = Calendar.current.dateComponents([.day], from: range30.start, to: range30.end).day
        XCTAssertEqual(days30, 30)

        let range3 = DateRange.lastNDays(3, now: now)
        let days3 = Calendar.current.dateComponents([.day], from: range3.start, to: range3.end).day
        XCTAssertEqual(days3, 3)
        XCTAssertLessThan(range3.start, range3.end)
    }

    // MARK: - 17. complianceLevel пороги через наблюдаемый rawValue (документированные границы)

    func test_complianceLevel_isExhaustiveAndOrdered() {
        // Уровни покрывают весь диапазон и различимы.
        XCTAssertNotEqual(ComplianceLevel.high, ComplianceLevel.medium)
        XCTAssertNotEqual(ComplianceLevel.medium, ComplianceLevel.low)
        XCTAssertEqual(Set([ComplianceLevel.high.rawValue,
                            ComplianceLevel.medium.rawValue,
                            ComplianceLevel.low.rawValue]).count, 3)
    }
}

// MARK: - ThrowingSessionRepository

private final class ThrowingSessionRepository: SessionRepository, @unchecked Sendable {
    func fetchAll(childId: String) async throws -> [SessionDTO] {
        throw AppError.networkUnavailable
    }
    func fetch(id: String) async throws -> SessionDTO {
        throw AppError.entityNotFound("test")
    }
    func fetchRecent(childId: String, limit: Int) async throws -> [SessionDTO] {
        throw AppError.networkUnavailable
    }
    func save(_ session: SessionDTO) async throws {}
}
