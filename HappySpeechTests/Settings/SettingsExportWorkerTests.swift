@testable import HappySpeech
import XCTest

// MARK: - SettingsExportWorkerTests
//
// Покрывает: exportPDF, exportCSV, exportJSON (happy path + error).
// Зависимости мокаются через протоколы SessionRepository и SpecialistExportService.

// MARK: - MockSpecialistExportService

private final class MockSpecialistExportService: SpecialistExportService, @unchecked Sendable {

    var stubbedPDFURL: URL = URL(fileURLWithPath: "/tmp/stub.pdf")
    var stubbedCSVURL: URL = URL(fileURLWithPath: "/tmp/stub.csv")
    var shouldFailPDF: Bool = false
    var shouldFailCSV: Bool = false

    private(set) var generatePDFCallCount: Int = 0
    private(set) var generateCSVCallCount: Int = 0
    private(set) var lastChildIdForPDF: String?
    private(set) var lastSessionsForPDF: [SessionDTO]?
    private(set) var lastChildIdForCSV: String?

    func generatePDF(childId: String, sessions: [SessionDTO]) async throws -> URL {
        generatePDFCallCount += 1
        lastChildIdForPDF = childId
        lastSessionsForPDF = sessions
        if shouldFailPDF { throw AppError.realmReadFailed("mock PDF fail") }
        return stubbedPDFURL
    }

    func generateCSV(childId: String, sessions: [SessionDTO]) async throws -> URL {
        generateCSVCallCount += 1
        lastChildIdForCSV = childId
        if shouldFailCSV { throw AppError.realmReadFailed("mock CSV fail") }
        return stubbedCSVURL
    }
}

// MARK: - SettingsExportWorkerTests

final class SettingsExportWorkerTests: XCTestCase {

    private var sessionRepository: SpySessionRepository!
    private var exportService: MockSpecialistExportService!
    private var sut: SettingsExportWorker!

    override func setUp() {
        super.setUp()
        sessionRepository = SpySessionRepository(sessions: [
            TestDataBuilder.session(childId: "child-001"),
            TestDataBuilder.session(childId: "child-001")
        ])
        exportService = MockSpecialistExportService()
        sut = SettingsExportWorker(
            sessionRepository: sessionRepository,
            exportService: exportService
        )
    }

    // MARK: - exportPDF

    func test_exportPDF_callsGeneratePDFWithCorrectChildId() async throws {
        let url = try await sut.exportPDF(childId: "child-001")
        XCTAssertEqual(exportService.generatePDFCallCount, 1,
                       "generatePDF должен вызываться один раз")
        XCTAssertEqual(exportService.lastChildIdForPDF, "child-001",
                       "childId должен передаваться в exportService")
        XCTAssertEqual(url, exportService.stubbedPDFURL,
                       "Worker должен возвращать URL из exportService")
    }

    func test_exportPDF_passesAllSessionsToExportService() async throws {
        _ = try await sut.exportPDF(childId: "child-001")
        XCTAssertEqual(exportService.lastSessionsForPDF?.count, 2,
                       "Все сессии ребёнка должны передаваться в exportService")
    }

    func test_exportPDF_propagatesExportServiceError() async {
        exportService.shouldFailPDF = true
        do {
            _ = try await sut.exportPDF(childId: "child-001")
            XCTFail("Ожидалась ошибка от exportService")
        } catch {
            XCTAssertNotNil(error, "Ошибка должна пробрасываться из exportService")
        }
    }

    func test_exportPDF_propagatesRepositoryError() async {
        sessionRepository.shouldFail = true
        do {
            _ = try await sut.exportPDF(childId: "child-001")
            XCTFail("Ожидалась ошибка от sessionRepository")
        } catch {
            XCTAssertNotNil(error, "Ошибка репозитория должна пробрасываться")
        }
    }

    // MARK: - exportCSV

    func test_exportCSV_callsGenerateCSVWithCorrectChildId() async throws {
        let url = try await sut.exportCSV(childId: "child-001")
        XCTAssertEqual(exportService.generateCSVCallCount, 1,
                       "generateCSV должен вызываться один раз")
        XCTAssertEqual(exportService.lastChildIdForCSV, "child-001",
                       "childId должен передаваться корректно")
        XCTAssertEqual(url, exportService.stubbedCSVURL,
                       "Worker должен возвращать URL от exportService")
    }

    func test_exportCSV_propagatesExportServiceError() async {
        exportService.shouldFailCSV = true
        do {
            _ = try await sut.exportCSV(childId: "child-001")
            XCTFail("Ожидалась ошибка")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - exportJSON

    func test_exportJSON_createsFileAtReturnedURL() async throws {
        let settings = AppSettings.default
        let url = try await sut.exportJSON(childId: "child-001", settings: settings)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "JSON файл должен существовать по возвращённому URL")
    }

    func test_exportJSON_fileContainsValidJSON() async throws {
        let settings = AppSettings.default
        let url = try await sut.exportJSON(childId: "child-001", settings: settings)

        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty, "Файл не должен быть пустым")

        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json, "Файл должен содержать валидный JSON")
    }

    func test_exportJSON_containsChildId() async throws {
        let settings = AppSettings.default
        let url = try await sut.exportJSON(childId: "child-json-test", settings: settings)

        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("child-json-test"),
                      "JSON должен содержать childId")
    }

    func test_exportJSON_propagatesRepositoryError() async {
        sessionRepository.shouldFail = true
        do {
            _ = try await sut.exportJSON(childId: "child-001", settings: AppSettings.default)
            XCTFail("Ожидалась ошибка репозитория")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_exportJSON_containsSettingsFields() async throws {
        var settings = AppSettings.default
        settings.childName = "Миша"
        settings.childAge = 7

        let url = try await sut.exportJSON(childId: "child-001", settings: settings)
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(text.contains("\"childAge\" : 7"), "JSON должен содержать childAge")
    }
}
