import Foundation
import GroupActivities
import OSLog
import UIKit

// MARK: - FamilyShareplayController
//
// @Observable контроллер для SharePlay / GroupActivities.
// Управляет жизненным циклом GroupSession<LessonGroupActivity>:
//   1. activate() → FaceTime приглашение
//   2. sessions() → ожидание входящих сессий
//   3. GroupSessionMessenger → send / receive SyncMessage
//
// COPPA:
//   - Активируется ТОЛЬКО после BiometricGate.success (проверяется в SharePlayInteractor).
//   - SyncMessage не содержит PII — только roundIndex, score, soundId.
//   - senderId = UIDevice.identifierForVendor (не имя ребёнка).
//
// Simulator: activate() возвращает false (нет FaceTime) — это ожидаемо, не crash.

@Observable
@MainActor
final class FamilyShareplayController {

    // MARK: - Published state

    private(set) var session: GroupSession<LessonGroupActivity>?
    private(set) var participants: [Participant] = []
    private(set) var isActive: Bool = false

    // MARK: - Private

    // GroupSessionMessenger — не generic, принимает любой GroupSession при инициализации
    private var messenger: GroupSessionMessenger?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyShareplayController"
    )

    private let deviceId: String = {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }()

    // MARK: - Init

    init() {}

    // MARK: - Start (called after BiometricGate.success)

    /// Активирует GroupActivity.
    /// - Returns: `true` если FaceTime доступен и приглашение отправлено.
    ///            `false` на симуляторе (нет активного FaceTime-звонка).
    /// - Throws: `SharePlayError.notActivated` при сбое GroupActivities.
    func activate(
        lessonId: String,
        soundId: String,
        templateKind: String
    ) async throws -> Bool {
        let activity = LessonGroupActivity(
            lessonId: lessonId,
            soundId: soundId,
            templateKind: templateKind
        )

        let prepareResult = await activity.prepareForActivation()
        switch prepareResult {
        case .activationPreferred, .activationDisabled:
            // activationDisabled — допустимо на симуляторе, не крашим
            break
        case .cancelled:
            Self.logger.info("GroupActivity prepare cancelled by user")
            throw SharePlayError.notActivated
        @unknown default:
            Self.logger.warning("GroupActivity prepareForActivation: unknown result")
        }

        do {
            let activated = try await activity.activate()
            Self.logger.info("GroupActivity activate result=\(activated)")
            return activated
        } catch {
            Self.logger.error("GroupActivity activate failed: \(error.localizedDescription)")
            throw SharePlayError.notActivated
        }
    }

    // MARK: - Observe incoming sessions

    /// Запускает long-running Task для приёма входящих SharePlay-сессий.
    /// Должен вызываться один раз при старте родительского контура.
    func observeSessions() {
        Task { [weak self] in
            for await newSession in LessonGroupActivity.sessions() {
                guard let self else { return }
                await self.handleNewSession(newSession)
            }
        }
    }

    // MARK: - Send

    /// Отправляет SyncMessage всем участникам активной сессии.
    func send(_ kind: SyncMessage.Kind) async throws {
        guard let messenger else {
            throw SharePlayError.messengerUnavailable
        }
        let msg = SyncMessage(
            kind: kind,
            timestamp: Date().timeIntervalSince1970,
            senderId: deviceId
        )
        try await messenger.send(msg)
        Self.logger.debug("SyncMessage sent: \(String(describing: kind))")
    }

    // MARK: - Receive messages as AsyncStream

    /// Возвращает поток входящих SyncMessage от других участников.
    func incomingMessages() -> AsyncStream<SyncMessage> {
        AsyncStream { [weak self] continuation in
            guard let self, let messenger = self.messenger else {
                continuation.finish()
                return
            }
            let myDeviceId = self.deviceId
            Task {
                for await (message, context) in messenger.messages(of: SyncMessage.self) {
                    // Игнорируем сообщения от самого себя
                    if message.senderId == myDeviceId { continue }
                    Self.logger.debug(
                        "SyncMessage received from participant=\(context.source.id.uuidString, privacy: .public)"
                    )
                    continuation.yield(message)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - End

    func endSession() {
        session?.leave()
        session = nil
        messenger = nil
        isActive = false
        participants = []
        Self.logger.info("SharePlay session ended")
    }

    // MARK: - Private

    private func handleNewSession(_ newSession: GroupSession<LessonGroupActivity>) async {
        session = newSession
        // GroupSessionMessenger инициализируется с любым GroupSession — не generic
        messenger = GroupSessionMessenger(session: newSession)
        newSession.join()
        isActive = true

        Self.logger.info(
            "New GroupSession joined, lessonId=\(newSession.activity.lessonId, privacy: .public)"
        )

        // Отслеживаем участников
        Task { [weak self] in
            for await newParticipants in newSession.$activeParticipants.values {
                self?.participants = Array(newParticipants)
                Self.logger.info("Participants updated: \(newParticipants.count)")
            }
        }

        // Отслеживаем состояние сессии
        Task { [weak self] in
            for await state in newSession.$state.values {
                switch state {
                case .joined:
                    Self.logger.info("Session state: joined")
                case .waiting:
                    Self.logger.info("Session state: waiting")
                case .invalidated(let reason):
                    Self.logger.info("Session invalidated: \(reason.localizedDescription)")
                    await self?.invalidateSession()
                @unknown default:
                    break
                }
            }
        }
    }

    private func invalidateSession() async {
        session = nil
        messenger = nil
        isActive = false
        participants = []
        Self.logger.info("Session invalidated, state reset")
    }
}
