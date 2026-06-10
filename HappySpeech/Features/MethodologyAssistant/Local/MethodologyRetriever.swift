import Foundation
import NaturalLanguage

// MARK: - ScoredChunk

/// Чанк корпуса с оценкой релевантности запросу.
struct ScoredChunk: Sendable, Equatable {
    let chunk: MethodologyChunk
    let score: Double
}

// MARK: - MethodologyRetriever

/// Локальный поиск по методическому корпусу методом **Okapi BM25**.
///
/// Полностью офлайн, on-device, $0. Токенизирует русский текст через
/// `NLTokenizer`, строит инвертированный индекс по чанкам и ранжирует их
/// по релевантности запросу. Робастно к отсутствию интернета и облака.
///
/// BM25 выбран вместо словарных эмбеддингов: не зависит от наличия
/// `NLEmbedding.wordEmbedding(for: .russian)` (которая доступна не на всех
/// сборках), детерминирован и проверяем юнит-тестами.
struct MethodologyRetriever: Sendable {

    // MARK: - BM25 parameters

    /// Классические значения Okapi BM25.
    private static let k1 = 1.5
    private static let b = 0.75

    // MARK: - Index

    private let chunks: [MethodologyChunk]
    /// Токены каждого чанка (после нормализации).
    private let docTokens: [[String]]
    /// Частоты терминов в каждом чанке.
    private let termFreqs: [[String: Int]]
    /// document frequency: в скольких чанках встречается термин.
    private let docFreq: [String: Int]
    /// Длина каждого чанка в токенах.
    private let docLengths: [Int]
    /// Средняя длина чанка.
    private let avgDocLength: Double

    // MARK: - Init

    init(chunks: [MethodologyChunk]) {
        self.chunks = chunks

        var tokens: [[String]] = []
        var freqs: [[String: Int]] = []
        var df: [String: Int] = [:]
        var lengths: [Int] = []
        tokens.reserveCapacity(chunks.count)

        for chunk in chunks {
            let toks = Self.tokenize(chunk.text)
            tokens.append(toks)
            lengths.append(toks.count)

            var tf: [String: Int] = [:]
            for token in toks {
                tf[token, default: 0] += 1
            }
            freqs.append(tf)
            for term in tf.keys {
                df[term, default: 0] += 1
            }
        }

        self.docTokens = tokens
        self.termFreqs = freqs
        self.docFreq = df
        self.docLengths = lengths
        let total = lengths.reduce(0, +)
        self.avgDocLength = chunks.isEmpty ? 0 : Double(total) / Double(chunks.count)
    }

    // MARK: - Search

    /// Возвращает топ-`limit` чанков, отсортированных по убыванию релевантности.
    /// Чанки с нулевой оценкой (нет совпадений) отбрасываются.
    func search(_ query: String, limit: Int) -> [ScoredChunk] {
        guard !chunks.isEmpty, limit > 0 else { return [] }
        let queryTerms = Self.tokenize(query)
        guard !queryTerms.isEmpty else { return [] }

        let n = Double(chunks.count)
        var scored: [ScoredChunk] = []
        scored.reserveCapacity(chunks.count)

        // Уникальные термины запроса (BM25 суммирует по уникальным термам).
        let uniqueQueryTerms = Set(queryTerms)

        for index in chunks.indices {
            let tf = termFreqs[index]
            let docLen = Double(docLengths[index])
            var score = 0.0

            for term in uniqueQueryTerms {
                guard let freq = tf[term], freq > 0 else { continue }
                let nq = Double(docFreq[term] ?? 0)
                // IDF Okapi BM25 (с +1 чтобы избежать отрицательных значений).
                let idf = log(1.0 + (n - nq + 0.5) / (nq + 0.5))
                let f = Double(freq)
                let denom = f + Self.k1 * (1.0 - Self.b + Self.b * docLen / max(avgDocLength, 1.0))
                score += idf * (f * (Self.k1 + 1.0)) / max(denom, .leastNonzeroMagnitude)
            }

            if score > 0 {
                scored.append(ScoredChunk(chunk: chunks[index], score: score))
            }
        }

        scored.sort { lhs, rhs in
            if lhs.score == rhs.score { return lhs.chunk.id < rhs.chunk.id }
            return lhs.score > rhs.score
        }
        return Array(scored.prefix(limit))
    }

    // MARK: - Tokenization

    /// Нормализованные токены русского текста: lowercase, без пунктуации и
    /// стоп-слов, длиной ≥ 2 символов.
    static func tokenize(_ text: String) -> [String] {
        let lowered = text.lowercased(with: Locale(identifier: "ru_RU"))
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = lowered
        var result: [String] = []
        tokenizer.enumerateTokens(in: lowered.startIndex..<lowered.endIndex) { range, _ in
            let token = String(lowered[range])
            let trimmed = token.trimmingCharacters(in: .punctuationCharacters)
            if trimmed.count >= 2, !stopWords.contains(trimmed),
               trimmed.rangeOfCharacter(from: .letters) != nil {
                result.append(trimmed)
            }
            return true
        }
        return result
    }

    /// Частотные русские служебные слова, не несущие смысла для поиска.
    private static let stopWords: Set<String> = [
        "и", "в", "во", "не", "что", "он", "на", "я", "с", "со", "как", "а",
        "то", "все", "она", "так", "его", "но", "да", "ты", "к", "у", "же",
        "вы", "за", "бы", "по", "только", "ее", "мне", "было", "вот", "от",
        "меня", "еще", "нет", "о", "из", "ему", "теперь", "когда", "даже",
        "ну", "вдруг", "ли", "если", "уже", "или", "ни", "быть", "был", "него",
        "до", "вас", "нибудь", "опять", "уж", "вам", "ведь", "там", "потом",
        "себя", "ничего", "ей", "может", "они", "тут", "где", "есть", "надо",
        "ней", "для", "мы", "тебя", "их", "чем", "была", "сам", "чтоб", "без",
        "будто", "чего", "раз", "тоже", "себе", "под", "будет", "ж", "тогда",
        "кто", "этот", "того", "потому", "этого", "какой", "совсем", "ним",
        "здесь", "этом", "один", "почти", "мой", "тем", "чтобы", "нее", "были",
        "куда", "зачем", "всех", "никогда", "можно", "при", "наконец", "два",
        "об", "другой", "хоть", "после", "над", "больше", "тот", "через", "эти",
        "нас", "про", "всего", "них", "какая", "много", "разве", "три", "эту",
        "моя", "впрочем", "хорошо", "свою", "этой", "перед", "иногда", "лучше",
        "чуть", "том", "нельзя", "такой", "им", "более", "всегда", "конечно",
        "всю", "между"
    ]
}
