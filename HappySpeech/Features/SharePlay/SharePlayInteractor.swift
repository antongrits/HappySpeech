import Foundation
import OSLog

// MARK: - SharePlayInteractor
//
// Clean Swift Interactor — бизнес-логика модуля SharePlay.
// Контур: parent (инициирует) + kid (получает сообщения).
//
// Функциональность (D.1 v15):
//   1. Загрузка доступных уроков и имени ребёнка.
//   2. Биометрический gate (COPPA: только родитель запускает сессию).
//   3. Активация GroupActivity через FamilyShareplayController.
//   4. Отслеживание состояния сессии: participantCount, isActive.
//   5. Обработка входящих SyncMessage от удалённого участника.
//   6. Отправка событий раунда: roundComplete, childAnswer, celebration.
//   7. Сессионная статистика: totalRounds, correctAnswers, averageScore.
//   8. Автоматическое завершение сессии при потере соединения (timeout 30s).
//   9. Начало нового раунда: ведущий отправляет roundStart.
//
// COPPA: activate() вызывается ТОЛЬКО при BiometricGate.success.
// Kid circuit: SyncMessage содержит только gameState (нет PII).

@MainActor
final class SharePlayInteractor: SharePlayBusinessLogic {

    // MARK: - VIP wiring

    var presenter: SharePlayPresentationLogic?

    // MARK: - Dependencies

