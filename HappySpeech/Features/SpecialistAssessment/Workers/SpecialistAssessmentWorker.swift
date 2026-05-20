import Foundation
import OSLog

// MARK: - SpecialistAssessmentWorkerProtocol

@MainActor
protocol SpecialistAssessmentWorkerProtocol: AnyObject {
    /// Все вопросы анкеты в порядке прохождения.
    var questions: [SpecialistAssessmentQuestion] { get }

    /// Сохраняет результат анкеты и возвращает рекомендованный фокус.
    /// Идемпотентно (новый id каждый запуск).
    @discardableResult
    func saveResult(
        childId: String,
        specialistId: String,
        answers: [SpecialistAssessmentAnswer]
    ) async -> SpecialistAssessmentModels.Submit.Response

    /// Вычисляет рекомендованный фокус (без записи в БД).
    func computeRecommendedAxes(
        answers: [SpecialistAssessmentAnswer]
    ) -> [SpecialistAssessmentAxis]
}

// MARK: - SpecialistAssessmentWorker
//
// Скоринг (педагогический, не клинический):
//   • yesno: ответ «нет» добавляет 1 балл к оси (есть проблема);
//   • scale: значение ≤ 2 добавляет 1 балл, ≤ 3 → 0.5.
// В рекомендации попадают оси, у которых балл ≥ 1.0. Если ни одна
// ось не набрала балла — возвращаются 2 самые слабые (для активации
// AdaptivePlanner всё равно).

@MainActor
final class SpecialistAssessmentWorker: SpecialistAssessmentWorkerProtocol {

    private let realmActor: RealmActor?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistAssessment.Worker"
    )

    init(realmActor: RealmActor?) {
        self.realmActor = realmActor
    }

    var questions: [SpecialistAssessmentQuestion] {
        SpecialistAssessmentCorpus.allQuestions
    }

    // MARK: - Save

    @discardableResult
    func saveResult(
        childId: String,
        specialistId: String,
        answers: [SpecialistAssessmentAnswer]
    ) async -> SpecialistAssessmentModels.Submit.Response {
        let recommended = computeRecommendedAxes(answers: answers)
        let resultId = UUID().uuidString
        let now = Date()
        let validUntil = now.addingTimeInterval(14 * 24 * 3600)
        let dto = AssessmentResultData(
            id: resultId,
            childId: childId,
            specialistId: specialistId,
            completedAt: now,
            answers: answers.map(\.serialized),
            recommendedFocus: recommended.map(\.rawValue),
            validUntil: validUntil
        )
        if let realmActor {
            await realmActor.persistAssessment(dto)
        } else {
            Self.logger.warning("realmActor отсутствует — результат не сохранён")
        }
        return SpecialistAssessmentModels.Submit.Response(
            recommendedAxes: recommended,
            savedResultId: resultId
        )
    }

    // MARK: - Scoring

    func computeRecommendedAxes(
        answers: [SpecialistAssessmentAnswer]
    ) -> [SpecialistAssessmentAxis] {
        // Группируем ответы по оси, складываем «слабые» баллы.
        var scores: [SpecialistAssessmentAxis: Double] = [:]
        for answer in answers {
            let weight = Self.weakScore(for: answer)
            scores[answer.axis, default: 0] += weight
        }
        let priority: [SpecialistAssessmentAxis] = SpecialistAssessmentAxis.allCases

        // Кандидаты с баллом ≥ 1.0.
        let weak = scores.filter { $0.value >= 1.0 }
        if !weak.isEmpty {
            return priority.filter { weak[$0] != nil }
        }
        // Иначе берём 2 самые низкие оси, чтобы AdaptivePlanner получал
        // ненулевой сигнал. Если у всех 0 баллов — пусто.
        let nonZero = scores.filter { $0.value > 0 }
        guard !nonZero.isEmpty else { return [] }
        let topTwo = nonZero
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .prefix(2)
            .map(\.key)
        return priority.filter { topTwo.contains($0) }
    }

    /// Балл «слабости» по одному ответу.
    static func weakScore(for answer: SpecialistAssessmentAnswer) -> Double {
        if let bool = answer.boolValue {
            return bool ? 0 : 1.0
        }
        if let scale = answer.numericValue {
            if scale <= 2 { return 1.0 }
            if scale <= 3 { return 0.5 }
            return 0
        }
        return 0
    }
}
