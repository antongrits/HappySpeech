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
    private let logger = Logger(subsystem: "ru.happyspeech", category: "PhonemeReport")

    // MARK: - State

    private var lastRows: [PhonemeReportRow] = []

    // MARK: - Init

    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
    }

    // MARK: - Load

    func load(_ request: PhonemeReportModels.Load.Request) async {
        do {
            async let profileTask = childRepository.fetch(id: request.childId)
            async let sessionsTask = sessionRepository.fetchAll(childId: request.childId)
            let (profile, sessions) = try await (profileTask, sessionsTask)

            lastRows = PhonemeReportAggregator.buildRows(
                targetSounds: profile.targetSounds,
                sessions: sessions
            )

            presenter?.presentLoad(.init(
                childName: profile.name,
                targetSounds: profile.targetSounds,
                sessions: sessions
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

    // MARK: - Test hooks

    // swiftlint:disable identifier_name
    func _lastRows() -> [PhonemeReportRow] { lastRows }
    // swiftlint:enable identifier_name
}
