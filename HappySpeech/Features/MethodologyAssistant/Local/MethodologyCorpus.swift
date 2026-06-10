import Foundation
import OSLog

// MARK: - MethodologyChunk

/// Один смысловой фрагмент методического корпуса (раздел документа).
///
/// Корпус собирается офлайн из 13 методических документов и забандлен в
/// приложение как `methodology_corpus.json`. Каждый чанк сохраняет путь до
/// раздела, чтобы локальный ответчик мог честно сослаться на источник.
struct MethodologyChunk: Decodable, Sendable, Equatable {
    /// Стабильный id чанка (`chunk-0042`).
    let id: String
    /// Имя исходного файла корпуса (`therapy-stages.md`).
    let source: String
    /// Человекочитаемый заголовок документа (для цитаты).
    let docTitle: String
    /// Путь до раздела внутри документа (`Этап 1 › Постановка`). Может быть пустым.
    let section: String
    /// Текст фрагмента (русский, markdown-подобный).
    let text: String

    /// Заголовок для цитаты: документ + раздел (если есть).
    var citationTitle: String {
        section.isEmpty ? docTitle : "\(docTitle) — \(section)"
    }
}

// MARK: - MethodologyCorpus

/// Загрузчик забандленного методического корпуса.
///
/// Полностью офлайн / on-device: читает `methodology_corpus.json` из bundle,
/// декодирует и кэширует чанки. Никаких сетевых вызовов, $0.
enum MethodologyCorpus {

    /// Все чанки корпуса (загружаются один раз, кэшируются).
    static func chunks(bundle: Bundle = .main) -> [MethodologyChunk] {
        loadOnce(bundle: bundle)
    }

    // MARK: - Private

    private struct CorpusFile: Decodable {
        let version: Int
        let chunks: [MethodologyChunk]
    }

    private nonisolated(unsafe) static var cached: [MethodologyChunk] = []
    private nonisolated(unsafe) static var didLoad = false
    private static let lock = NSLock()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MethodologyAssistant.Corpus"
    )

    private static func loadOnce(bundle: Bundle) -> [MethodologyChunk] {
        lock.lock()
        defer { lock.unlock() }
        if didLoad { return cached }
        didLoad = true
        cached = decode(bundle: bundle)
        logger.info("methodology corpus loaded: \(cached.count, privacy: .public) chunks")
        return cached
    }

    private static func decode(bundle: Bundle) -> [MethodologyChunk] {
        guard
            let url = bundle.url(forResource: "methodology_corpus", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            logger.warning("methodology_corpus.json не найден в bundle — корпус пуст")
            return []
        }
        do {
            return try JSONDecoder().decode(CorpusFile.self, from: data).chunks
        } catch {
            logger.error("методический корпус не декодирован: \(error.localizedDescription)")
            return []
        }
    }
}
