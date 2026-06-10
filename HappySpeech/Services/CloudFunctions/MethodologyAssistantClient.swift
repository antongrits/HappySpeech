import Foundation

// MARK: - Models

/// Источник, на который опирался ответ помощника по методике.
///
/// Соответствует документу забандленного методического корпуса
/// (`methodology_corpus.json`, например `therapy-stages.md`).
public struct MethodologyCitation: Sendable, Equatable, Identifiable {
    /// Человекочитаемый заголовок документа (для отображения).
    public let title: String
    /// Имя исходного файла корпуса (например, `therapy-stages.md`).
    public let source: String

    public var id: String { source }

    public init(title: String, source: String) {
        self.title = title
        self.source = source
    }
}

/// Ответ помощника по методике: текст + источники + id сессии для уточнений.
public struct MethodologyAnswer: Sendable, Equatable {
    /// Сгенерированный ответ (русский markdown).
    public let answer: String
    /// Источники из корпуса, на которые опирался ответ.
    public let citations: [MethodologyCitation]
    /// Непрозрачный id сессии — передать обратно для follow-up вопроса.
    public let sessionId: String?

    public init(answer: String, citations: [MethodologyCitation], sessionId: String?) {
        self.answer = answer
        self.citations = citations
        self.sessionId = sessionId
    }
}

// MARK: - Protocol

/// Помощник по методике логопедии для **взрослых контуров** (родитель /
/// специалист), доступен только за parental gate.
///
/// Принимает текстовый вопрос взрослого и возвращает обоснованный ответ со
/// ссылками на методический корпус. Реализация —
/// ``LocalMethodologyAssistantClient`` (офлайн BM25-поиск по забандленному
/// корпусу, $0). Прежний облачный путь (Vertex AI Search) убран.
///
/// > Important: COPPA — НИКАКОГО детского аудио или PII. Только текстовые
/// > методические вопросы взрослого. Показывать исключительно в
/// > родительском / специалистском разделе за подтверждением «взрослый».
public protocol MethodologyAssistantClientProtocol: CloudFunctionsClient {
    /// Задаёт вопрос помощнику по методике.
    ///
    /// - Parameters:
    ///   - question: Текстовый вопрос взрослого (3…600 символов).
    ///   - sessionId: Опциональный id предыдущей сессии для уточняющего вопроса.
    /// - Returns: ``MethodologyAnswer``.
    /// - Throws: ``CloudFunctionsClientError``.
    func ask(question: String, sessionId: String?) async throws -> MethodologyAnswer
}

public extension MethodologyAssistantClientProtocol {
    /// Удобный вызов без сессии (новый вопрос).
    func ask(question: String) async throws -> MethodologyAnswer {
        try await ask(question: question, sessionId: nil)
    }
}

// MARK: - Mock

public final class MockMethodologyAssistantClient: MethodologyAssistantClientProtocol,
                                                   @unchecked Sendable {

    public let region: String = CloudFunctionsRegion.default
    public var stubbedAnswer: MethodologyAnswer
    public var shouldThrowError: Bool = false

    public init() {
        self.stubbedAnswer = MethodologyAnswer(
            answer: """
            Звук Р ставится последним, после Л и Ль. Начните с артикуляционной \
            подготовки («Лошадка», «Грибок», «Барабанщик»), затем вызывайте \
            вибрацию от быстрого Д-Д-Д. Автоматизируйте по этапам: слог → слово \
            (по позициям) → фраза.
            """,
            citations: [
                MethodologyCitation(
                    title: "Этапы логопедической работы",
                    source: "therapy-stages.md"
                ),
                MethodologyCitation(
                    title: "Таксономия групп звуков",
                    source: "sound-groups-taxonomy.md"
                )
            ],
            sessionId: "mock-session-0001"
        )
    }

    public func ask(question: String, sessionId: String?) async throws -> MethodologyAnswer {
        if shouldThrowError {
            throw CloudFunctionsClientError.serverError("Mock error")
        }
        return stubbedAnswer
    }
}
