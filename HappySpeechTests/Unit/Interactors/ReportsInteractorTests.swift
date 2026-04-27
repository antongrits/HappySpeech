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
    }

    // MARK: - 2. fetchReport с сессиями → totalSessions > 0

    func test_fetchReport_withSessions_populatesSummary() async {
        let session = SessionDTO.preview
        let (sut, spy) = makeSUT(sessions: [session])
        let request = ReportsModels.FetchReport.Request(
            childId: "preview-child-1",
            range: DateRange(start: .distantPast, end: .distantFuture)
        )
        await sut.fetchReport(request)
        XCTAssertGreaterThan(spy.lastFetchResponse?.summary.totalSessions ?? 0, 0)
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

    // MARK: - 4. exportReport CSV создаёт файл с ненулевым размером

    func test_exportReport_csv_generatesFile() async {
        let session = SessionDTO.preview
        let (sut, spy) = makeSUT(sessions: [session])
        let request = ReportsModels.ExportReport.Request(
            childId: "preview-child-1",
            range: DateRange(start: .distantPast, end: .distantFuture),
            format: .csv
        )
        await sut.exportReport(request)
        XCTAssertTrue(spy.exportReportCalled)
        XCTAssertGreaterThan(spy.lastExportResponse?.bytes ?? 0, 0)
    }

    // MARK: - 5. exportReport PDF placeholder создаёт файл

    func test_exportReport_pdf_generatesFile() async {
        let session = SessionDTO.preview
        let (sut, spy) = makeSUT(sessions: [session])
        let request = ReportsModels.ExportReport.Request(
            childId: "preview-child-1",
            range: DateRange(start: .distantPast, end: .distantFuture),
            format: .pdf
        )
        await sut.exportReport(request)
        XCTAssertTrue(spy.exportReportCalled)
        XCTAssertNotNil(spy.lastExportResponse?.fileURL)
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
