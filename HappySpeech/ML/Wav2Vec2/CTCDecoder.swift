import Accelerate
import CoreML
import Foundation

// MARK: - CTCDecoder

/// Greedy CTC декодер для Wav2Vec2RuChild.mlpackage.
///
/// Реализует алгоритм CTC greedy search:
/// 1. По каждому timestep берёт argmax из logits.
/// 2. Убирает повторы (collapsed).
/// 3. Убирает blank токены (индекс 0 = `<pad>`).
/// 4. Собирает символы в строку.
///
/// Сложность: O(T * V) где T — временных шагов, V — размер словаря (37).
///
/// ## Ограничения
/// - Greedy (не beam search) — быстро, но субоптимально при шуме.
/// - Beam search (width=5) — резерв post-v1.0, если нужна точность на шумном аудио.
/// - Не использует языковую модель — фонемный уровень достаточен для HappySpeech.
public enum CTCDecoder {

    // MARK: - Public

    /// Декодирует CTC logits из MLMultiArray в последовательность фонем.
    ///
    /// - Parameters:
    ///   - logitsArray: MLMultiArray с формой [1, T, V] Float32, где V=37.
    ///   - vocab: словарь символов (по умолчанию ``Wav2Vec2Vocabulary``).
    /// - Returns: ``CTCDecodeResult`` с фонемами, текстом и уверенностью.
    public static func decode(
        logitsArray: MLMultiArray,
        vocab: [String] = Wav2Vec2Vocabulary.symbols
    ) -> CTCDecodeResult {
        let shape = logitsArray.shape.map { $0.intValue }
        guard shape.count == 3, shape[0] == 1 else {
            return CTCDecodeResult(phonemes: [], decodedText: "", averageConfidence: 0)
        }

        let timeSteps = shape[1]
        let vocabSize = shape[2]

        var phonemes: [PhonemeLogit] = []
        var totalConfidence: Double = 0

        var prevIndex = -1

        for t in 0 ..< timeSteps {
            // Извлекаем логиты для timestep t
            var rawLogits = [Float](repeating: 0, count: vocabSize)
            for v in 0 ..< vocabSize {
                let idx = t * vocabSize + v
                rawLogits[v] = logitsArray[idx].floatValue
            }

            // Softmax для получения вероятностей
            let probs = softmax(rawLogits)

            // Argmax
            let maxIdx = argmax(probs)
            let confidence = Double(probs[maxIdx])
            totalConfidence += confidence

            // CTC greedy: пропускаем blank (0) и повторы
            if maxIdx == Wav2Vec2Vocabulary.blankIndex || maxIdx == prevIndex {
                prevIndex = maxIdx
                continue
            }

            prevIndex = maxIdx
            phonemes.append(PhonemeLogit(
                timestep: t,
                phonemeIndex: maxIdx,
                confidence: confidence
            ))
        }

        // Строим текстовую строку
        let text = buildText(from: phonemes, vocab: vocab)
        let avgConfidence = timeSteps > 0 ? totalConfidence / Double(timeSteps) : 0

        return CTCDecodeResult(
            phonemes: phonemes,
            decodedText: text,
            averageConfidence: avgConfidence
        )
    }

    // MARK: - Private Helpers

    /// Softmax по Float-массиву (numerically stable через вычитание max).
    private static func softmax(_ logits: [Float]) -> [Float] {
        guard !logits.isEmpty else { return [] }

        var maxVal: Float = -Float.infinity
        vDSP_maxv(logits, 1, &maxVal, vDSP_Length(logits.count))

        var shifted = logits.map { $0 - maxVal }
        var expVals = [Float](repeating: 0, count: logits.count)
        var count = Int32(logits.count)
        vvexpf(&expVals, &shifted, &count)

        var sum: Float = 0
        vDSP_sve(expVals, 1, &sum, vDSP_Length(logits.count))

        if sum < Float.leastNormalMagnitude { sum = 1 }
        var result = [Float](repeating: 0, count: logits.count)
        vDSP_vsdiv(expVals, 1, &sum, &result, 1, vDSP_Length(logits.count))

        return result
    }

    /// Возвращает индекс максимального элемента.
    private static func argmax(_ values: [Float]) -> Int {
        guard !values.isEmpty else { return 0 }
        var maxVal: Float = -Float.infinity
        var maxIdx: vDSP_Length = 0
        vDSP_maxvi(values, 1, &maxVal, &maxIdx, vDSP_Length(values.count))
        return Int(maxIdx)
    }

    /// Строит строку из последовательности фонемных индексов.
    private static func buildText(from phonemes: [PhonemeLogit], vocab: [String]) -> String {
        var chars: [Character] = []

        for logit in phonemes {
            guard let symbol = vocab.indices.contains(logit.phonemeIndex)
                    ? vocab[logit.phonemeIndex]
                    : nil
            else { continue }

            // Пробел — word boundary "|"
            if symbol == "|" {
                if chars.last != " " {
                    chars.append(" ")
                }
            } else if symbol != "<pad>", symbol != "<s>",
                      symbol != "</s>", symbol != "<unk>" {
                // Кириллический символ
                if let ch = symbol.first {
                    chars.append(ch)
                }
            }
        }

        return String(chars).trimmingCharacters(in: .whitespaces)
    }
}
