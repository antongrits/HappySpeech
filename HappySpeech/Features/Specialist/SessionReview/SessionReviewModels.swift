import Foundation

// MARK: - SessionReviewModels
//
// VIP models for the specialist "Session review" screen. Lets the specialist
// step through every attempt of a concrete session, playback the child's
// recording, and override the auto-computed score with a manual score.
//
// M6.15 (B1): добавлен use case `LoadDetails` — расширенный обзор сессии
// для специалиста (имя ребёнка, разбивка по играм, точность по фонемам,
// рекомендация LLM, экспорт PDF). Старые use case'ы (`LoadSession`,
// `SetManualScore`, `FinalizeReview`) сохранены без изменений — обеспечивают
// обратную совместимость существующих per-attempt флоу.

// swiftlint:disable nesting
enum SessionReviewModels {

    // MARK: LoadSession (per-attempt review)
    enum LoadSession {
        struct Request { let sessionId: String }
        struct Response {
            let session: SessionDTO
            let attemptRows: [AttemptReviewRow]
        }
        struct ViewModel: Equatable {
            let titleText: String
            let rows: [AttemptReviewRow]
            let summary: SessionReviewSummary
        }
    }

    // MARK: SetManualScore
    enum SetManualScore {
        struct Request {
            let sessionId: String
            let attemptId: String
            let manualScore: Double
        }
        struct Response {
            let attemptRows: [AttemptReviewRow]
            let summary: SessionReviewSummary
        }
        struct ViewModel: Equatable {
            let rows: [AttemptReviewRow]
            let summary: SessionReviewSummary
        }
    }

    // MARK: FinalizeReview
    enum FinalizeReview {
        struct Request {
            let sessionId: String
            let specialistNotes: String
        }
        struct Response { let savedAt: Date }
        struct ViewModel: Equatable {
            let confirmationText: String
        }
    }

    // MARK: LoadDetails (M6.15 — обогащённый обзор для SessionReviewView)
    enum LoadDetails {
        struct Request { let sessionId: String }
        struct Response {
            let summary: SessionSummary
        }
        struct ViewModel: Equatable {
            let titleText: String
            let dateText: String
            let durationText: String
            let childNameText: String
            let games: [GameResultViewModel]
            let phonemeChartData: [SoundAccuracy]
            let phonemeRows: [PhonemeRowViewModel]
            let llmRecommendation: String?
            let overallAccuracyPercent: Int
            let totalAttemptsText: String
        }
    }

    // MARK: ExportPDF
    enum ExportPDF {
        struct Request { let sessionId: String }
        struct Response { let url: URL }
        struct ViewModel: Equatable {
            let shareableURL: URL
            let confirmationText: String
        }
    }

    // MARK: LoadAttemptBreakdown (M6.15 — per-attempt scoring detail)
    enum LoadAttemptBreakdown {
        struct Request { let sessionId: String }
        struct Response {
            let sessionId: String
            let rows: [AttemptBreakdownRow]
        }
        struct ViewModel: Equatable {
            let sessionId: String
            let rows: [AttemptBreakdownViewModel]
            let stats: BreakdownStatsViewModel
        }
    }

    // MARK: AddAnnotation (M6.15 — specialist text annotation)
    enum AddAnnotation {
        struct Request {
            let sessionId: String
            /// nil — аннотация ко всей сессии; строка — к конкретной попытке.
            let targetAttemptId: String?
            let text: String
        }
        struct Response {
            let sessionId: String
            let annotations: [SessionAnnotation]
        }
        struct ViewModel: Equatable {
            let annotations: [AnnotationViewModel]
            let confirmationText: String
        }
    }

    // MARK: DeleteAnnotation (M6.15)
    enum DeleteAnnotation {
        struct Request {
            let sessionId: String
            let annotationId: String
        }
        // Response переиспользует AddAnnotation.Response
    }

    // MARK: AnnotationUpdated (shared response from add/delete)
    enum AnnotationUpdated {
        struct Response {
            let sessionId: String
            let annotations: [SessionAnnotation]
        }
        struct ViewModel: Equatable {
            let annotations: [AnnotationViewModel]
        }
    }
}
// swiftlint:enable nesting

// MARK: - Per-attempt row (existing)

struct AttemptReviewRow: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let word: String
    let asrTranscript: String
    let autoScore: Double
    let manualScore: Double?
    let audioPath: String
    let isMarkedCorrect: Bool

    /// Effective score used for summaries: `manualScore` wins over `autoScore`.
    var effectiveScore: Double { manualScore ?? autoScore }
}

