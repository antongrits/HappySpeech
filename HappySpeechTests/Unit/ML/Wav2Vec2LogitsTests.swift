@preconcurrency import CoreML
@testable import HappySpeech
import XCTest

// MARK: - Wav2Vec2LogitsTests
//
// Покрывает новый контракт `Wav2Vec2Service.logits(audio:)` (v17 «Фонемный
// паспорт»): возврат сырой матрицы T×37 и конвертацию MLMultiArray → [[Float]].
// Тяжёлую CoreML-модель не грузим — проверяем mock-контракт и чистый конвертер.

final class Wav2Vec2LogitsTests: XCTestCase {

    private let vocabSize = Wav2Vec2Vocabulary.size

    // MARK: - Mock logits: явная матрица возвращается как есть

    func test_mockLogits_returnsExplicitMatrixUnchanged() async throws {
        let explicit: [[Float]] = [
            [1, 2, 3],
            [4, 5, 6]
        ]
        let mock = Wav2Vec2ServiceMock(text: "кот", logits: explicit)

        let result = try await mock.logits(audio: Data(count: 64))

        XCTAssertEqual(result, explicit, "Явно заданная матрица должна возвращаться без изменений")
    }

    // MARK: - Mock logits: синтез из текста (форма и доминирующий класс)

    func test_mockLogits_synthesizedFromText_hasExpectedShapeAndDominance() async throws {
        let mock = Wav2Vec2ServiceMock(text: "рыба")
        let result = try await mock.logits(audio: Data(count: 64))

        XCTAssertFalse(result.isEmpty, "Синтез по непустому слову не должен быть пустым")
        // Каждая строка — длиной vocabSize.
        for row in result {
            XCTAssertEqual(row.count, vocabSize, "Каждая строка логитов — размером словаря (\(vocabSize))")
        }
        // Аргмакс хотя бы одной строки должен указывать на «р» (есть в словаре).
        guard let rId = Wav2Vec2Vocabulary.index(of: "р") else {
            return XCTFail("Символ 'р' должен присутствовать в словаре модели")
        }
        let dominatedByR = result.contains { row in
            argmax(row) == rId
        }
        XCTAssertTrue(dominatedByR, "Хотя бы один кадр должен доминироваться классом 'р'")
    }

    func test_mockLogits_throwsWhenConfigured() async {
        let mock = Wav2Vec2ServiceMock(text: "кот", shouldThrow: true)
        do {
            _ = try await mock.logits(audio: Data(count: 64))
            XCTFail("Ожидалась ошибка при shouldThrow=true")
        } catch {
            // Ожидаемо.
        }
    }

    // MARK: - multiArrayToMatrix: [1, T, C] float32

    func test_multiArrayToMatrix_3D_float32_rowMajor() throws {
        let timeSteps = 3
        let vocab = 4
        let array = try MLMultiArray(shape: [1, NSNumber(value: timeSteps), NSNumber(value: vocab)], dataType: .float32)
        // Заполняем известными значениями: value = t * 10 + c.
        var flatIndex = 0
        for _ in 0..<1 {
            for t in 0..<timeSteps {
                for c in 0..<vocab {
                    array[flatIndex] = NSNumber(value: Float(t * 10 + c))
                    flatIndex += 1
                }
            }
        }

        let matrix = Wav2Vec2ServiceLive.multiArrayToMatrix(array)

        XCTAssertEqual(matrix.count, timeSteps, "T строк")
        XCTAssertEqual(matrix.first?.count, vocab, "C столбцов")
        for t in 0..<timeSteps {
            for c in 0..<vocab {
                XCTAssertEqual(matrix[t][c], Float(t * 10 + c), accuracy: 0.0001,
                               "Значение [\(t)][\(c)] должно сохраниться при конвертации")
            }
        }
    }

    // MARK: - multiArrayToMatrix: [T, C] (2D, без batch)

    func test_multiArrayToMatrix_2D_float32() throws {
        let timeSteps = 2
        let vocab = 3
        let array = try MLMultiArray(shape: [NSNumber(value: timeSteps), NSNumber(value: vocab)], dataType: .float32)
        for index in 0..<(timeSteps * vocab) {
            array[index] = NSNumber(value: Float(index))
        }

        let matrix = Wav2Vec2ServiceLive.multiArrayToMatrix(array)

        XCTAssertEqual(matrix, [[0, 1, 2], [3, 4, 5]], "2D-форма [T,C] разворачивается row-major")
    }

    func test_multiArrayToMatrix_unsupportedRank_returnsEmpty() throws {
        let array = try MLMultiArray(shape: [NSNumber(value: 4)], dataType: .float32)
        XCTAssertTrue(Wav2Vec2ServiceLive.multiArrayToMatrix(array).isEmpty,
                      "1D-форма не поддерживается → пустая матрица")
    }

    // MARK: - Helpers

    private func argmax(_ row: [Float]) -> Int {
        var bestIndex = 0
        var bestValue = -Float.infinity
        for (index, value) in row.enumerated() where value > bestValue {
            bestValue = value
            bestIndex = index
        }
        return bestIndex
    }
}
