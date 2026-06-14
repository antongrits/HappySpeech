import Foundation
import OSLog

// MARK: - VisualVocabularyFlipInteractor

/// VIP-модуль карточек-перевёртышей «Вижу слово» (@Observable Interactor + View).
///
/// Это исследовательская карточная игра без оценки «верно/неверно» (ребёнок
/// переворачивает карточки и изучает связку слово↔звук). Поэтому персистится
/// честная **сессия вовлечённости**: реальные минуты практики идут в агрегаты
/// профиля/серию дней через `SessionPersistenceCoordinating`, но `totalAttempts`/
/// `correctAttempts` = 0 — мы не выдумываем счёт там, где его нет. Сессия пишется
/// один раз при выходе и только если ребёнок реально открыл хотя бы одну карточку.
@MainActor
@Observable
final class VisualVocabularyFlipInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VisualVocabularyFlip"
    )

    let childId: String
    var filter: VisualVocabularyFlipModels.SoundFilter = .all
    var flippedIds: Set<UUID> = []

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
    }

    var deck: [VisualVocabularyFlipModels.Card] {
        switch filter {
        case .all: return VisualVocabularyFlipModels.deck
        case .s:   return VisualVocabularyFlipModels.deck.filter { $0.targetSound == "С" }
        case .sh:  return VisualVocabularyFlipModels.deck.filter { $0.targetSound == "Ш" }
        case .r:   return VisualVocabularyFlipModels.deck.filter { $0.targetSound == "Р" }
        case .zh:  return VisualVocabularyFlipModels.deck.filter { $0.targetSound == "Ж" }
        case .k:   return VisualVocabularyFlipModels.deck.filter { $0.targetSound == "К" }
        }
    }

    func toggle(_ id: UUID) {
        if flippedIds.contains(id) {
            flippedIds.remove(id)
        } else {
            flippedIds.insert(id)
            didEngage = true
        }
        Self.logger.info("Flip toggled \(id, privacy: .public)")
    }

    func setFilter(_ value: VisualVocabularyFlipModels.SoundFilter) {
        filter = value
        flippedIds.removeAll()
    }

    /// Фиксирует сессию вовлечённости при выходе (реальные минуты, без выдуманного
    /// счёта). Один раз и только если ребёнок открыл хотя бы одну карточку.
    func finish() async {
        guard didEngage, !didPersistSession, let sessionPersistence, !childId.isEmpty else { return }
        didPersistSession = true

        let dto = SessionDTO(
            id: sessionId,
            childId: childId,
            date: Date(),
            templateType: TemplateType.memory.rawValue,
            targetSound: "",
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: Int(Date().timeIntervalSince(sessionStart)),
            totalAttempts: 0,
            correctAttempts: 0,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
        await sessionPersistence.persistAndSync(dto)
        Self.logger.info("VisualVocabularyFlip engagement session persisted")
    }
}
