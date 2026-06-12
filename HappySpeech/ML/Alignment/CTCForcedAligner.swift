import Accelerate
import Foundation

// MARK: - PhonemeSpan

/// Временной интервал одной фонемы после CTC forced alignment.
///
/// Индексы фреймов соответствуют оси T выхода Wav2Vec2RuChild ([1, 149, 37]).
/// Каждый кадр T ≈ 20 мс (48000 сэмплов / 49 stride ≈ 6.5 мс hop, round-trip ~20 мс
/// в Wav2Vec2 conv-стеке) — ориентировочно; точная длительность зависит от модели.
///
/// ## Честные границы
/// Модель Wav2Vec2RuChild обучена на синтетическом датасете и не валидировалась
/// на реальной детской речи. Границы спанов — относительные, пригодны для
/// GOP-скоринга и сравнения внутри одного ребёнка (внутрисубъектный дизайн).
/// Не использовать как клинический инструмент диагностики речи.
public struct PhonemeSpan: Sendable, Equatable {
    /// Кириллический символ из ``Wav2Vec2Vocabulary`` (НЕ IPA).
    ///
    /// Значение совпадает с результатом `Wav2Vec2Vocabulary.symbol(at:)` —
    /// то есть это кириллическая буква словаря модели (например «р», «ш», «л»),
    /// а не IPA-символ. Для получения канонического IPA используйте
    /// ``AlignmentVocabMap/canonicalIPA(forVocabId:)``.
    public let phoneme: String
    /// 0-based индекс первого кадра (включительно), 0..<T.
    public let startFrame: Int
    /// 0-based индекс последнего кадра (включительно), startFrame..<T.
    public let endFrame: Int

    public init(phoneme: String, startFrame: Int, endFrame: Int) {
        self.phoneme = phoneme
        self.startFrame = startFrame
        self.endFrame = endFrame
    }

    /// Число кадров, покрытых спаном.
    public var frameCount: Int { max(0, endFrame - startFrame + 1) }
}

// MARK: - CTCForcedAligner

/// Витерби-алайнер для CTC forced alignment по blank-interleaved графу.
///
/// Реализует классический алгоритм CTC forced alignment (Graves 2006):
/// принимает логарифмические вероятности (log-softmax) и эталонную фонемную
/// последовательность, возвращает пофонемные временны́е интервалы (спаны).
///
/// ## Граф состояний (blank-interleaved)
/// Для L эталонных фонем создаётся граф из 2L+1 состояний:
/// ```
/// s=0      s=1      s=2      s=3   ...  s=2L
/// blank   ref[0]   blank   ref[1]  ...  ref[L-1]
/// ```
/// Разрешённые переходы из состояния s в кадре t:
/// - stay:       s → s     (текущая фонема / blank)
/// - next:       s → s+1   (следующее состояние)
/// - skip-blank: s → s+2   (если s — blank, пропустить blank и перейти к следующей фонеме)
///
/// ## Сложность
/// O(T × (2L+1)) по времени, O(2L+1) по памяти (rolling-буфер).
///
/// ## Ограничения
/// - Минимальное число кадров: T ≥ 2L+1 (иначе алайнмент невозможен, возвращает nil).
/// - Поддерживаются фонемы, которые есть в ``Wav2Vec2Vocabulary`` (37 классов).
/// - IPA-фонемы, не имеющие сопоставления в vocab, помечаются как `unsupported`
///   через ``AlignmentVocabMap`` и вызывают ошибку ``CTCAlignerError/unsupportedPhoneme``.
///
/// ## Честные границы
/// Алайнмент работает корректно при условии, что модель «видела» эту фонему в
/// обучающих данных. На синтетическом датасете без реальной детской речи точность
/// границ спанов ниже, чем на валидированном корпусе. Используется для
/// относительных метрик (GOP), не как абсолютная временна́я разметка.
public enum CTCForcedAligner {

    // MARK: - Errors

    /// Ошибки принудительного выравнивания.
    public enum CTCAlignerError: LocalizedError, Sendable {
        /// Аудио слишком короткое: T < 2L+1 состояний.
        case tooFewFrames(frames: Int, required: Int)
        /// Эталонная последовательность пустая.
        case emptyReference
        /// Фонема не поддерживается словарём модели (нет vocab-id).
        case unsupportedPhoneme(String)

        public var errorDescription: String? {
            switch self {
            case .tooFewFrames(let f, let r):
                return String(localized: "Слишком мало CTC-кадров: \(f), нужно ≥ \(r)")
            case .emptyReference:
                return String(localized: "Пустая эталонная фонемная последовательность")
            case .unsupportedPhoneme(let ipa):
                return String(localized: "Фонема '\(ipa)' не поддерживается словарём модели")
            }
        }
    }

