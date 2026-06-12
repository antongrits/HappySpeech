import Foundation
import OSLog

// MARK: - PhonemeReportBusinessLogic

@MainActor
protocol PhonemeReportBusinessLogic: AnyObject {
    func load(_ request: PhonemeReportModels.Load.Request) async
}

// MARK: - PhonemeReportInteractor

/// Бизнес-логика экрана «Детальный пофонемный отчёт» (A-09).
///
/// Тянет РЕАЛЬНЫЕ данные: профиль ребёнка (`ChildRepository`) для целевых
/// звуков и имени + полную историю сессий (`SessionRepository`). Никакой
/// фабрикации — все числа считает `PhonemeReportAggregator` из персистентных
/// `SessionDTO`.
@MainActor
final class PhonemeReportInteractor: PhonemeReportBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any PhonemeReportPresentationLogic)?

    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository
    private let phonemeProfileService: any PhonemeProfileServiceProtocol
    private let logger = Logger(subsystem: "ru.happyspeech", category: "PhonemeReport")

    // MARK: - State

    private var lastRows: [PhonemeReportRow] = []
    private var lastProfile: PhonemeProfile?

    // MARK: - Init

    /// - Note: `phonemeProfileService` имеет дефолт через общий контейнер для
    ///   обратной совместимости со старыми call-site / тестами агрегатора.
    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository,
        phonemeProfileService: any PhonemeProfileServiceProtocol = MockPhonemeProfileService()
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
        self.phonemeProfileService = phonemeProfileService
    }

    // MARK: - Load

    func load(_ request: PhonemeReportModels.Load.Request) async {
        do {
            async let profileTask = childRepository.fetch(id: request.childId)
            async let sessionsTask = sessionRepository.fetchAll(childId: request.childId)
            // Паспорт грузится параллельно, но его сбой НЕ валит весь экран —
            // обрабатывается отдельно ниже (graceful degradation).
            async let passportTask = loadPassport(childId: request.childId)

            let (profile, sessions) = try await (profileTask, sessionsTask)
            let passport = await passportTask

            lastRows = PhonemeReportAggregator.buildRows(
                targetSounds: profile.targetSounds,
                sessions: sessions
            )
            lastProfile = passport?.profile

            presenter?.presentLoad(.init(
                childName: profile.name,
                targetSounds: profile.targetSounds,
                sessions: sessions,
                phonemeProfile: passport?.profile,
                forecasts: passport?.forecasts ?? []
            ))
        } catch {
            logger.error("load failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentLoad(.init(
                childName: "",
                targetSounds: [],
                sessions: [],
                error: error
            ))
        }
    }

    // MARK: - Passport (graceful)

    /// Тянет паспорт и прогнозы по топ-проблемным фонемам. Любая ошибка паспорта
    /// логируется и проглатывается → секция паспорта просто скрывается, остальной
    /// отчёт остаётся рабочим.
    private func loadPassport(
        childId: String
    ) async -> (profile: PhonemeProfile, forecasts: [MasteryForecast])? {
        do {
            let profile = try await phonemeProfileService.profile(childId: childId)
            guard !profile.cells.isEmpty else {
                // Пустой паспорт — валидное состояние (ещё не было family-voice
                // занятий). Возвращаем его, чтобы показать дружелюбный empty-state.
                return (profile, [])
            }
            var forecasts: [MasteryForecast] = []
            for problem in profile.topProblems {
                if let forecast = try? await phonemeProfileService.predict(
                    childId: childId, phoneme: problem.phoneme
                ) {
                    forecasts.append(forecast)
                }
            }
            return (profile, forecasts)
        } catch {
            logger.error("passport load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Test hooks

    // swiftlint:disable identifier_name
    func _lastRows() -> [PhonemeReportRow] { lastRows }
    func _lastProfile() -> PhonemeProfile? { lastProfile }
    // swiftlint:enable identifier_name
}