struct SessionReviewSummary: Sendable, Equatable {
    let totalAttempts: Int
    let markedCorrect: Int
    let averageEffectiveScore: Double
    let disagreementCount: Int   // specialist overrode auto — count of such rows
}

// MARK: - SessionSummary (B1 — full session report)

/// Расширенная сводка сессии для специалиста. Собирается интерактором из
/// `SessionDTO` + `ChildProfileDTO` + (опционально) рекомендации LLM,
/// положенной в Realm-поле `notes` или вычисленной на лету.
struct SessionSummary: Sendable, Equatable {
    let sessionId: String
    let date: Date
    let duration: TimeInterval
    let childName: String
    let targetSound: String
    let games: [GameResult]
    /// Точность произношения по фонемам, 0...1.
    let phonemeAccuracy: [String: Double]
    /// Текст рекомендации LLM. `nil` если не сгенерирован.
    let llmRecommendation: String?
    let totalAttempts: Int
    let correctAttempts: Int
    let fatigueDetected: Bool
}

/// Результат одной игры внутри сессии. `gameName` — человекочитаемое имя
/// шаблона (например, «Слушай и выбери»), `correct` — количество верных
/// ответов, `total` — общее число попыток в игре.
struct GameResult: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let gameName: String
    let templateType: String
    let correct: Int
    let total: Int

    /// 0...1, защищено от деления на ноль.
    var accuracy: Double {
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total)
    }
}

// MARK: - View-side row models

/// Строка для отображения одной игры в списке.
struct GameResultViewModel: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let detailText: String
    let accuracyPercent: Int
    /// Семантический тон строки: зелёный/жёлтый/красный.
    let tone: AccuracyTone
}

/// Строка для отображения точности по конкретной фонеме.
struct PhonemeRowViewModel: Identifiable, Equatable, Hashable {
    let id: String
    let phoneme: String
    let accuracyPercent: Int
    let tone: AccuracyTone
}

/// Семантика точности — управляет цветом UI и accessibility-метками.
enum AccuracyTone: Sendable, Equatable, Hashable {
    /// ≥80%
    case good
    /// 50…79%
    case medium
    /// <50%
    case poor

    static func make(from percent: Int) -> AccuracyTone {
        switch percent {
        case 80...:
            return .good
        case 50..<80:
            return .medium
        default:
            return .poor
        }
    }

    /// Локализованный заголовок тона — используется в a11y-метках и
    /// текстовых описаниях рядом с цветом.
    var localizedTitle: String {
        switch self {
        case .good:   return String(localized: "review.tone.good")
        case .medium: return String(localized: "review.tone.medium")
        case .poor:   return String(localized: "review.tone.poor")
        }
    }
}

// MARK: - AttemptBreakdownRow (M6.15 — per-attempt detail)

/// Детальная строка для одной попытки в контексте специалистского обзора.
/// Содержит все три оценки (ASR, ML, manual) и флаг уверенности движка.
struct AttemptBreakdownRow: Identifiable, Sendable, Equatable, Hashable {
    /// Порядковый номер (1-based) — для отображения в UI.
    let index: Int
    let id: String
    let word: String
    let asrTranscript: String
    /// Оценка ASR-движка (WhisperKit confidence × корректность транскрипта), 0…1.
    let asrScore: Double
    /// Оценка PronunciationScorer (Core ML), nil если модель не применялась.
    let pronunciationScore: Double?
    /// Ручная оценка специалиста, nil если не выставлена.
    let manualScore: Double?
    /// Итоговая оценка: manualScore > pronunciationScore > asrScore.
    let effectiveScore: Double
    /// Финальный бинарный результат попытки.
    let isCorrect: Bool
    /// Путь к локальному аудиофайлу для воспроизведения.
    let audioPath: String
    /// Уровень согласованности между ASR и ML оценками.
    let confidence: ScoreConfidence
    let timestamp: Date
}

// MARK: - ScoreConfidence

/// Согласованность между автоматическими оценками. Влияет на иконку в UI.
enum ScoreConfidence: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Обе модели согласны — отклонение < 15%.
    case high
    /// Умеренное расхождение 15–30%.
    case medium
    /// Сильное расхождение > 30% или только одна модель.
    case low

    static func make(asr: Double, pronunciation: Double, manual: Double) -> ScoreConfidence {
        // Manual override снижает доверие до medium — специалист что-то знает.
        if manual > 0 { return .medium }
        // Если PronunciationScorer не применялся — только ASR.
        guard pronunciation >= 0 else { return .low }
        let delta = abs(asr - pronunciation)
        switch delta {
        case ..<0.15:
            return .high
        case ..<0.30:
            return .medium
        default:
            return .low
        }
    }

    var iconName: String {
        switch self {
        case .high:   return "checkmark.seal.fill"
        case .medium: return "exclamationmark.triangle"
        case .low:    return "questionmark.circle"
        }
    }
}