    // MARK: - Public API

    /// Выполняет CTC forced alignment и возвращает пофонемные спаны.
    ///
    /// - Parameters:
    ///   - logProbs: матрица T×C лог-вероятностей (результат log-softmax над сырыми
    ///     логитами). T = 149, C = 37 (``Wav2Vec2Vocabulary.size``). Если переданы
    ///     сырые логиты — передайте через ``CTCForcedAligner/applyLogSoftmax(_:vocabSize:)``.
    ///   - refIds: индексы эталонных фонем в словаре (vocab-id). Каждый элемент ∈ [0, 36].
    ///     Получаются через ``AlignmentVocabMap/vocabId(for:)``.
    /// - Returns: массив ``PhonemeSpan`` длиной `refIds.count` в порядке следования
    ///   фонем в эталоне.
    /// - Throws: ``CTCAlignerError`` если входные данные некорректны.
    public static func align(
        logProbs: [[Float]],
        refIds: [Int]
    ) throws -> [PhonemeSpan] {
        let timeSteps = logProbs.count
        let numPhonemes = refIds.count

        guard !refIds.isEmpty else {
            throw CTCAlignerError.emptyReference
        }

        let numStates = 2 * numPhonemes + 1
        let minFrames = numStates
        guard timeSteps >= minFrames else {
            throw CTCAlignerError.tooFewFrames(frames: timeSteps, required: minFrames)
        }

        let blankId = Wav2Vec2Vocabulary.blankIndex

        // MARK: Получение vocab из символов
        // Строим symbols для backtrace: нечётные состояния — ref-фонемы, чётные — blank.
        var stateSymbols = [Int](repeating: blankId, count: numStates)
        for i in 0 ..< numPhonemes {
            stateSymbols[2 * i + 1] = refIds[i]
        }

        // MARK: Витерби DP с rolling-буфером
        // Инициализируем первый кадр: допустимы только состояния 0 (blank) и 1 (первая фонема).
        let negInf: Float = -Float.infinity
        var prev = [Float](repeating: negInf, count: numStates)
        prev[0] = logProbs[0][blankId]
        prev[1] = logProbs[0][refIds[0]]

        // Матрица traceback: каждая ячейка хранит состояние-предка.
        var traceback = [[Int]](repeating: [Int](repeating: 0, count: numStates), count: timeSteps)
        // Первый кадр: каждое состояние само по себе (stay).
        for s in 0 ..< numStates { traceback[0][s] = s }

        var curr = [Float](repeating: negInf, count: numStates)

        for t in 1 ..< timeSteps {
            let logP = logProbs[t]

            for s in 0 ..< numStates {
                let emitId = stateSymbols[s]
                let emit = logP[emitId]

                // Переход stay: s → s
                var bestVal = prev[s]
                var bestPrev = s

                // Переход next: s-1 → s
                if s > 0 {
                    let val = prev[s - 1]
                    if val > bestVal {
                        bestVal = val
                        bestPrev = s - 1
                    }
                }

                // Переход skip-blank: s-2 → s
                // Только если s >= 2, текущее состояние s — нечётное (фонема),
                // и состояние s-1 — blank (чётное), а предыдущая фонема ≠ текущей фонеме.
                if s >= 2, s % 2 == 1 {
                    // s-2 — предыдущая фонема; s-1 — blank
                    let prevRefIdx = (s - 2) / 2 // индекс фонемы в refIds
                    let currRefIdx = (s) / 2      // = (s - 1 + 1) / 2 = s / 2
                    // skip-blank допустим только если pred-фонема ≠ curr-фонеме
                    if currRefIdx < numPhonemes,
                       prevRefIdx < numPhonemes,
                       refIds[prevRefIdx] != refIds[currRefIdx] {
                        let val = prev[s - 2]
                        if val > bestVal {
                            bestVal = val
                            bestPrev = s - 2
                        }
                    }
                }

                curr[s] = emit + bestVal
                traceback[t][s] = bestPrev
            }

            swap(&prev, &curr)
            curr.withUnsafeMutableBufferPointer { buf in
                for i in 0 ..< numStates { buf[i] = negInf }
            }
        }

        // MARK: Backtrace
        // Лучший финальный путь: конечное состояние — 2L или 2L-1 (согласно стандарту CTC).
        let lastState: Int
        let val2L = prev[numStates - 1]
        let val2L1 = numStates >= 2 ? prev[numStates - 2] : negInf
        lastState = (val2L >= val2L1) ? numStates - 1 : numStates - 2

        var statePath = [Int](repeating: 0, count: timeSteps)
        statePath[timeSteps - 1] = lastState
        for t in stride(from: timeSteps - 2, through: 0, by: -1) {
            statePath[t] = traceback[t + 1][statePath[t + 1]]
        }

        // MARK: Сборка спанов из пути
        return buildSpans(
            statePath: statePath,
            stateSymbols: stateSymbols,
            refIds: refIds
        )
    }

