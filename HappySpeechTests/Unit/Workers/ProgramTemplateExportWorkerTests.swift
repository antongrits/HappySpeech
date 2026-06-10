@testable import HappySpeech
import XCTest

// MARK: - ProgramTemplateExportWorkerTests
//
// Покрывает stateless worker экспорта/импорта шаблонов программ:
//   • export(program:) → создаёт .happyspeech файл во временном каталоге
//   • importProgram(from:) → декодирует назад в Program (round-trip)
//   • ошибки: файл не найден, битый JSON, пустые блоки, версия выше текущей
//   • ProgramTemplatePayload.toProgram() напрямую (проверка versionMismatch)

final class ProgramTemplateExportWorkerTests: XCTestCase {

    // MARK: - Fixtures

    private let worker = ProgramTemplateExportWorker()

    private func makeProgram(
        childId: String = "child-export-1",
        notes: String = "Тренируй звук Р",
        blocks: [ProgramBlock] = [
            ProgramBlock(type: .warmup, durationMinutes: 2),
            ProgramBlock(type: .syllables, durationMinutes: 5, targetSound: "Р")
        ]
    ) -> Program {
        Program(childId: childId, blocks: blocks, specialistNotes: notes, updatedAt: Date())
    }

    // MARK: - Export

    func test_export_createsFileAtReturnedURL() throws {
        let program = makeProgram()
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_export_fileHasHappySpeechExtension() throws {
        let program = makeProgram()
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "happyspeech")
    }

    func test_export_fileNameContainsChildId() throws {
        let program = makeProgram(childId: "abc123")
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(url.lastPathComponent.contains("abc123"))
    }

    func test_export_emptyChildId_usesTemplateSlug() throws {
        let program = makeProgram(childId: "")
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(url.lastPathComponent.contains("template"))
    }

    func test_export_producesValidJSON() throws {
        let program = makeProgram()
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func test_export_payloadContainsCurrentVersion() throws {
        let program = makeProgram()
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let version = json?["version"] as? Int
        XCTAssertEqual(version, ProgramTemplatePayload.currentVersion)
    }

    // MARK: - Round-trip (export → import)

    func test_roundTrip_preservesChildId() throws {
        let program = makeProgram(childId: "round-trip-child")
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try worker.importProgram(from: url)
        XCTAssertEqual(imported.childId, program.childId)
    }

    func test_roundTrip_preservesSpecialistNotes() throws {
        let program = makeProgram(notes: "Важные заметки специалиста")
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try worker.importProgram(from: url)
        XCTAssertEqual(imported.specialistNotes, program.specialistNotes)
    }

    func test_roundTrip_preservesBlockCount() throws {
        let blocks = [
            ProgramBlock(type: .warmup, durationMinutes: 2),
            ProgramBlock(type: .articulationGymnastics, durationMinutes: 3),
            ProgramBlock(type: .breakRest, durationMinutes: 1)
        ]
        let program = makeProgram(blocks: blocks)
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try worker.importProgram(from: url)
        XCTAssertEqual(imported.blocks.count, blocks.count)
    }

    func test_roundTrip_preservesBlockTypes() throws {
        let blocks = [
            ProgramBlock(type: .syllables, durationMinutes: 5, targetSound: "Ш"),
            ProgramBlock(type: .minimalPairs, durationMinutes: 4, targetSound: "Ш")
        ]
        let program = makeProgram(blocks: blocks)
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try worker.importProgram(from: url)
        XCTAssertEqual(imported.blocks.map(\.type), blocks.map(\.type))
    }

    func test_roundTrip_preservesTargetSound() throws {
        let blocks = [ProgramBlock(type: .wordsInitial, durationMinutes: 4, targetSound: "Р")]
        let program = makeProgram(blocks: blocks)
        let url = try worker.export(program: program)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try worker.importProgram(from: url)
        XCTAssertEqual(imported.blocks.first?.targetSound, "Р")
    }

    // MARK: - Import errors

    func test_importProgram_missingFile_throwsFileUnreadable() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_program_\(UUID().uuidString).happyspeech")
        XCTAssertThrowsError(try worker.importProgram(from: url)) { error in
            guard let exportError = error as? ProgramTemplateExportError else {
                return XCTFail("Ожидалась ошибка ProgramTemplateExportError, получено: \(error)")
            }
            if case .fileUnreadable = exportError { } else {
                XCTFail("Ожидалась .fileUnreadable, получено: \(exportError)")
            }
        }
    }

