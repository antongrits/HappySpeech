@testable import HappySpeech
import XCTest

// MARK: - FamilyVoiceRecorderWorkerTests
//
// Тестируются только статические file-path утилиты (нет AVAudioRecorder).
// startRecording/stopRecording/playRecording требуют реального микрофона —
// не тестируются в unit target (hardware-only).

final class FamilyVoiceRecorderWorkerTests: XCTestCase {

    // MARK: - makeFileURL

    func test_makeFileURL_createsURLWithM4aExtension() throws {
        let url = try FamilyVoiceRecorderWorker.makeFileURL(for: "test-id-001")
        XCTAssertEqual(url.pathExtension, "m4a", "Файл должен иметь расширение .m4a")
    }

    func test_makeFileURL_urlContainsSubfolderName() throws {
        let url = try FamilyVoiceRecorderWorker.makeFileURL(for: "test-id-002")
        XCTAssertTrue(
            url.path.contains(FamilyVoiceRecorderWorker.subfolderName),
            "Путь должен содержать имя подпапки '\(FamilyVoiceRecorderWorker.subfolderName)'"
        )
    }

    func test_makeFileURL_urlContainsId() throws {
        let id = "unique-recording-abc"
        let url = try FamilyVoiceRecorderWorker.makeFileURL(for: id)
        XCTAssertTrue(url.lastPathComponent.contains(id),
                      "Имя файла должно содержать переданный id")
    }

    func test_makeFileURL_differentIds_differentURLs() throws {
        let url1 = try FamilyVoiceRecorderWorker.makeFileURL(for: "id-aaa")
        let url2 = try FamilyVoiceRecorderWorker.makeFileURL(for: "id-bbb")
        XCTAssertNotEqual(url1, url2, "Разные id должны давать разные URL")
    }

    func test_makeFileURL_createsDirectory() throws {
        let url = try FamilyVoiceRecorderWorker.makeFileURL(for: "dir-test")
        let folder = url.deletingLastPathComponent()
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path),
                      "makeFileURL должен создавать папку family_recordings")
    }

    // MARK: - resolveFilePath

    func test_resolveFilePath_relativePath_buildsCorrectURL() throws {
        let relative = "family_recordings/sample.m4a"
        let url = try FamilyVoiceRecorderWorker.resolveFilePath(relative)
        XCTAssertTrue(url.path.hasSuffix(relative),
                      "Resolved URL должен заканчиваться на relative path")
    }

    func test_resolveFilePath_doesNotCrash() {
        XCTAssertNoThrow(try FamilyVoiceRecorderWorker.resolveFilePath("any/path.m4a"))
    }

    // MARK: - relativeFilePath

    func test_relativeFilePath_absoluteToRelative_stripsDocumentsPrefix() throws {
        let docsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let absURL = docsURL.appendingPathComponent("family_recordings/test.m4a")
        let relative = try FamilyVoiceRecorderWorker.relativeFilePath(from: absURL)
        XCTAssertFalse(relative.hasPrefix(docsURL.path),
                       "Относительный путь не должен содержать Documents-префикс")
        XCTAssertTrue(relative.contains("family_recordings/test.m4a"))
    }

    func test_relativeFilePath_outsideDocuments_returnsAbsoluteString() throws {
        // Путь вне Documents — возвращается как есть
        let outsideURL = URL(fileURLWithPath: "/tmp/test_recording.m4a")
        let relative = try FamilyVoiceRecorderWorker.relativeFilePath(from: outsideURL)
        XCTAssertEqual(relative, "/tmp/test_recording.m4a")
    }

    // MARK: - stopRecording without active recording → error

    func test_stopRecording_noActiveRecording_throwsError() async {
        let worker = FamilyVoiceRecorderWorker()
        do {
            _ = try await worker.stopRecording()
            XCTFail("Ожидалась ошибка при остановке без активной записи")
        } catch FamilyVoiceError.noActiveRecording {
            // Ожидаемая ошибка
        } catch {
            XCTFail("Ожидалась FamilyVoiceError.noActiveRecording, получено: \(error)")
        }
    }

    // MARK: - FamilyVoiceError: errorDescription not nil

    func test_familyVoiceError_recordingFailed_hasDescription() {
        XCTAssertNotNil(FamilyVoiceError.recordingFailed.errorDescription)
    }

    func test_familyVoiceError_noActiveRecording_hasDescription() {
        XCTAssertNotNil(FamilyVoiceError.noActiveRecording.errorDescription)
    }

    func test_familyVoiceError_fileNotFound_hasDescription() {
        XCTAssertNotNil(FamilyVoiceError.fileNotFound("/some/path").errorDescription)
    }

    func test_familyVoiceError_maxRecordingsReached_hasDescription() {
        XCTAssertNotNil(FamilyVoiceError.maxRecordingsReached.errorDescription)
    }

    func test_familyVoiceError_micPermissionDenied_hasDescription() {
        XCTAssertNotNil(FamilyVoiceError.microphonePermissionDenied.errorDescription)
    }

    // MARK: - subfolderName constant

    func test_subfolderName_isNonEmpty() {
        XCTAssertFalse(FamilyVoiceRecorderWorker.subfolderName.isEmpty)
    }

    func test_subfolderName_value() {
        XCTAssertEqual(FamilyVoiceRecorderWorker.subfolderName, "family_recordings")
    }
}
