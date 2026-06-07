import Foundation
import OSLog

// MARK: - VisualVocabularyFlipInteractor

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
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

    init(childId: String) {
        self.childId = childId
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
        }
        Self.logger.info("Flip toggled \(id, privacy: .public)")
    }

    func setFilter(_ value: VisualVocabularyFlipModels.SoundFilter) {
        filter = value
        flippedIds.removeAll()
    }
}
