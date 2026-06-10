import Foundation
import OSLog

// MARK: - MethodologyAssistantBusinessLogic

@MainActor
protocol MethodologyAssistantBusinessLogic: AnyObject {
    /// Задаёт вопрос помощнику. Поддерживает follow-up через сохранённый sessionId.
    func ask(_ request: MethodologyAssistant.Request.Ask)
    /// Очищает диалог (начать заново).
    func reset(_ request: MethodologyAssistant.Request.Reset)
}

// MARK: - MethodologyAssistantInteractor

/// Бизнес-логика помощника по методике логопедии.
///
/// Ответственности:
/// - Валидация вопроса (3…600 символов) перед вызовом ответчика.
/// - Вызов ``MethodologyAssistantClientProtocol/ask(question:sessionId:)``
///   (локальный офлайн-поиск по корпусу).
/// - Хранение `sessionId` для уточняющих вопросов, если ответчик его вернёт.
/// - Маппинг ошибок в user-facing русские сообщения через presenter.
///
/// Контур: только parent / specialist за parental gate (COPPA). Этот
/// интерактор НИКОГДА не вызывается из детского контекста.
@MainActor
final class MethodologyAssistantInteractor: MethodologyAssistantBusinessLogic {

    // MARK: - VIP

    var presenter: MethodologyAssistantPresentationLogic?

    // MARK: - Dependencies

    private let client: any MethodologyAssistantClientProtocol

    // MARK: - Session state

    /// Сохранённый id сессии для follow-up. Обновляется после каждого ответа.
    private var sessionId: String?

    /// Текущий in-flight запрос — отменяется при reset / новом запросе.
    private var askTask: Task<Void, Never>?

    private static let minLength = 3
    private static let maxLength = 600

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MethodologyAssistant.Interactor"
    )

    // MARK: - Init

    init(client: any MethodologyAssistantClientProtocol) {
        self.client = client
    }

    // MARK: - Ask

    func ask(_ request: MethodologyAssistant.Request.Ask) {
        let trimmed = request.question.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= Self.minLength else {
            presenter?.presentFailure(
                .init(
                    message: String(localized: "methodologyAssistant.error.tooShort"),
                    askedQuestion: trimmed
                )
            )
            return
        }
        guard trimmed.count <= Self.maxLength else {
            presenter?.presentFailure(
                .init(
                    message: String(localized: "methodologyAssistant.error.tooLong"),
                    askedQuestion: trimmed
                )
            )
            return
        }

        // Explicit sessionId из request имеет приоритет над сохранённым (follow-up).
        let effectiveSession = request.sessionId ?? sessionId

        presenter?.presentLoading(.init(pendingQuestion: trimmed))

        askTask?.cancel()
        askTask = Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await self.client.ask(
                    question: trimmed,
                    sessionId: effectiveSession
                )
                guard !Task.isCancelled else { return }
                // Запоминаем session для follow-up.
                if let newSession = answer.sessionId, !newSession.isEmpty {
                    self.sessionId = newSession
                }
                self.logger.info(
                    "methodology answer received, citations=\(answer.citations.count, privacy: .public)"
                )
                self.presenter?.presentAnswer(
                    .init(answer: answer, askedQuestion: trimmed)
                )
            } catch is CancellationError {
                // Отменён — ничего не показываем.
            } catch {
                guard !Task.isCancelled else { return }
                // Не логируем текст вопроса (PII-free), только факт ошибки.
                self.logger.error("methodology ask failed: \(error.localizedDescription)")
                let message = (error as? LocalizedError)?.errorDescription
                    ?? String(localized: "methodologyAssistant.error.generic")
                self.presenter?.presentFailure(
                    .init(message: message, askedQuestion: trimmed)
                )
            }
        }
    }

    // MARK: - Reset

    func reset(_ request: MethodologyAssistant.Request.Reset) {
        askTask?.cancel()
        askTask = nil
        sessionId = nil
        presenter?.presentCleared(.init())
        logger.info("methodology dialog reset")
    }
}
