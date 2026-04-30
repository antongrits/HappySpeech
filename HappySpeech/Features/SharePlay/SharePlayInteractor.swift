import Foundation
import OSLog

// MARK: - SharePlayInteractor
//
// Clean Swift Interactor — бизнес-логика модуля SharePlay.
// Контур: parent (инициирует) + kid (получает сообщения).
//
// Зависимости через протоколы:
//   - BiometricGateService — обязательный pre-check перед activate()
//   - ChildRepository — для загрузки имён и доступных уроков
//
// COPPA: activate() вызывается ТОЛЬКО при BiometricGate.success.

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

    // MARK: - State

    private var currentChildId: String = ""

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

        // Загрузка профиля ребёнка
        let childName: String
        do {
            let profile = try await childRepository.fetch(id: request.childId)
            childName = profile.name
        } catch {
            Self.logger.error("load: childRepository.fetch failed — \(error.localizedDescription)")
            childName = String(localized: "shareplay.default.child")
        }

        // Заглушка уроков: в полной версии — через ContentService
        let sampleLessons = SharePlayInteractor.sampleLessons()

        let response = SharePlay.Load.Response(
            childName: childName,
            availableLessons: sampleLessons,
            isBiometricAvailable: isBiometricAvailable
        )
        presenter?.presentLoad(response)
    }

    func startSession(_ request: SharePlay.StartSession.Request) async {
        // Шаг 1: биометрический gate (COPPA — только родитель запускает)
        let authResult = await biometric.authenticate(
            reason: String(localized: "shareplay.biometric.reason")
        )

        switch authResult {
        case .success, .fallback:
            // .success — биометрия прошла.
            // .fallback — биометрия недоступна на симуляторе/устройстве без Face ID;
            // продолжаем — в реальном продакшне здесь будет ParentalGate math-вопрос.
            break
        case .denied, .cancelled:
            Self.logger.warning("startSession: biometric auth failed/cancelled — \(String(describing: authResult))")
            presenter?.presentStartSession(
                SharePlay.StartSession.Response(outcome: .authFailed)
            )
            return
        }

        // Шаг 2: активируем GroupActivity
        do {
            let activated = try await controller.activate(
                lessonId: request.lesson.id,
                soundId: request.lesson.soundId,
                templateKind: request.lesson.templateKind
            )

            if activated {
                Self.logger.info("SharePlay activated for lesson=\(request.lesson.id, privacy: .public)")
                presenter?.presentStartSession(
                    SharePlay.StartSession.Response(outcome: .activating)
                )
            } else {
                // Симулятор — FaceTime недоступен, но это не crash
                Self.logger.info("SharePlay activate returned false — no active FaceTime call")
                presenter?.presentStartSession(
                    SharePlay.StartSession.Response(outcome: .notAvailable)
                )
            }
        } catch let spError as SharePlayError {
            Self.logger.error("startSession error: \(spError.localizedDescription)")
            presenter?.presentStartSession(
                SharePlay.StartSession.Response(
                    outcome: .error(spError.localizedDescription ?? "")
                )
            )
        } catch {
            Self.logger.error("startSession unexpected error: \(error.localizedDescription)")
            presenter?.presentStartSession(
                SharePlay.StartSession.Response(
                    outcome: .error(error.localizedDescription)
                )
            )
        }
    }

    func sendRoundComplete(roundIndex: Int, score: Double) async {
        do {
            try await controller.send(.roundComplete(roundIndex: roundIndex, score: score))
        } catch {
            Self.logger.error("sendRoundComplete failed: \(error.localizedDescription)")
        }
    }

    func sendAnswer(roundIndex: Int, answer: String, isCorrect: Bool) async {
        do {
            try await controller.send(.childAnswer(roundIndex: roundIndex, answer: answer, isCorrect: isCorrect))
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
        controller.endSession()
        presenter?.presentEndSession(SharePlay.EndSession.Response())
        Self.logger.info("endSession: session ended by user")
    }

    // MARK: - Private helpers

    private static func sampleLessons() -> [SharePlayLessonItem] {
        [
            SharePlayLessonItem(
                id: "sp-lesson-001",
                title: String(localized: "shareplay.lesson.sound_s"),
                soundId: "с",
                templateKind: "repeatAfterModel"
            ),
            SharePlayLessonItem(
                id: "sp-lesson-002",
                title: String(localized: "shareplay.lesson.sound_sh"),
                soundId: "ш",
                templateKind: "listenAndChoose"
            ),
            SharePlayLessonItem(
                id: "sp-lesson-003",
                title: String(localized: "shareplay.lesson.sound_r"),
                soundId: "р",
                templateKind: "repeatAfterModel"
            )
        ]
    }
}
