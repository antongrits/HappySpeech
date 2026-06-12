import Foundation
@testable import HappySpeech

// MARK: - MockReviewSchedulerService
//
// Записывающий мок единого планировщика интервальных повторов (F1-016).
// Фиксирует каждый вызов `recordOutcome` для проверки, что шаблоны упражнений
// (minimal-pairs, repeat-after-model, articulation, narrative-quest) пополняют
// расписание повторений с корректными (childId, itemId, sound, correct).
//
// Actor — соответствует `Sendable`-требованию протокола и потокобезопасно
// аккумулирует вызовы, в т.ч. из fire-and-forget `Task { await … }` в горячих
// путях интеракторов.

actor MockReviewSchedulerService: ReviewSchedulerService {

    /// Один зафиксированный вызов `recordOutcome`.
    struct RecordedOutcome: Sendable, Equatable {
        let childId: String
        let itemId: String
        let sound: String
        let correct: Bool
    }

    private(set) var recordedOutcomes: [RecordedOutcome] = []

    /// Предзаданный ответ `dueReviews` (по умолчанию пусто).
    var dueStub: [ReviewItemState] = []

    func recordOutcome(childId: String, itemId: String, sound: String, correct: Bool) async {
        recordedOutcomes.append(
            RecordedOutcome(childId: childId, itemId: itemId, sound: sound, correct: correct)
        )
    }

    func dueReviews(for childId: String, sound: String?, now: Date, limit: Int) async -> [ReviewItemState] {
        dueStub
    }

    func allItems(for childId: String) async -> [ReviewItemState] {
        []
    }

    // MARK: - Test helpers

    /// Количество зафиксированных вызовов.
    var outcomeCount: Int { recordedOutcomes.count }

    /// Последний зафиксированный вызов.
    var lastOutcome: RecordedOutcome? { recordedOutcomes.last }

    /// Есть ли вызов с указанными полями.
    func contains(itemId: String, sound: String, correct: Bool) -> Bool {
        recordedOutcomes.contains { outcome in
            outcome.itemId == itemId && outcome.sound == sound && outcome.correct == correct
        }
    }
}
