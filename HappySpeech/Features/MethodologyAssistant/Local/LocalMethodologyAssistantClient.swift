import Foundation
import OSLog

// MARK: - LocalMethodologyAssistantClient

/// Локальный, офлайн, бесплатный помощник по методике логопедии.
///
/// Заменяет платный облачный путь (Cloud Function `askMethodologyAssistant` →
/// Vertex AI Search / Discovery Engine). Полностью on-device:
/// 1. Забандленный методический корпус (`methodology_corpus.json`, 13 документов).
/// 2. Поиск релевантных фрагментов методом BM25 (``MethodologyRetriever``).
/// 3. Сборка связного русского markdown-ответа из топ-фрагментов + честные
///    источники (документ + раздел).
///
/// Никаких сетевых вызовов и затрат: $0, работает офлайн. Сохраняет тот же
/// контракт ``MethodologyAssistantClientProtocol``, что и старый облачный
/// клиент, поэтому UI карточки ассистента не меняется.
///
/// > Important: COPPA — только текстовые методические вопросы взрослого
/// > (родитель / специалист) за parental gate. Никакого детского аудио / PII.
public final class LocalMethodologyAssistantClient: MethodologyAssistantClientProtocol,
                                                    @unchecked Sendable {

    // MARK: - Errors

    /// Локализованная ошибка локального ассистента (русский, user-facing).
    public enum LocalError: LocalizedError, Sendable, Equatable {
        /// Корпус не удалось загрузить из bundle.
        case corpusUnavailable
        /// Вопрос слишком короткий / длинный.
        case invalidQuestion(String)
        /// По запросу не нашлось релевантных фрагментов.
        case noRelevantContent

        public var errorDescription: String? {
            switch self {
            case .corpusUnavailable:
                return "Методическая база недоступна. Переустановите приложение."
            case .invalidQuestion(let detail):
                return detail
            case .noRelevantContent:
                return "По этому вопросу в методической базе ничего не найдено. "
                    + "Попробуйте переформулировать или задать более конкретный вопрос."
            }
        }
    }

    // MARK: - Config

    /// Совпадает с прежним серверным `MAX_QUESTION_LENGTH`.
    private static let maxQuestionLength = 600
    private static let minQuestionLength = 3
    /// Сколько фрагментов корпуса включать в ответ.
    private static let topK = 4

    // MARK: - State

    public let region: String = "local"

    private let chunks: [MethodologyChunk]
    private let retriever: MethodologyRetriever

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MethodologyAssistant.Local"
    )

    // MARK: - Init

    /// - Parameter bundle: bundle с `methodology_corpus.json` (по умолчанию `.main`).
    public init(bundle: Bundle = .main) {
        let loaded = MethodologyCorpus.chunks(bundle: bundle)
        self.chunks = loaded
        self.retriever = MethodologyRetriever(chunks: loaded)
    }

    /// Тестовый init с явным корпусом (без bundle).
    init(chunks: [MethodologyChunk]) {
        self.chunks = chunks
        self.retriever = MethodologyRetriever(chunks: chunks)
    }

    // MARK: - Ask

    public func ask(question: String, sessionId: String?) async throws -> MethodologyAnswer {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minQuestionLength else {
            throw LocalError.invalidQuestion("Вопрос слишком короткий.")
        }
        guard trimmed.count <= Self.maxQuestionLength else {
            throw LocalError.invalidQuestion("Вопрос слишком длинный.")
        }
        guard !chunks.isEmpty else {
            throw LocalError.corpusUnavailable
        }

        let hits = retriever.search(trimmed, limit: Self.topK)
        guard !hits.isEmpty else {
            throw LocalError.noRelevantContent
        }

        logger.info("local methodology answer built, hits=\(hits.count, privacy: .public)")
        return Self.composeAnswer(from: hits)
    }

    // MARK: - Answer composition

    /// Собирает markdown-ответ из найденных фрагментов + дедуплицированные
    /// источники. Без фабрикации — текст берётся прямо из корпуса.
    static func composeAnswer(from hits: [ScoredChunk]) -> MethodologyAnswer {
        var paragraphs: [String] = []
        var citations: [MethodologyCitation] = []
        var seenSources = Set<String>()

        for hit in hits {
            let body = hit.chunk.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            // Заголовок раздела перед фрагментом (если есть) — для читаемости.
            if hit.chunk.section.isEmpty {
                paragraphs.append(body)
            } else {
                paragraphs.append("**\(hit.chunk.section)**\n\n\(body)")
            }

            if !seenSources.contains(hit.chunk.source) {
                seenSources.insert(hit.chunk.source)
                citations.append(
                    MethodologyCitation(
                        title: hit.chunk.citationTitle,
                        source: hit.chunk.source
                    )
                )
            }
        }

        let answer = paragraphs.joined(separator: "\n\n---\n\n")
        return MethodologyAnswer(
            answer: answer,
            citations: citations,
            sessionId: nil
        )
    }
}
