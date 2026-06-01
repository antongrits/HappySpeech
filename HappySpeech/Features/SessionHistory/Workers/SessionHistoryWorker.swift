import Foundation
import OSLog

// MARK: - SessionHistoryLoading

/// Worker, загружающий РЕАЛЬНУЮ историю сессий ребёнка из репозиториев.
///
/// Источник данных:
/// - `SessionRepository.fetchAll(childId:)` — все завершённые сессии (дата,
///   шаблон, целевой звук, длительность, попытки, правильные попытки и список
///   попыток с реальными аудио-путями и баллами);
/// - `ChildRepository.fetch(id:)` — имя ребёнка (для комментария «Ляли»).
///
/// Никаких выдуманных чисел и `Float.random`: баллы сессий считаются из
/// `successRate` (correct/total), per-attempt баллы берутся из реального
/// `pronunciationScore`/`asrScore`. Если у ребёнка нет сессий, возвращается
/// пустой `SessionHistoryData`, и Presenter показывает честное «пока нет
/// занятий».
@MainActor
protocol SessionHistoryLoading: AnyObject {
    func loadHistory(childId: String) async -> SessionHistoryData
    func childName(childId: String) async -> String?
}

// MARK: - SessionHistoryData

/// Результат загрузки истории — VIP-типы, готовые для интерактора.
struct SessionHistoryData: Sendable, Equatable {
    let sessions: [SessionRecord]
    /// Попытки по идентификатору сессии (реальные per-attempt записи).
    let attempts: [String: [SessionAttemptRecord]]
    /// Локальные аудио-пути по идентификатору сессии (только реально существующие файлы).
    let audioFiles: [String: String]

    static let empty = SessionHistoryData(sessions: [], attempts: [:], audioFiles: [:])
}

// MARK: - SessionHistoryWorker

@MainActor
final class SessionHistoryWorker: SessionHistoryLoading {

    // MARK: - Collaborators

    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionHistoryWorker")

    // MARK: - Init

    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
    }

    // MARK: - Load

    func loadHistory(childId: String) async -> SessionHistoryData {
        guard !childId.isEmpty else {
            logger.info("loadHistory: empty childId → empty")
            return .empty
        }

        let dtos: [SessionDTO]
        do {
            dtos = try await sessionRepository.fetchAll(childId: childId)
        } catch {
            logger.error("loadHistory: fetchAll failed \(error.localizedDescription, privacy: .public)")
            return .empty
        }

        guard !dtos.isEmpty else {
            logger.info("loadHistory: no sessions for child")
            return .empty
        }

        return Self.map(dtos: dtos)
    }

    func childName(childId: String) async -> String? {
        guard !childId.isEmpty else { return nil }
        do {
            let child = try await childRepository.fetch(id: childId)
            return child.name.isEmpty ? nil : child.name
        } catch {
            logger.debug("childName: profile unavailable")
            return nil
        }
    }
}

// MARK: - Pure mapping (тестируемое, без I/O)

extension SessionHistoryWorker {

    /// Маппинг реальных `SessionDTO` в VIP-типы экрана истории.
    /// Балл сессии — `successRate` (correct/total). Per-attempt балл — реальный
    /// `pronunciationScore` (или `asrScore`, если он значимее). Аудио-путь
    /// добавляется, только если файл реально существует на диске.
    static func map(dtos: [SessionDTO]) -> SessionHistoryData {
        var sessions: [SessionRecord] = []
        var attemptsBySession: [String: [SessionAttemptRecord]] = [:]
        var audioFilesBySession: [String: String] = [:]

        for dto in dtos {
            let template = TemplateType(rawValue: dto.templateType) ?? .listenAndChoose
            let score = Float(dto.successRate)
            let sound = dto.targetSound.isEmpty ? "—" : dto.targetSound

            sessions.append(
                SessionRecord(
                    id: dto.id,
                    date: dto.date,
                    gameType: template,
                    soundTarget: sound,
                    score: score,
                    durationSec: dto.durationSeconds,
                    attempts: dto.totalAttempts,
                    isPassed: score >= 0.7
                )
            )

            let attemptRecords = dto.attempts.map { att -> SessionAttemptRecord in
                let attemptScore = Float(max(att.pronunciationScore, att.asrScore))
                return SessionAttemptRecord(
                    id: att.id,
                    word: att.word,
                    score: attemptScore,
                    isCorrect: att.isCorrect,
                    durationMs: 0
                )
            }
            attemptsBySession[dto.id] = attemptRecords

            // Реальное локальное аудио прикрепляем только если файл существует.
            if let path = firstExistingAudioPath(in: dto.attempts) {
                audioFilesBySession[dto.id] = path
            }
        }

        let sorted = sessions.sorted { $0.date > $1.date }
        return SessionHistoryData(
            sessions: sorted,
            attempts: attemptsBySession,
            audioFiles: audioFilesBySession
        )
    }

    /// Возвращает первый реально существующий локальный аудио-путь попытки сессии.
    static func firstExistingAudioPath(in attempts: [AttemptDTO]) -> String? {
        for att in attempts {
            let path = att.audioLocalPath
            guard !path.isEmpty else { continue }
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}