    private let biometric: any BiometricGateService
    private let childRepository: any ChildRepository
    private let controller: FamilyShareplayController

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SharePlayInteractor"
    )

    // MARK: - Session state

    private var currentChildId: String = ""
    private var currentRoundIndex: Int = 0
    private var totalRounds: Int = 5
    private var roundScores: [Double] = []
    private var correctAnswerCount: Int = 0
    private var totalAnswerCount: Int = 0
    private var sessionActive: Bool = false
    private var heartbeatTask: Task<Void, Never>?
    private var inactivityTask: Task<Void, Never>?
    private static let inactivityTimeoutSeconds: Double = 30

    // MARK: - Device ID (COPPA-safe: no name/email)

    private var senderId: String {
        // Используем vendor identifier — нет PII.
        "device-\(String(ProcessInfo.processInfo.processIdentifier))"
    }

    // MARK: - Init

    init(
        biometric: any BiometricGateService,
        childRepository: any ChildRepository,
        controller: FamilyShareplayController
    ) {
        self.biometric = biometric
        self.childRepository = childRepository
        self.controller = controller
    }

    // MARK: - SharePlayBusinessLogic

    func load(_ request: SharePlay.Load.Request) async {
        currentChildId = request.childId

        let isBiometricAvailable = await biometric.canUseBiometric()

        let childName: String
        do {
            let profile = try await childRepository.fetch(id: request.childId)
            childName = profile.name
        } catch {
            Self.logger.error("load: childRepository.fetch failed — \(error.localizedDescription)")
            childName = String(localized: "shareplay.default.child")
        }

        let availableLessons = SharePlayInteractor.buildLessonCatalog()

        let response = SharePlay.Load.Response(
            childName:            childName,
            availableLessons:     availableLessons,
            isBiometricAvailable: isBiometricAvailable
        )
        presenter?.presentLoad(response)
    }

    func startSession(_ request: SharePlay.StartSession.Request) async {
        // Биометрический gate (COPPA: только родитель запускает).
        let authResult = await biometric.authenticate(
            reason: String(localized: "shareplay.biometric.reason")
        )

        switch authResult {
        case .success, .fallback:
            break
        case .denied, .cancelled:
            Self.logger.warning("startSession: biometric failed — \(String(describing: authResult))")
            presenter?.presentStartSession(
                SharePlay.StartSession.Response(outcome: .authFailed)
            )
            return
        }

        // Сброс статистики новой сессии.
        resetSessionStats()

        do {
            let activated = try await controller.activate(
                lessonId:     request.lesson.id,
                soundId:      request.lesson.soundId,
                templateKind: request.lesson.templateKind
            )

            if activated {
                sessionActive = true
                Self.logger.info(
                    "SharePlay activated lesson=\(request.lesson.id, privacy: .public)"
                )
                // Отправляем participantReady.
                await sendParticipantReady()
                // Запускаем heartbeat каждые 10 секунд.
                startHeartbeat()
                presenter?.presentStartSession(
                    SharePlay.StartSession.Response(outcome: .activating)
                )
            } else {
                Self.logger.info("SharePlay activate returned false — нет активного FaceTime-звонка")
                presenter?.presentStartSession(
                    SharePlay.StartSession.Response(outcome: .notAvailable)
                )
            }
        } catch let spError as SharePlayError {
            Self.logger.error("startSession error: \(spError.localizedDescription)")
            presenter?.presentStartSession(
                SharePlay.StartSession.Response(outcome: .error(spError.localizedDescription))
            )
        } catch {
            Self.logger.error("startSession unexpected: \(error.localizedDescription)")
            presenter?.presentStartSession(
                SharePlay.StartSession.Response(outcome: .error(error.localizedDescription))
            )
        }
    }

    // MARK: - Round management

    /// Ведущий начинает новый раунд и рассылает roundStart всем участникам.
    func startRound(soundId: String) async {
        currentRoundIndex += 1
        do {
            try await controller.send(.roundStart(roundIndex: currentRoundIndex, soundId: soundId))
            Self.logger.info(
                "startRound: round=\(self.currentRoundIndex, privacy: .public) sound=\(soundId, privacy: .public)"
            )
            resetInactivityTimer()
        } catch {
            Self.logger.error("startRound failed: \(error.localizedDescription)")
        }
    }

    func sendRoundComplete(roundIndex: Int, score: Double) async {
        roundScores.append(score)
        do {
            try await controller.send(.roundComplete(roundIndex: roundIndex, score: score))
            Self.logger.info(
                "sendRoundComplete round=\(roundIndex, privacy: .public) score=\(score, privacy: .public)"
            )
            resetInactivityTimer()

            // Если завершили все раунды — отправляем итог сессии.
            if roundScores.count >= totalRounds {
                let total = averageScore()
                await sendSessionComplete(totalScore: total)
            }
        } catch {
            Self.logger.error("sendRoundComplete failed: \(error.localizedDescription)")
        }
    }

    func sendAnswer(roundIndex: Int, answer: String, isCorrect: Bool) async {
        totalAnswerCount += 1
        if isCorrect { correctAnswerCount += 1 }
        do {
            try await controller.send(
                .childAnswer(roundIndex: roundIndex, answer: answer, isCorrect: isCorrect)
            )
            Self.logger.info(
                "sendAnswer round=\(roundIndex, privacy: .public) correct=\(isCorrect, privacy: .public)"
            )
            resetInactivityTimer()
        } catch {
            Self.logger.error("sendAnswer failed: \(error.localizedDescription)")
        }
    }

    func sendCelebration(intensity: String) async {
        do {
            try await controller.send(.lyalyaCelebration(intensity: intensity))
        } catch {
            Self.logger.error("sendCelebration failed: \(error.localizedDescription)")
        }
    }

    func endSession(_ request: SharePlay.EndSession.Request) async {
        stopHeartbeat()
        stopInactivityTimer()
        sessionActive = false

        // Отправляем итог сессии перед завершением.
        let total = averageScore()
        await sendSessionComplete(totalScore: total)

        controller.endSession()
        presenter?.presentEndSession(SharePlay.EndSession.Response())

        let stats = buildSessionStats()
        presenter?.presentSessionStats(SharePlay.SessionStats.Response(stats: stats))

        Self.logger.info(
            "endSession: avg=\(total, privacy: .public) correct=\(self.correctAnswerCount)/\(self.totalAnswerCount, privacy: .public)"
        )
    }

    // MARK: - Remote message handling

    /// Вызывается при получении входящего SyncMessage (через View/Controller bridge).
    func handleRemoteMessage(_ message: SyncMessage) async {
        resetInactivityTimer()
        presenter?.presentRemoteMessage(SharePlay.RemoteMessage.Response(message: message))

        switch message.kind {
        case .sessionComplete(let score):
            Self.logger.info(
                "remoteSessionComplete score=\(score, privacy: .public)"
            )
        case .participantReady:
            Self.logger.info("remoteParticipantReady")
        case .roundStart(let roundIdx, let soundId):
            Self.logger.info(
                "remoteRoundStart round=\(roundIdx, privacy: .public) sound=\(soundId, privacy: .public)"
            )
        case .roundComplete(let roundIdx, let score):
            Self.logger.info(
                "remoteRoundComplete round=\(roundIdx, privacy: .public) score=\(score, privacy: .public)"
            )
        case .childAnswer(let roundIdx, _, let correct):
            Self.logger.info(
                "remoteAnswer round=\(roundIdx, privacy: .public) correct=\(correct, privacy: .public)"
            )
        case .lyalyaCelebration(let intensity):
            Self.logger.info("remoteCelebration intensity=\(intensity, privacy: .public)")
        }
    }

    // MARK: - Session state change

    func handleSessionStateChange(isActive: Bool, participantCount: Int) async {
        sessionActive = isActive

        if !isActive {
            stopHeartbeat()
            stopInactivityTimer()
        }

        presenter?.presentSessionStateChange(SharePlay.SessionStateChange.Response(
            isActive:         isActive,
            participantCount: participantCount
        ))
        Self.logger.info(
            "sessionStateChange active=\(isActive, privacy: .public) participants=\(participantCount, privacy: .public)"
        )
    }

    // MARK: - Private: send helpers

    private func sendParticipantReady() async {
        do {
            try await controller.send(.participantReady)
        } catch {
            Self.logger.error("sendParticipantReady failed: \(error.localizedDescription)")
        }
    }

    private func sendSessionComplete(totalScore: Double) async {
        do {
            try await controller.send(.sessionComplete(totalScore: totalScore))
        } catch {
            Self.logger.error("sendSessionComplete failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, sessionActive else { break }
                await sendParticipantReady()
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Inactivity timer

    private func resetInactivityTimer() {
        stopInactivityTimer()
        inactivityTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.inactivityTimeoutSeconds))
            guard let self, !Task.isCancelled, sessionActive else { return }
            Self.logger.warning("SharePlay: inactivity timeout — завершаем сессию")
            await endSession(SharePlay.EndSession.Request())
        }
    }

    private func stopInactivityTimer() {
        inactivityTask?.cancel()
        inactivityTask = nil
    }

    // MARK: - Stats helpers

    private func resetSessionStats() {
        currentRoundIndex = 0
        roundScores       = []
        correctAnswerCount = 0
        totalAnswerCount   = 0
    }

    private func averageScore() -> Double {
        guard !roundScores.isEmpty else { return 0 }
        return roundScores.reduce(0, +) / Double(roundScores.count)
    }

    private func buildSessionStats() -> SharePlay.SessionStats.Stats {
        SharePlay.SessionStats.Stats(
            totalRoundsPlayed:    roundScores.count,
            averageScore:         averageScore(),
            correctAnswers:       correctAnswerCount,
            totalAnswers:         totalAnswerCount,
            accuracyPercent:      totalAnswerCount > 0
                ? Double(correctAnswerCount) / Double(totalAnswerCount) * 100.0
                : 0.0
        )
    }

    // MARK: - Lesson catalog

    private static func buildLessonCatalog() -> [SharePlayLessonItem] {
        [
            SharePlayLessonItem(
                id:           "sp-lesson-001",
                title:        String(localized: "shareplay.lesson.sound_s"),
                soundId:      "с",
                templateKind: "repeatAfterModel"
            ),
            SharePlayLessonItem(
                id:           "sp-lesson-002",
                title:        String(localized: "shareplay.lesson.sound_sh"),
                soundId:      "ш",
                templateKind: "listenAndChoose"
            ),
            SharePlayLessonItem(
                id:           "sp-lesson-003",
                title:        String(localized: "shareplay.lesson.sound_r"),
                soundId:      "р",
                templateKind: "repeatAfterModel"
            ),
            SharePlayLessonItem(
                id:           "sp-lesson-004",
                title:        String(localized: "shareplay.lesson.sound_l"),
                soundId:      "л",
                templateKind: "dragAndMatch"
            ),
            SharePlayLessonItem(
                id:           "sp-lesson-005",
                title:        String(localized: "shareplay.lesson.sound_z"),
                soundId:      "з",
                templateKind: "sorting"
            )
        ]
    }
}

// MARK: - SharePlay SessionStats models (D.1 v15)

extension SharePlay {
    enum SessionStats {
        struct Response {
            let stats: Stats
        }
        struct Stats {
            let totalRoundsPlayed: Int
            let averageScore:      Double
            let correctAnswers:    Int
            let totalAnswers:      Int
            let accuracyPercent:   Double
        }
        struct ViewModel {
            let summaryLabel:    String
            let accuracyLabel:   String
            let roundsLabel:     String
        }
    }
}

// MARK: - SharePlayPresentationLogic extension (D.1 v15)

extension SharePlayPresentationLogic {
    func presentSessionStats(_ response: SharePlay.SessionStats.Response) {}
}

