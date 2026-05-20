import Foundation
import OSLog

// MARK: - SpecialistAssessmentCorpus
//
// v31 Волна D Ф.3 — корпус анкеты «Первичная оценка специалиста».
// Загружается из `pack_specialist_assessment.json`.

enum SpecialistAssessmentCorpus {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistAssessment.Corpus"
    )

    private struct PackFile: Decodable {
        let questions: [SpecialistAssessmentQuestion]
    }

    /// 10 вопросов, в порядке прохождения.
    static let allQuestions: [SpecialistAssessmentQuestion] = loadFromBundle()

    /// Вопрос по идентификатору.
    static func question(id: String) -> SpecialistAssessmentQuestion? {
        allQuestions.first { $0.id == id }
    }

    private static func loadFromBundle() -> [SpecialistAssessmentQuestion] {
        guard let url = Bundle.main.url(
            forResource: "pack_specialist_assessment",
            withExtension: "json"
        ) else {
            logger.warning("pack_specialist_assessment.json не найден — анкета пуста")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(PackFile.self, from: data)
            logger.info("Загружено вопросов: \(pack.questions.count, privacy: .public)")
            return pack.questions
        } catch {
            logger.error(
                "Не удалось разобрать pack_specialist_assessment.json: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }
}