    func test_importProgram_malformedJSON_throwsDecodingFailed() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bad_\(UUID().uuidString).happyspeech")
        try "not valid json {{{".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try worker.importProgram(from: url)) { error in
            guard let exportError = error as? ProgramTemplateExportError else {
                return XCTFail("Ожидалась ошибка ProgramTemplateExportError")
            }
            if case .decodingFailed = exportError { } else {
                XCTFail("Ожидалась .decodingFailed, получено: \(exportError)")
            }
        }
    }

    func test_importProgram_emptyBlocks_throwsInvalidPayload() throws {
        // Собираем JSON вручную с пустым массивом blocks.
        let iso = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "version": ProgramTemplatePayload.currentVersion,
            "exportedAt": iso.string(from: Date()),
            "childId": "child-empty",
            "specialistNotes": "notes",
            "blocks": []
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty_blocks_\(UUID().uuidString).happyspeech")
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try worker.importProgram(from: url)) { error in
            guard let exportError = error as? ProgramTemplateExportError else {
                return XCTFail("Ожидалась ошибка ProgramTemplateExportError")
            }
            if case .invalidPayload = exportError { } else {
                XCTFail("Ожидалась .invalidPayload, получено: \(exportError)")
            }
        }
    }

    // MARK: - ProgramTemplatePayload.toProgram: versionMismatch

    func test_toProgram_futureVersion_throwsVersionMismatch() {
        let iso = ISO8601DateFormatter()
        let payloadJSON: [String: Any] = [
            "version": ProgramTemplatePayload.currentVersion + 99,
            "exportedAt": iso.string(from: Date()),
            "childId": "child-x",
            "specialistNotes": "",
            "blocks": [[
                "id": UUID().uuidString,
                "type": "warmup",
                "durationMinutes": 2
            ]]
        ]
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: payloadJSON)
        // swiftlint:disable:next force_try
        let payload = try! JSONDecoder().decode(ProgramTemplatePayload.self, from: data)

        XCTAssertThrowsError(try payload.toProgram()) { error in
            guard let exportError = error as? ProgramTemplateExportError else {
                return XCTFail("Ожидалась ProgramTemplateExportError")
            }
            if case let .versionMismatch(found, required) = exportError {
                XCTAssertEqual(found, ProgramTemplatePayload.currentVersion + 99)
                XCTAssertEqual(required, ProgramTemplatePayload.currentVersion)
            } else {
                XCTFail("Ожидалась .versionMismatch, получено: \(exportError)")
            }
        }
    }

    func test_toProgram_currentVersion_succeeds() throws {
        let block = ProgramBlock(type: .coolDown, durationMinutes: 1)
        let program = makeProgram(blocks: [block])
        let payload = ProgramTemplatePayload(program: program)
        let restored = try payload.toProgram()
        XCTAssertEqual(restored.childId, program.childId)
        XCTAssertEqual(restored.blocks.count, 1)
    }

    // MARK: - ProgramTemplateExportError descriptions

    func test_errorDescription_fileUnreadable_nonEmpty() {
        XCTAssertFalse(ProgramTemplateExportError.fileUnreadable.errorDescription?.isEmpty ?? true)
    }

    func test_errorDescription_invalidPayload_nonEmpty() {
        XCTAssertFalse(ProgramTemplateExportError.invalidPayload.errorDescription?.isEmpty ?? true)
    }
}
