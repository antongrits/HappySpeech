import Foundation
import OSLog

// MARK: - LetterPaintingFunInteractor

/// VIP-модуль творческого рисования букв «Раскрась букву» (@Observable Interactor + View).
///
/// Это креативная игра без оценки «верно/неверно» (ребёнок закрашивает контур
/// буквы). Поэтому персистится честная **сессия вовлечённости**: реальные минуты
/// практики идут в агрегаты профиля/серию дней через `SessionPersistenceCoordinating`,
/// но `totalAttempts`/`correctAttempts` = 0 — счёт не выдумывается. Сессия пишется
/// один раз при завершении и только если ребёнок реально провёл хотя бы один штрих.
@MainActor
@Observable
final class LetterPaintingFunInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterPaintingFun"
    )

    let childId: String
    var state: LetterPaintingFunModels.ViewState

    private let sessionPersistence: (any SessionPersistenceCoordinating)?
    private let sessionId = UUID().uuidString
    private let sessionStart = Date()
    private var didEngage = false
    private var didPersistSession = false

    init(
        childId: String,
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil
    ) {
        self.childId = childId
        self.sessionPersistence = sessionPersistence
        self.state = .initial
    }

    func selectLetter(_ letter: String) {
        state.currentLetter = letter
        state.strokes.removeAll()
        Self.logger.info("selectLetter \(letter, privacy: .public)")
    }

    func selectColor(_ color: LetterPaintingFunModels.PaintColor) {
        state.currentColor = color
        Self.logger.info("selectColor \(color.rawValue, privacy: .public)")
    }

    func appendStroke(_ points: [CGPoint]) {
        guard !points.isEmpty else { return }
        let stroke = LetterPaintingFunModels.Stroke(
            id: UUID(),
            color: state.currentColor,
            points: points
        )
        state.strokes.append(stroke)
        didEngage = true
    }

    func clear() {
        state.strokes.removeAll()
        Self.logger.info("clear strokes")
    }

    /// Фиксирует сессию вовлечённости при завершении (реальные минуты, без
    /// выдуманного счёта). Один раз и только если был хотя бы один штрих.
    func finish() async {
        guard didEngage, !didPersistSession, let sessionPersistence, !childId.isEmpty else { return }
        didPersistSession = true

        let dto = SessionDTO(
            id: sessionId,
            childId: childId,
            date: Date(),
            templateType: TemplateType.letterTracing.rawValue,
            targetSound: "",
            stage: CorrectionStage.prep.rawValue,
            durationSeconds: Int(Date().timeIntervalSince(sessionStart)),
            totalAttempts: 0,
            correctAttempts: 0,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
        await sessionPersistence.persistAndSync(dto)
        Self.logger.info("LetterPaintingFun engagement session persisted")
    }
}
