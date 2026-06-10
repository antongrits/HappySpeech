import Foundation
import OSLog

// MARK: - ProgramTemplateExportError

enum ProgramTemplateExportError: LocalizedError {
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case fileUnreadable
    case versionMismatch(found: Int, required: Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return String(localized: "program_editor.export.error.encoding")
        case .decodingFailed:
            return String(localized: "program_editor.export.error.decoding")
        case .fileUnreadable:
            return String(localized: "program_editor.export.error.unreadable")
        case let .versionMismatch(found, required):
            return String(
                format: String(localized: "program_editor.export.error.version_mismatch"),
                found,
                required
            )
        case .invalidPayload:
            return String(localized: "program_editor.export.error.invalid_payload")
        }
    }
}

// MARK: - ProgramTemplatePayload

/// Версионированная обёртка для шаблона программы.
/// Поле `version` обязательно для обратной совместимости при импорте.
struct ProgramTemplatePayload: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: String
    let childId: String
    let specialistNotes: String
    let blocks: [ProgramBlock]

    init(program: Program) {
        version = Self.currentVersion
        exportedAt = ISO8601DateFormatter().string(from: Date())
        childId = program.childId
        specialistNotes = program.specialistNotes
        blocks = program.blocks
    }

    /// Восстановить `Program` из payload. При несовместимой версии — ошибка.
    func toProgram() throws -> Program {
        guard version <= Self.currentVersion else {
            throw ProgramTemplateExportError.versionMismatch(
                found: version,
                required: Self.currentVersion
            )
        }
        return Program(
            childId: childId,
            blocks: blocks,
            specialistNotes: specialistNotes,
            updatedAt: Date()
        )
    }
}

// MARK: - ProgramTemplateExportWorker

/// Stateless worker: кодирует/декодирует шаблон программы в JSON,
/// записывает файл во временный каталог.
struct ProgramTemplateExportWorker: Sendable {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgramTemplateExportWorker")

    // MARK: - Export

    /// Кодирует программу в JSON и записывает во временный каталог.
    /// Возвращает URL готового файла.
    func export(program: Program) throws -> URL {
        let payload = ProgramTemplatePayload(program: program)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            logger.error("export encoding failed: \(error.localizedDescription, privacy: .public)")
            throw ProgramTemplateExportError.encodingFailed(underlying: error)
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hs-programs", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let childSlug = program.childId.isEmpty ? "template" : program.childId
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "program-\(childSlug)-\(timestamp).happyspeech"
        let fileURL = dir.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: .atomic)
        logger.info("exported program to \(fileURL.lastPathComponent, privacy: .public)")
        return fileURL
    }

    // MARK: - Import

    /// Читает и декодирует JSON-шаблон из указанного файла.
    /// Бросает `ProgramTemplateExportError` при любой ошибке.
    func importProgram(from fileURL: URL) throws -> Program {
        // startAccessingSecurityScopedResource is required for URLs returned by
        // SwiftUI .fileImporter (security-scoped bookmarks). Call it regardless
        // of its return value — false just means the URL is not security-scoped
        // (e.g. in unit tests) and the read will still succeed.
        _ = fileURL.startAccessingSecurityScopedResource()
        defer { fileURL.stopAccessingSecurityScopedResource() }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            logger.error("import read failed: \(error.localizedDescription, privacy: .public)")
            throw ProgramTemplateExportError.fileUnreadable
        }

        let decoder = JSONDecoder()
        let payload: ProgramTemplatePayload
        do {
            payload = try decoder.decode(ProgramTemplatePayload.self, from: data)
        } catch {
            logger.error("import decoding failed: \(error.localizedDescription, privacy: .public)")
            throw ProgramTemplateExportError.decodingFailed(underlying: error)
        }

        guard !payload.blocks.isEmpty else {
            throw ProgramTemplateExportError.invalidPayload
        }

        do {
            let program = try payload.toProgram()
            logger.info(
                "imported program blocks=\(program.blocks.count, privacy: .public) version=\(payload.version, privacy: .public)"
            )
            return program
        } catch {
            throw error
        }
    }
}
