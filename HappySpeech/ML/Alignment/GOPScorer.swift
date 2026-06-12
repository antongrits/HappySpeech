import Foundation

// MARK: - PhonemeGOP

/// Результат GOP-скоринга одной фонемы из forced alignment.
///
/// GOP (Goodness of Pronunciation) — разность между логарифмической
/// вероятностью целевой фонемы и наилучшей конкурирующей фонемой,
/// усреднённая по всем кадрам спана.
///
/// ## Честные границы
/// Абсолютные значения GOP смещены из-за обучения на синтетическом датасете.
/// Для диагностики следует использовать относительные метрики:
/// - межфонемное сравнение внутри одного ребёнка;
/// - динамику GOP по сессиям (тренд);
/// - калибровку по первым 20 наблюдениям ребёнка (self-baseline).
/// Не интерпретировать как абсолютную оценку качества произношения.
public struct PhonemeGOP: Sendable, Equatable {
    /// Канонический IPA-символ оцениваемой фонемы.
    ///
    /// Значение получено через ``AlignmentVocabMap/canonicalIPA(forVocabId:)``
    /// и соответствует ключам ``ChildSpeechScoringPolicy/developmentalSubstitutions``
    /// и ``IPADictionary/info(for:)``. Например: "r", "ʂ", "l", "tɕ".
    public let phoneme: String
    /// Временной спан, по которому рассчитан GOP.
    public let span: PhonemeSpan
    /// GOP = mean_{t∈span}(logP(p) − max_{q≠p,blank} logP(q)).
    /// Положительный → фонема уверенно правильная; отрицательный → конкурент сильнее.
    public let gop: Float
    /// Геометрическое среднее апостериорной вероятности целевой фонемы по спану:
    /// exp(mean_{t∈span}(logP_t(p))). Эквивалентно exp(avgLogP), то есть
    /// геометрическому (а не арифметическому) среднему вероятностей.
    public let avgPosterior: Float
    /// Vocab-id конкурирующей фонемы (argmax по спану среди q≠p,blank).
    /// nil если спан пустой или конкурент не определён.
    public let competitorId: Int?
    /// Канонический IPA-символ конкурирующей фонемы.
    ///
    /// Получен через ``AlignmentVocabMap/canonicalIPA(forVocabId:)`` —
    /// совместим с ключами ``ChildSpeechScoringPolicy/developmentalSubstitutions``.
    /// nil если конкурент не определён или vocab-id не имеет IPA-аналога.
    public let competitorIPA: String?
    /// Геометрическое среднее апостериорной вероятности конкурирующей фонемы по спану:
    /// exp(mean_{t∈span}(logP_t(bestCompetitor))). Аналог avgPosterior для победителя.
    ///
    /// Используется классификатором для различения «замена с уверенным конкурентом»
    /// (competitorPosterior высокий) и «диффузный спан» (оба постериора низкие → uncertain).
    /// nil если конкурент не определён.
    public let competitorPosterior: Float?

    public init(
        phoneme: String,
        span: PhonemeSpan,
        gop: Float,
        avgPosterior: Float,
        competitorId: Int?,
        competitorIPA: String?,
        competitorPosterior: Float? = nil
    ) {
        self.phoneme = phoneme
        self.span = span
        self.gop = gop
        self.avgPosterior = avgPosterior
        self.competitorId = competitorId
        self.competitorIPA = competitorIPA
        self.competitorPosterior = competitorPosterior
    }
}

// MARK: - GOPScorer

/// Вычислитель GOP (Goodness of Pronunciation) по пофонемным спанам.
///
/// Формула GOP для фонемы p на спане [s, e]:
/// ```
/// GOP_p = (1/(e-s+1)) × Σ_{t=s..e} (logP_t(p) − max_{q≠p,blank}(logP_t(q)))
/// ```
/// где `logP_t(q)` — log-softmax вероятность класса q в кадре t.
///
/// Дополнительно вычисляется:
/// - `avgPosterior` = exp(mean(logP_t(p))) по спану;
/// - `competitorId` = argmax по span из (sum logP_t(q)) для q≠p,blank.
///
/// ## Входные данные
/// - `logProbs`: матрица T×C лог-вероятностей (уже log-softmax). Для сырых
///   логитов — передать через ``CTCForcedAligner/applyLogSoftmax(_:vocabSize:)``.
/// - `spans`: результат ``CTCForcedAligner/align(logProbs:refIds:)``.
///
/// ## Сложность
/// O(L × D × C) где L — число фонем, D — средняя длина спана, C = 37.
public enum GOPScorer {

    // MARK: - Public API