    // MARK: - Log-Softmax (Accelerate)

    /// Применяет log-softmax к строкам матрицы сырых логитов T×C.
    ///
    /// Использует Accelerate (vDSP) для численно устойчивого вычисления:
    /// log_softmax(x_i) = x_i − max(x) − log(Σ exp(x_j − max(x)))
    ///
    /// - Parameters:
    ///   - rawLogits: плоский массив T×C логитов (row-major, C чисел на кадр).
    ///   - vocabSize: размер словаря C (для Wav2Vec2RuChild = 37).
    /// - Returns: матрица T×C лог-вероятностей, каждая строка нормализована.
    public static func applyLogSoftmax(_ rawLogits: [[Float]], vocabSize: Int) -> [[Float]] {
        rawLogits.map { row in
            logSoftmaxRow(row, vocabSize: vocabSize)
        }
    }

    // MARK: - Private

    /// Log-softmax одной строки длиной C.
    private static func logSoftmaxRow(_ row: [Float], vocabSize: Int) -> [Float] {
        let count = min(row.count, vocabSize)
        guard count > 0 else { return row }

        var maxVal: Float = 0
        vDSP_maxv(row, 1, &maxVal, vDSP_Length(count))

        // Вычитаем max для численной устойчивости
        var shifted = [Float](repeating: 0, count: count)
        var negMax = -maxVal
        vDSP_vsadd(row, 1, &negMax, &shifted, 1, vDSP_Length(count))

        // exp(shifted)
        var expVals = [Float](repeating: 0, count: count)
        var countI = Int32(count)
        vvexpf(&expVals, &shifted, &countI)

        // sum(exp)
        var sumExp: Float = 0
        vDSP_sve(expVals, 1, &sumExp, vDSP_Length(count))

        let logSumExp = logf(max(sumExp, Float.leastNormalMagnitude))

        // log_softmax = shifted - log_sum_exp
        var result = [Float](repeating: 0, count: count)
        var negLogSum = -logSumExp
        vDSP_vsadd(shifted, 1, &negLogSum, &result, 1, vDSP_Length(count))

        return result
    }

    /// Собирает `[PhonemeSpan]` из decoded state path.
    ///
    /// Нечётные состояния соответствуют фонемам (state 2i+1 → refIds[i]).
    /// Чётные состояния — blank. Собираем непрерывные блоки нечётных состояний
    /// и записываем первый/последний кадр как startFrame/endFrame спана.
    private static func buildSpans(
        statePath: [Int],
        stateSymbols: [Int],
        refIds: [Int]
    ) -> [PhonemeSpan] {
        let numPhonemes = refIds.count
        var spans = [PhonemeSpan?](repeating: nil, count: numPhonemes)

        for (t, state) in statePath.enumerated() {
            guard state % 2 == 1 else { continue } // чётные — blank, пропускаем
            let refIdx = state / 2
            guard refIdx < numPhonemes else { continue }

            let symbol = Wav2Vec2Vocabulary.symbol(at: refIds[refIdx]) ?? "<unk>"

            if let existing = spans[refIdx] {
                spans[refIdx] = PhonemeSpan(
                    phoneme: existing.phoneme,
                    startFrame: existing.startFrame,
                    endFrame: t
                )
            } else {
                spans[refIdx] = PhonemeSpan(phoneme: symbol, startFrame: t, endFrame: t)
            }
        }

        // Для фонем без явного спана (edge case: слишком короткое слово) —
        // используем fallback равномерного разбиения.
        let timeSteps = statePath.count
        return spans.enumerated().map { (idx, span) in
            if let sp = span { return sp }
            let step = max(1, timeSteps / numPhonemes)
            let start = idx * step
            let end = min(start + step - 1, timeSteps - 1)
            let symbol = Wav2Vec2Vocabulary.symbol(at: refIds[idx]) ?? "<unk>"
            return PhonemeSpan(phoneme: symbol, startFrame: start, endFrame: end)
        }
    }
}
