import Foundation

// MARK: - MethodologyAssistant Models (Clean Swift VIP)

/// Namespace для Request / Response / ViewModel типов помощника по методике.
///
/// Помощник доступен только во взрослых контурах (родитель / специалист)
/// за parental gate. Принимает текстовый методический вопрос и показывает
/// markdown-ответ + источники из локального методического корпуса (офлайн).
enum MethodologyAssistant {

    // MARK: - Request

    enum Request {
        /// Задать вопрос. `sessionId` непустой → уточняющий (follow-up) вопрос.
        struct Ask: Sendable {
            let question: String
            let sessionId: String?

            init(question: String, sessionId: String? = nil) {
                self.question = question
                self.sessionId = sessionId
            }
        }

        /// Очистить диалог (новая сессия).
        struct Reset: Sendable {
            init() {}
        }
    }

    // MARK: - Response

    enum Response {
        struct Loading: Sendable {
            let pendingQuestion: String
        }

        struct Answered: Sendable {
            let answer: MethodologyAnswer
            let askedQuestion: String
        }

        struct Failed: Sendable {
            let message: String
            let askedQuestion: String
        }

        struct Cleared: Sendable {
            init() {}
        }
    }

    // MARK: - ViewModel

    /// Одна реплика в диалоге — вопрос взрослого или ответ помощника.
    struct Turn: Identifiable, Sendable, Equatable {
        enum Kind: Sendable, Equatable {
            case question
            case answer
        }

        let id: UUID
        let kind: Kind
        /// Текст вопроса или markdown-ответ.
        let text: String
        /// Источники (только для ответа).
        let citations: [MethodologyCitation]

        init(
            id: UUID = UUID(),
            kind: Kind,
            text: String,
            citations: [MethodologyCitation] = []
        ) {
            self.id = id
            self.kind = kind
            self.text = text
            self.citations = citations
        }
    }

    /// ViewModel экрана. Полностью описывает состояние UI.
    struct ViewModel: Sendable, Equatable {
        /// Лента реплик (вопрос → ответ → вопрос → …).
        var turns: [Turn]
        /// Идёт запрос к серверу.
        var isLoading: Bool
        /// Сообщение об ошибке (русское, user-facing). nil — нет ошибки.
        var errorMessage: String?
        /// Подсказки-примеры вопросов для пустого состояния.
        var suggestions: [String]
        /// Можно ли отправить запрос (есть текст и не идёт загрузка).
        var canSend: Bool

        init(
            turns: [Turn] = [],
            isLoading: Bool = false,
            errorMessage: String? = nil,
            suggestions: [String] = [],
            canSend: Bool = false
        ) {
            self.turns = turns
            self.isLoading = isLoading
            self.errorMessage = errorMessage
            self.suggestions = suggestions
            self.canSend = canSend
        }

        /// Стартовый ViewModel с примерами вопросов.
        static var initial: ViewModel {
            ViewModel(
                suggestions: [
                    String(localized: "methodologyAssistant.suggestion.1"),
                    String(localized: "methodologyAssistant.suggestion.2"),
                    String(localized: "methodologyAssistant.suggestion.3")
                ]
            )
        }
    }
}