    /// Вычисляет GOP для каждого спана.
    ///
    /// Поле ``PhonemeGOP/phoneme`` и ``PhonemeGOP/competitorIPA`` заполняются
    /// каноническим IPA через ``AlignmentVocabMap/canonicalIPA(forVocabId:)``,
    /// что обеспечивает совместимость с ``ChildSpeechScoringPolicy`` и ``IPADictionary``.
    ///
    /// - Parameters:
    ///   - logProbs: матрица T×C лог-вероятностей после log-softmax.
    ///   - spans: спаны из ``CTCForcedAligner/align(logProbs:refIds:)``.
    ///     Поле ``PhonemeSpan/phoneme`` — кириллица из ``Wav2Vec2Vocabulary``.
    /// - Returns: массив ``PhonemeGOP`` в том же порядке, что и `spans`.
    public static func score(logProbs: [[Float]], spans: [PhonemeSpan]) -> [PhonemeGOP] {
        let timeSteps = logProbs.count
        let vocabSize = logProbs.first?.count ?? Wav2Vec2Vocabulary.size
        let blankId = Wav2Vec2Vocabulary.blankIndex

        return spans.map { span in
            // P1-A: vocab-id целевой фонемы.
            // Если span.phoneme не найден в словаре (например "<unk>") — вернуть
            // uncertain-результат с нулевым GOP, чтобы классификатор дал .uncertain
            // по правилу minPosterior (avgPosterior=0).
            guard let targetId = Wav2Vec2Vocabulary.index(of: span.phoneme) else {
                return PhonemeGOP(
                    phoneme: span.phoneme,
                    span: span,
                    gop: 0,
                    avgPosterior: 0,
                    competitorId: nil,
                    competitorIPA: nil
                )
            }

            // Канонический IPA целевой фонемы.
            // Если маппинг отсутствует (напр. ъ/ь) — тоже uncertain-путь.
            guard let targetIPA = AlignmentVocabMap.canonicalIPA(forVocabId: targetId) else {
                return PhonemeGOP(
                    phoneme: span.phoneme,
                    span: span,
                    gop: 0,
                    avgPosterior: 0,
                    competitorId: nil,
                    competitorIPA: nil
                )
            }

            // Кадры внутри спана (clamp к [0, T))
            let startFrame = max(0, span.startFrame)
            let endFrame = min(span.endFrame, timeSteps - 1)

            guard startFrame <= endFrame else {
                return PhonemeGOP(
                    phoneme: targetIPA,
                    span: span,
                    gop: 0,
                    avgPosterior: 0,
                    competitorId: nil,
                    competitorIPA: nil
                )
            }

            var gopAccum: Float = 0
            var targetLogPAccum: Float = 0
            var competitorAccum = [Float](repeating: 0, count: vocabSize)
            let frameCount = endFrame - startFrame + 1

            for t in startFrame ... endFrame {
                let row = logProbs[t]
                let targetLogP = row.indices.contains(targetId) ? row[targetId] : -Float.infinity

                // Конкурент: max по rival≠target и rival≠blank
                var competitorMax: Float = -Float.infinity
                for rival in 0 ..< min(row.count, vocabSize) {
                    guard rival != targetId, rival != blankId else { continue }
                    let v = row[rival]
                    if v > competitorMax { competitorMax = v }
                    competitorAccum[rival] += v
                }

                // P1-B: если среди конкурентов нет ни одного (все -inf),
                // GOP-вклад кадра = 0 (нейтрально), а не +inf.
                let effectiveCompetitorMax = competitorMax == -Float.infinity
                    ? targetLogP
                    : competitorMax

                gopAccum += targetLogP - effectiveCompetitorMax
                targetLogPAccum += targetLogP
            }

            let gopMean = gopAccum / Float(frameCount)
            let avgLogP = targetLogPAccum / Float(frameCount)
            let avgPost = expf(avgLogP)

            // Конкурент: argmax по сумме log-вероятностей по спану
            var bestCompetitorId: Int?
            var bestCompetitorSum: Float = -Float.infinity
            for rival in 0 ..< vocabSize {
                guard rival != targetId, rival != blankId else { continue }
                let sumV = competitorAccum[rival]
                if sumV > bestCompetitorSum {
                    bestCompetitorSum = sumV
                    bestCompetitorId = rival
                }
            }

            // Канонический IPA конкурента (не кириллица из словаря).
            let competitorIPA = bestCompetitorId.flatMap {
                AlignmentVocabMap.canonicalIPA(forVocabId: $0)
            }

            // Геометрическое среднее постериора конкурента по спану.
            // Нужно для классификатора: замена = конкурент УВЕРЕН (высокий posterior),
            // uncertain = оба постериора низкие (диффузный / тихий спан).
            let competitorPost: Float?
            if let cid = bestCompetitorId {
                let cAvgLogP = competitorAccum[cid] / Float(frameCount)
                let cPost = expf(cAvgLogP)
                competitorPost = max(0, min(1, cPost))
            } else {
                competitorPost = nil
            }

            return PhonemeGOP(
                phoneme: targetIPA,
                span: span,
                gop: gopMean,
                avgPosterior: max(0, min(1, avgPost)),
                competitorId: bestCompetitorId,
                competitorIPA: competitorIPA,
                competitorPosterior: competitorPost
            )
        }
    }
}
