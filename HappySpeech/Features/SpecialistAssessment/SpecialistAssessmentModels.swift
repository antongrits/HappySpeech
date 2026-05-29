import Foundation

// MARK: - SpecialistAssessmentModels (Clean Swift: Models)
//
// v31 Волна D Ф.3 — «Первичная оценка специалиста».
//
// Цель: закрыть Otsimo gap (G-05) — specialist-questionnaire-driven
// personalization. 10 коротких вопросов, охватывающих 5 осей речевого
// развития (Левина/Архипова/Филичёва-Чиркина):
//   • articulation — звукопроизношение и моторика артикуляционного аппарата;
//   • phonology — фонематический слух;
//   • lexical — словарный запас и обобщения;
//   • grammar — согласование, предлоги;
//   • connectedSpeech — связная речь.
//
// По завершении: подсчёт «слабых» осей → рекомендованный фокус для
// AdaptivePlannerService на ближайшие 14 дней. **Это не диагноз** —
// это методическая поддержка специалиста (project guide §11).

// MARK: - SpecialistAssessmentAxis

public enum SpecialistAssessmentAxis: String, Sendable, CaseIterable, Codable {
    case articulation
    case phonology
    case lexical
    case grammar
    case connectedSpeech
}

// MARK: - SpecialistAssessmentQuestionType

public enum SpecialistAssessmentQuestionType: String, Sendable, Codable {
    case yesno
    case scale
    /// Множественный выбор из набора `options` (например, перечень звуков,
    /// вызывающих затруднения). v32 — расширение корпуса до 15 вопросов.
    case multiselect
}

// MARK: - SpecialistAssessmentScale

public struct SpecialistAssessmentScale: Sendable, Equatable, Codable {
    public let min: Int
    public let max: Int
    public let lowLabel: String
    public let highLabel: String

    public init(min: Int, max: Int, lowLabel: String, highLabel: String) {
        self.min = min
        self.max = max
        self.lowLabel = lowLabel
        self.highLabel = highLabel
    }
}

// MARK: - SpecialistAssessmentQuestion

public struct SpecialistAssessmentQuestion: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let axis: SpecialistAssessmentAxis
    public let text: String
    public let type: SpecialistAssessmentQuestionType
    public let scale: SpecialistAssessmentScale?
    /// Варианты для `multiselect` (например, перечень звуков). Иначе `nil`.
    public let options: [String]?

    public init(
        id: String,
        axis: SpecialistAssessmentAxis,
        text: String,
        type: SpecialistAssessmentQuestionType,
        scale: SpecialistAssessmentScale?,
        options: [String]? = nil
    ) {
        self.id = id
        self.axis = axis
        self.text = text
        self.type = type
        self.scale = scale
        self.options = options
    }

    enum CodingKeys: String, CodingKey {
        case id
        case axis
        case text
        case type
        case scale
        case options
        case weight  // игнорируется при декоде, в файле дублирует axis
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        axis = try c.decode(SpecialistAssessmentAxis.self, forKey: .axis)
        text = try c.decode(String.self, forKey: .text)
        type = try c.decode(SpecialistAssessmentQuestionType.self, forKey: .type)
        scale = try c.decodeIfPresent(SpecialistAssessmentScale.self, forKey: .scale)
        options = try c.decodeIfPresent([String].self, forKey: .options)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(axis, forKey: .axis)
        try c.encode(text, forKey: .text)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(scale, forKey: .scale)
        try c.encodeIfPresent(options, forKey: .options)
    }
}

// MARK: - SpecialistAssessmentAnswer

/// Один ответ. Для yesno — boolValue, для scale — numericValue,
/// для multiselect — selectedOptions (выбранные варианты).
public struct SpecialistAssessmentAnswer: Sendable, Equatable {
    public let questionId: String
    public let axis: SpecialistAssessmentAxis
    public let boolValue: Bool?
    public let numericValue: Int?
    public let selectedOptions: [String]?

    public init(
        questionId: String,
        axis: SpecialistAssessmentAxis,
        boolValue: Bool? = nil,
        numericValue: Int? = nil,
        selectedOptions: [String]? = nil
    ) {
        self.questionId = questionId
        self.axis = axis
        self.boolValue = boolValue
        self.numericValue = numericValue
        self.selectedOptions = selectedOptions
    }

    /// Сериализованный вид для хранения в Realm (List<String>).
    /// Формат: `questionId|axis|kind|value`.
    /// Для multiselect значения разделяются запятой.
    public var serialized: String {
        if let boolValue {
            return "\(questionId)|\(axis.rawValue)|yesno|\(boolValue ? "yes" : "no")"
        } else if let numericValue {
            return "\(questionId)|\(axis.rawValue)|scale|\(numericValue)"
        } else if let selectedOptions {
            return "\(questionId)|\(axis.rawValue)|multiselect|\(selectedOptions.joined(separator: ","))"
        }
        return "\(questionId)|\(axis.rawValue)|none|"
    }
}

// MARK: - SpecialistAssessmentModels namespace

enum SpecialistAssessmentModels {

    enum Load {
        struct Request: Sendable {
            let childId: String
            let specialistId: String
        }

        struct Response: Sendable {
            let questions: [SpecialistAssessmentQuestion]
            let childId: String
            let specialistId: String
        }

        struct ViewModel: Sendable {
            let title: String
            let questions: [QuestionViewModel]
        }

        struct QuestionViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let text: String
            let axis: SpecialistAssessmentAxis
            let type: SpecialistAssessmentQuestionType
            let scale: SpecialistAssessmentScale?
            let options: [String]?
            let progressLabel: String
        }
    }

    enum Answer {
        struct Request: Sendable {
            let questionId: String
            let axis: SpecialistAssessmentAxis
            let boolValue: Bool?
            let numericValue: Int?
            let selectedOptions: [String]?

            init(
                questionId: String,
                axis: SpecialistAssessmentAxis,
                boolValue: Bool? = nil,
                numericValue: Int? = nil,
                selectedOptions: [String]? = nil
            ) {
                self.questionId = questionId
                self.axis = axis
                self.boolValue = boolValue
                self.numericValue = numericValue
                self.selectedOptions = selectedOptions
            }
        }
    }

    enum Submit {
        struct Request: Sendable {
            let childId: String
            let specialistId: String
        }

        struct Response: Sendable {
            let recommendedAxes: [SpecialistAssessmentAxis]
            let savedResultId: String
        }

        struct ViewModel: Sendable {
            let title: String
            let recommendedAxes: [RecommendedAxisViewModel]
            let validUntilLabel: String
            let applyCtaTitle: String
        }

        struct RecommendedAxisViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let axis: SpecialistAssessmentAxis
            let displayName: String
            let rationale: String
        }
    }
}
