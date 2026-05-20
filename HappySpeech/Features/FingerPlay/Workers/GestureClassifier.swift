import Foundation

// MARK: - GestureClassifier
//
// Безкамерный слой принятия решения: получает HandPose.rawValue и
// targetPose и возвращает результат сравнения. Изолировано от Vision
// для удобства unit-тестирования.

struct GestureClassifier: Sendable {

    /// Минимальная уверенность HandPoseWorker'а для зачёта совпадения.
    let minimumConfidence: Float

    init(minimumConfidence: Float = 0.5) {
        self.minimumConfidence = minimumConfidence
    }

    // MARK: - Public

    /// Проверяет совпадение detectedPose и targetPose с учётом порога уверенности.
    /// Возвращает `true`, если жест совпадает И уверенность достаточная.
    func matches(detected: String, confidence: Float, target: String) -> Bool {
        guard confidence >= minimumConfidence else { return false }
        if detected == target { return true }
        // Допускаем эквивалентные жесты: «point» и «pinch» оба считаются
        // показом пальцев — это снижает раздражение детей.
        if equivalentSets.contains(where: { $0.contains(detected) && $0.contains(target) }) {
            return true
        }
        return false
    }

    /// Сколько повторений нужно собрать на стадии (выводится из FingerStage.repetitions).
    func requiredRepetitions(for stage: FingerStage) -> Int {
        max(1, stage.repetitions)
    }

    /// Считает, что серия `successes` подряд (без сбоев) достигла цели.
    func didReachTarget(successesInARow: Int, stage: FingerStage) -> Bool {
        successesInARow >= requiredRepetitions(for: stage)
    }

    // MARK: - Private

    /// Эквивалентные жесты — взаимозаменяемы для детских целей.
    private var equivalentSets: [Set<String>] {
        [
            ["point", "pinch"]      // указательный и щепотка — оба «точка»
        ]
    }
}
