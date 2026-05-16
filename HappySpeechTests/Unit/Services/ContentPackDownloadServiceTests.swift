@testable import HappySpeech
import XCTest

// MARK: - ContentPackDownloadServiceTests
//
// 2.6b v25 — покрытие ContentPackDownloadService.
// LiveContentPackDownloadService.init создаёт `Storage.storage()` (Firebase Storage),
// что требует FirebaseApp.configure() — недоступно в unit-окружении (краш процесса
// при первом обращении). Поэтому LiveContentPackDownloadService genuinely SDK-bound
// и НЕ инстанцируется в тестах — документировано для ADR-V25-COVERAGE.
// Покрываем тестируемую чистую логику без Firebase:
//   • ContentPackError — локализованные русские описания;
//   • MockContentPackDownloadService — контракт протокола
//     (success / failure / cache / progress-stream lifecycle).

final class ContentPackDownloadServiceTests: XCTestCase {

    // MARK: - ContentPackError — localized descriptions

    func test_error_descriptions_areNonEmpty() {
        let errors: [ContentPackError] = [
            .packNotFound("sound_r_pack"),
            .diskWriteFailed(NSError(domain: "test", code: 1)),
            .alreadyDownloading("sound_s_pack")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "\(error) без описания")
        }
    }

    func test_error_packNotFound_includesPackId() {
        let description = ContentPackError.packNotFound("sound_l_pack").errorDescription ?? ""
        XCTAssertTrue(description.contains("sound_l_pack"), "Описание должно содержать id пака")
    }

    func test_error_alreadyDownloading_includesPackId() {
        let description = ContentPackError.alreadyDownloading("sound_sh_pack").errorDescription ?? ""
        XCTAssertTrue(description.contains("sound_sh_pack"))
    }

    func test_error_diskWriteFailed_includesUnderlyingDescription() {
        let underlying = NSError(
            domain: "DiskTest",
            code: 28,
            userInfo: [NSLocalizedDescriptionKey: "Недостаточно места"]
        )
        let description = ContentPackError.diskWriteFailed(underlying).errorDescription ?? ""
        XCTAssertTrue(description.contains("Недостаточно места"))
    }

    // MARK: - MockContentPackDownloadService — downloadPack

    func test_mock_downloadPack_success_recordsPackAndReturnsURL() async throws {
        let mock = MockContentPackDownloadService()
        XCTAssertTrue(mock.downloadedPacks.isEmpty)
        let url = try await mock.downloadPack(id: "sound_r_pack")
        XCTAssertEqual(url.lastPathComponent, "sound_r_pack.json")
        XCTAssertEqual(mock.downloadedPacks, ["sound_r_pack"])
    }

    func test_mock_downloadPack_multipleCalls_accumulate() async throws {
        let mock = MockContentPackDownloadService()
        _ = try await mock.downloadPack(id: "sound_s_pack")
        _ = try await mock.downloadPack(id: "sound_l_pack")
        XCTAssertEqual(mock.downloadedPacks, ["sound_s_pack", "sound_l_pack"])
    }

    func test_mock_downloadPack_returnedURLPointsToTemporaryDirectory() async throws {
        let mock = MockContentPackDownloadService()
        let url = try await mock.downloadPack(id: "sound_k_pack")
        XCTAssertTrue(
            url.path.hasPrefix(FileManager.default.temporaryDirectory.path),
            "Mock возвращает URL внутри temporaryDirectory"
        )
    }

    func test_mock_downloadPack_whenShouldFail_throwsPackNotFound() async {
        let mock = MockContentPackDownloadService()
        mock.shouldFail = true
        do {
            _ = try await mock.downloadPack(id: "sound_k_pack")
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as ContentPackError {
            guard case .packNotFound(let id) = error else {
                return XCTFail("Ожидалась packNotFound, получено \(error)")
            }
            XCTAssertEqual(id, "sound_k_pack")
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    func test_mock_downloadPack_whenShouldFail_doesNotRecordPack() async {
        let mock = MockContentPackDownloadService()
        mock.shouldFail = true
        _ = try? await mock.downloadPack(id: "sound_r_pack")
        XCTAssertTrue(
            mock.downloadedPacks.isEmpty,
            "Неуспешная загрузка не должна попадать в downloadedPacks"
        )
    }

    // MARK: - MockContentPackDownloadService — cachedURL

    func test_mock_cachedURL_alwaysNil() {
        let mock = MockContentPackDownloadService()
        XCTAssertNil(mock.cachedURL(for: "sound_r_pack"))
        XCTAssertNil(mock.cachedURL(for: ""))
    }

    // MARK: - MockContentPackDownloadService — clearCache

    func test_mock_clearCache_removesDownloadedPacks() async throws {
        let mock = MockContentPackDownloadService()
        _ = try await mock.downloadPack(id: "sound_s_pack")
        XCTAssertFalse(mock.downloadedPacks.isEmpty)
        try mock.clearCache()
        XCTAssertTrue(mock.downloadedPacks.isEmpty)
    }

    func test_mock_clearCache_onEmptyState_doesNotThrow() {
        let mock = MockContentPackDownloadService()
        XCTAssertNoThrow(try mock.clearCache())
    }

    // MARK: - MockContentPackDownloadService — downloadProgress

    func test_mock_downloadProgress_yieldsCompletion() async {
        let mock = MockContentPackDownloadService()
        var values: [Double] = []
        for await progress in mock.downloadProgress(id: "sound_r_pack") {
            values.append(progress)
        }
        XCTAssertEqual(values, [1.0], "Mock сразу отдаёт 100% и завершает стрим")
    }

    func test_mock_downloadProgress_streamTerminates() async {
        let mock = MockContentPackDownloadService()
        var iterator = mock.downloadProgress(id: "sound_l_pack").makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, 1.0)
        let afterFinish = await iterator.next()
        XCTAssertNil(afterFinish, "После завершения стрим возвращает nil")
    }
}
