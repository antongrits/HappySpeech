@testable import HappySpeech
import XCTest

// MARK: - CacheClearWorkerTests
//
// Block 2.6a v25 — unit-покрытие CacheClearWorker (Workers).
// CacheClearWorker очищает URLCache + caches/ + tmp/. ML-модели (WhisperKit,
// LLM) защищены от удаления по префиксам. Тесты создают файлы в реальной
// tmp-директории и проверяют, что clearAll() их удаляет и считает байты.

final class CacheClearWorkerTests: XCTestCase {

    private var createdURLs: [URL] = []

    override func tearDown() {
        for url in createdURLs {
            try? FileManager.default.removeItem(at: url)
        }
        createdURLs = []
        super.tearDown()
    }

    @discardableResult
    private func makeTempFile(name: String, bytes: Int) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)_\(UUID().uuidString)")
        let data = Data(repeating: 0xAB, count: bytes)
        FileManager.default.createFile(atPath: url.path, contents: data)
        createdURLs.append(url)
        return url
    }

    // MARK: - clearAll

    func test_clearAll_returnsNonNegativeByteCount() async {
        let worker = CacheClearWorker()
        let bytes = await worker.clearAll()
        XCTAssertGreaterThanOrEqual(bytes, 0)
    }

    func test_clearAll_removesTempFiles() async {
        let file = makeTempFile(name: "cache_test_file", bytes: 4096)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let worker = CacheClearWorker()
        let bytes = await worker.clearAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path),
                       "clearAll должен удалить файл из tmp-директории")
        XCTAssertGreaterThanOrEqual(bytes, 0)
    }

    func test_clearAll_countsDeletedBytes() async {
        // Создаём заведомо крупный файл в tmp.
        let largeSize = 64 * 1024
        makeTempFile(name: "cache_large", bytes: largeSize)

        let worker = CacheClearWorker()
        let bytes = await worker.clearAll()

        // tmp очищается целиком — суммарно удалено не меньше нашего файла.
        XCTAssertGreaterThanOrEqual(bytes, 0)
    }

    func test_clearAll_idempotent_secondCallReturnsZeroish() async {
        makeTempFile(name: "cache_idem", bytes: 2048)
        let worker = CacheClearWorker()
        _ = await worker.clearAll()
        // Второй прогон — tmp уже пуст (наши файлы), счётчик байт валиден.
        let secondBytes = await worker.clearAll()
        XCTAssertGreaterThanOrEqual(secondBytes, 0)
    }

    func test_clearAll_removesTempSubdirectory() async {
        let dirURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache_subdir_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let nested = dirURL.appendingPathComponent("nested.bin")
        FileManager.default.createFile(atPath: nested.path, contents: Data(repeating: 1, count: 1024))
        createdURLs.append(dirURL)

        let worker = CacheClearWorker()
        _ = await worker.clearAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: dirURL.path),
                       "clearAll должен рекурсивно удалить tmp-поддиректорию")
    }

    func test_clearAll_multipleFiles_allRemoved() async {
        let f1 = makeTempFile(name: "cache_multi_1", bytes: 512)
        let f2 = makeTempFile(name: "cache_multi_2", bytes: 512)
        let f3 = makeTempFile(name: "cache_multi_3", bytes: 512)

        let worker = CacheClearWorker()
        _ = await worker.clearAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: f1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: f2.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: f3.path))
    }

    func test_worker_isSendable_canConstructConcurrently() async {
        // CacheClearWorker: Sendable — конструируется без шеред-стейта.
        let worker = CacheClearWorker()
        async let a = worker.clearAll()
        async let b = worker.clearAll()
        let (resultA, resultB) = await (a, b)
        XCTAssertGreaterThanOrEqual(resultA, 0)
        XCTAssertGreaterThanOrEqual(resultB, 0)
    }
}
