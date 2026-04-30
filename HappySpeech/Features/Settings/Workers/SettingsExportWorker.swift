import Foundation
import OSLog

// MARK: - SettingsExportWorker
//
// Реальный экспорт пользовательских данных в 3 форматах: PDF, CSV, JSON.
//
// PDF и CSV делегируются `SpecialistExportServiceLive` (PDFKit + ReportsDocumentFormatter),
// чтобы не дублировать логику форматирования отчёта.
//
// JSON — полный дамп сессий + настройки в `SessionExportDTO` / `SettingsExportDTO`.
// Используется для GDPR/интеграций: разработчик / специалист может разобрать
// машиночитаемый файл своими инструментами.

struct SettingsExportWorker: Sendable {

    let sessionRepository: any SessionRepository
    let exportService: any SpecialistExportService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SettingsExportWorker")

    // MARK: - Public API

    func exportPDF(childId: String) async throws -> URL {
        let sessions = try await sessionRepository.fetchAll(childId: childId)
        logger.info("export PDF childId=\(childId, privacy: .private) sessions=\(sessions.count, privacy: .public)")
        return try await exportService.generatePDF(childId: childId, sessions: sessions)
    }

    func exportCSV(childId: String) async throws -> URL {
        let sessions = try await sessionRepository.fetchAll(childId: childId)
        logger.info("export CSV childId=\(childId, privacy: .private) sessions=\(sessions.count, privacy: .public)")
        return try await exportService.generateCSV(childId: childId, sessions: sessions)
    }

    func exportJSON(childId: String, settings: AppSettings) async throws -> URL {
        let sessions = try await sessionRepository.fetchAll(childId: childId)
        logger.info("export JSON childId=\(childId, privacy: .private) sessions=\(sessions.count, privacy: .public)")

        let payload = FullExportPayload(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: bundleVersion,
            buildNumber: bundleBuild,
            childId: childId,
            settings: SettingsExportDTO(from: settings),
            sessions: sessions.map(SessionExportDTO.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let fileManager = FileManager.default
        let dir = fileManager.temporaryDirectory.appendingPathComponent("hs-reports", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let timestamp = Int(Date().timeIntervalSince1970)
        let url = dir.appendingPathComponent("happyspeech-export-\(timestamp).json")
        try data.write(to: url, options: .atomic)

        logger.info("JSON export written: \(url.lastPathComponent, privacy: .public)")
        return url
    }

    // MARK: - Private

    private var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var bundleBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Export DTOs (JSON)

private struct FullExportPayload: Encodable {
    let exportedAt: String
    let appVersion: String
    let buildNumber: String
    let childId: String
    let settings: SettingsExportDTO
    let sessions: [SessionExportDTO]
}

private struct SettingsExportDTO: Encodable {
    let theme: String
    let childName: String
    let childAge: Int
    let notificationsEnabled: Bool
    let audioQuality: String
    let autoDownload: Bool
    let specialistConnected: Bool

    init(from s: AppSettings) {
        theme = s.theme.rawValue
        childName = s.childName
        childAge = s.childAge
        notificationsEnabled = s.notificationsEnabled
        audioQuality = s.audioQuality.rawValue
        autoDownload = s.autoDownload
        specialistConnected = s.specialistConnected
    }
}

private struct SessionExportDTO: Encodable {
    let id: String
    let date: String
    let templateType: String
    let targetSound: String
    let stage: String
    let durationSeconds: Int
    let totalAttempts: Int
    let correctAttempts: Int
    let successRate: Double
    let fatigueDetected: Bool
    let attempts: [AttemptExportDTO]

    init(from dto: SessionDTO) {
        id = dto.id
        date = ISO8601DateFormatter().string(from: dto.date)
        templateType = dto.templateType
        targetSound = dto.targetSound
        stage = dto.stage
        durationSeconds = dto.durationSeconds
        totalAttempts = dto.totalAttempts
        correctAttempts = dto.correctAttempts
        successRate = dto.successRate
        fatigueDetected = dto.fatigueDetected
        attempts = dto.attempts.map(AttemptExportDTO.init)
    }
}

private struct AttemptExportDTO: Encodable {
    let id: String
    let word: String
    let asrTranscript: String
    let asrScore: Double
    let pronunciationScore: Double
    let manualScore: Double
    let isCorrect: Bool
    let timestamp: String

    init(from dto: AttemptDTO) {
        id = dto.id
        word = dto.word
        asrTranscript = dto.asrTranscript
        asrScore = dto.asrScore
        pronunciationScore = dto.pronunciationScore
        manualScore = dto.manualScore
        isCorrect = dto.isCorrect
        timestamp = ISO8601DateFormatter().string(from: dto.timestamp)
    }
}
