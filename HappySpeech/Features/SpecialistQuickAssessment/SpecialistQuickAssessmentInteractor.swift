import Foundation
import OSLog

// MARK: - SpecialistQuickAssessmentInteractor

/// Бизнес-логика экспресс-оценки специалиста.
///
/// Оценка реально персистится в `SpecialistQuickAssessmentStore` (UserDefaults,
/// per specialist+child): сохранённые звёзды по категориям переживают перезапуск
/// и подгружаются при повторном открытии. Без идентификаторов (Preview/тесты)
/// хранилище безопасно ничего не сохраняет.
@MainActor
@Observable
final class SpecialistQuickAssessmentInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistQuickAssessment"
    )

    let childId: String
    let specialistId: String
    var state: SpecialistQuickAssessmentModels.ViewState

    private let store: SpecialistQuickAssessmentStore

    init(
        childId: String,
        specialistId: String,
        defaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.specialistId = specialistId
        self.store = SpecialistQuickAssessmentStore(
            defaults: defaults,
            specialistId: specialistId,
            childId: childId
        )
        self.state = .initial
        loadSaved()
    }

    /// Подгружает ранее сохранённую оценку (если есть).
    func loadSaved() {
        guard let record = store.load() else { return }
        state.ratings = SpecialistQuickAssessmentModels.Category.allCases.map { category in
            SpecialistQuickAssessmentModels.Rating(
                id: category,
                stars: record.stars[category.rawValue] ?? 0
            )
        }
        state.isSaved = true
        Self.logger.info("loaded saved assessment")
    }

    func set(_ category: SpecialistQuickAssessmentModels.Category, stars: Int) {
        guard let idx = state.ratings.firstIndex(where: { $0.id == category }) else { return }
        state.ratings[idx].stars = max(0, min(5, stars))
        state.isSaved = false
    }

    func save() {
        var stars: [String: Int] = [:]
        for rating in state.ratings {
            stars[rating.id.rawValue] = rating.stars
        }
        let record = SpecialistQuickAssessmentStore.Record(date: Date(), stars: stars)
        let persisted = store.save(record)
        state.isSaved = true
        Self.logger.info("save assessment avg=\(self.state.averageStars) persisted=\(persisted, privacy: .public)")
    }

    func reset() {
        state = .initial
    }
}