// MARK: - BreakdownStats

/// Агрегированная статистика breakdown'а — отдаётся в ViewModel.
struct BreakdownStats: Sendable, Equatable {
    let averageASR: Double
    let averagePronunciation: Double?
    let averageEffective: Double
    let totalCorrect: Int
    let manualOverrideCount: Int
}

// MARK: - SessionAnnotation

/// Текстовая аннотация специалиста к сессии или к конкретной попытке.
/// In-memory (M6.15), сохранение в Realm через Sync-слой — в следующем спринте.
struct SessionAnnotation: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let sessionId: String
    /// nil — аннотация ко всей сессии, строка — к попытке.
    let targetAttemptId: String?
    let text: String
    let createdAt: Date
}

// MARK: - View-side models (M6.15)

struct AttemptBreakdownViewModel: Identifiable, Equatable, Hashable {
    let id: String
    let index: Int
    let word: String
    let asrTranscript: String
    let asrScoreText: String
    let pronunciationScoreText: String?
    let effectiveScoreText: String
    let isCorrect: Bool
    let audioPath: String
    let confidenceIconName: String
    let tone: AccuracyTone
    let hasManualScore: Bool
    let timestampText: String
}

struct BreakdownStatsViewModel: Equatable {
    let averageASRText: String
    let averagePronunciationText: String?
    let averageEffectiveText: String
    let totalCorrectText: String
    let manualOverrideText: String?
}

struct AnnotationViewModel: Identifiable, Equatable, Hashable {
    let id: String
    let text: String
    let dateText: String
    /// nil — аннотация ко всей сессии.
    let targetAttemptWord: String?
    let isSessionLevel: Bool
}

// MARK: - SessionReview (B1 alias namespace)
//
// Лёгкий публичный namespace по ТЗ M6.15 B1. Позволяет вызывающему коду писать
//
//     SessionReview.Request(sessionId: "abc")
//     viewModel: SessionReview.ViewModel
//
// вместо длинного `SessionReviewModels.LoadDetails.*`. Это чистые
// value-типы — обёртки над старыми моделями, без дублирования логики.

enum SessionReview {

    /// Идентификатор сессии для запроса детального обзора.
    struct Request: Sendable, Equatable {
        let sessionId: String
    }

    /// Сырая «доменная» сводка по сессии — то, что Interactor собирает
    /// из репозиториев. По сути зеркало `SessionSummary`, но с отдельным
    /// полем error для гибких флоу.
    struct Response: Sendable {
        let sessionId: String
        let date: Date
        let duration: TimeInterval
        let childName: String
        let games: [GameResult]
        let phonemeAccuracy: [String: Double]
        let llmRecommendation: String?
        let error: Error?

        init(
            sessionId: String,
            date: Date,
            duration: TimeInterval,
            childName: String,
            games: [GameResult],
            phonemeAccuracy: [String: Double],
            llmRecommendation: String?,
            error: Error? = nil
        ) {
            self.sessionId = sessionId
            self.date = date
            self.duration = duration
            self.childName = childName
            self.games = games
            self.phonemeAccuracy = phonemeAccuracy
            self.llmRecommendation = llmRecommendation
            self.error = error
        }
    }

    /// Готовая ViewModel — то, что показывается на экране. Текстовые поля
    /// уже локализованы и отформатированы Presenter-ом.
    struct ViewModel: Sendable, Equatable {
        let title: String
        let childName: String
        let durationText: String
        let gameRows: [GameRow]
        let phonemeRows: [PhonemeRow]
        let llmSummary: String?
        let exportEnabled: Bool
    }

    /// Строка для одной игры в сессии. Цвет вычислен Presenter-ом по тону
    /// (зелёный/жёлтый/красный) — view не делает свой расчёт.
    struct GameRow: Sendable, Equatable, Identifiable {
        let id: String
        let name: String
        let correct: Int
        let total: Int
        let accuracyPercent: Int
        let toneRaw: Int  // 0=good, 1=medium, 2=poor — для Sendable Equatable
    }

    /// Строка с точностью по фонеме.
    struct PhonemeRow: Sendable, Equatable, Identifiable {
        let id: String
        let phoneme: String
        let accuracyPercent: Int
        let toneRaw: Int
    }
}
