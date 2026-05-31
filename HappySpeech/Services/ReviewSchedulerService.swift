import Foundation
import OSLog

// MARK: - ReviewSchedulerService (F1-016)
//
// Интервальное повторение слов-ошибок по всем основным шаблонам.
//
// ### Зачем
// FSRS/SM-2 раньше жил узко: SM-2-агрегация по звуку — в `LiveAdaptivePlannerService`,
// FSRS — только в LexicalThemes. F1-016 требует единый планировщик повторов,
// в который пишут результаты ВСЕХ основных шаблонов (minimal-pairs,
// repeat-after-model, listen-and-choose, articulation) и новых механик
// (Звуковой детектив, Слоговая улитка, Словообразование, Чей хвост).
//
// ### Методическая лестница интервалов
// Закреплённая лестница 1 → 3 → 7 → 14 → 30 дней (correction-stages, принцип
// распределённого повторения). При ошибке слово сбрасывается на ступень 0
// (повтор завтра, 1 день) — errorless: не наказание, а «ещё разок скоро».
// При успехе — продвигается на следующую ступень. Это методически мягче, чем
// полный SM-2 EF-пересчёт, и предсказуемо для родителя/логопеда.
//
// ### Хранение — вне Realm (UserDefaults), обоснование в `ReviewScheduleStore`.

// MARK: - ReviewLadder (чистая логика, тестируемая)

/// Чистая детерминированная логика лестницы интервалов 1→3→7→14→30 дней.
/// `nonisolated`-friendly: только value-семантика, без I/O и глобального состояния.
public enum ReviewLadder {

    /// Ступени лестницы в днях (correction-stages). Индекс = ступень.
    public static let intervalsDays: [Int] = [1, 3, 7, 14, 30]

    /// Максимальный индекс ступени (слово полностью закреплено).
    public static var maxStepIndex: Int { intervalsDays.count - 1 }

    /// Интервал в днях для ступени `step` (зажимается в границы лестницы).
    public static func intervalDays(forStep step: Int) -> Int {
        let clamped = min(max(0, step), maxStepIndex)
        return intervalsDays[clamped]
    }

    /// Новая ступень после результата попытки.
    /// - correct → следующая ступень (не выше максимума).
    /// - ошибка  → сброс на 0 (повтор завтра). Errorless: «вернёмся скоро», не наказание.
    public static func nextStep(currentStep: Int, correct: Bool) -> Int {
        guard correct else { return 0 }
        return min(currentStep + 1, maxStepIndex)
    }

    /// Дата следующего повтора от `now` для ступени `step`.
    public static func nextDueDate(forStep step: Int, from now: Date) -> Date {
        let days = intervalDays(forStep: step)
        let startOfDay = Calendar.current.startOfDay(for: now)
        return Calendar.current.date(byAdding: .day, value: days, to: startOfDay)
            ?? now.addingTimeInterval(TimeInterval(days) * 86_400)
    }

    /// Применяет результат попытки к состоянию повтора и возвращает новое состояние.
    public static func apply(
        outcome correct: Bool,
        to state: ReviewItemState,
        now: Date = Date()
    ) -> ReviewItemState {
        let newStep = nextStep(currentStep: state.step, correct: correct)
        let totalReviews = state.totalReviews + 1
        let totalCorrect = state.totalCorrect + (correct ? 1 : 0)
        return ReviewItemState(
            itemId: state.itemId,
            sound: state.sound,
            step: newStep,
            lastReviewed: now,
            nextDue: nextDueDate(forStep: newStep, from: now),
            totalReviews: totalReviews,
            totalCorrect: totalCorrect
        )
    }

    /// Стартовое состояние для нового слова-ошибки (due завтра — повторить скоро).
    public static func newItem(itemId: String, sound: String, correct: Bool, now: Date = Date()) -> ReviewItemState {
        let step = nextStep(currentStep: 0, correct: correct)
        return ReviewItemState(
            itemId: itemId,
            sound: sound,
            step: step,
            lastReviewed: now,
            nextDue: nextDueDate(forStep: step, from: now),
            totalReviews: 1,
            totalCorrect: correct ? 1 : 0
        )
    }
}

// MARK: - ReviewItemState

/// Состояние одного слова в интервальном повторении. Codable — сериализуется в
/// JSON в UserDefaults (per-child). Чистая value-семантика.
public struct ReviewItemState: Sendable, Codable, Equatable {
    /// Идентификатор контент-элемента (слово/пара/задание).
    public let itemId: String
    /// Целевой звук/группа (для подмешивания по нужному звуку).
    public let sound: String
    /// Текущая ступень лестницы 1→3→7→14→30 (0…4).
    public let step: Int
    /// Дата последнего повтора.
    public let lastReviewed: Date
    /// Дата, когда слово снова станет due.
    public let nextDue: Date
    /// Всего повторов слова.
    public let totalReviews: Int
    /// Всего успешных повторов.
    public let totalCorrect: Int

    public init(
        itemId: String,
        sound: String,
        step: Int,
        lastReviewed: Date,
        nextDue: Date,
        totalReviews: Int,
        totalCorrect: Int
    ) {
        self.itemId = itemId
        self.sound = sound
        self.step = step
        self.lastReviewed = lastReviewed
        self.nextDue = nextDue
        self.totalReviews = totalReviews
        self.totalCorrect = totalCorrect
    }

    /// Слово созрело для повтора к моменту `now`.
    public func isDue(at now: Date = Date()) -> Bool {
        nextDue <= now
    }

    /// Слово полностью закреплено (достигло верхней ступени лестницы).
    public var isMastered: Bool { step >= ReviewLadder.maxStepIndex }
}

// MARK: - ReviewSchedulerService Protocol

/// Единый планировщик интервального повторения слов-ошибок (F1-016).
///
/// Игры по завершении вызывают `recordOutcome` на каждое слово; планировщик
/// в начале дневного маршрута подмешивает due-повторы через `dueReviews`.
public protocol ReviewSchedulerService: Sendable {

    /// Зафиксировать результат попытки по слову. Создаёт или продвигает состояние
    /// по лестнице 1→3→7→14→30. Полностью закреплённые слова, отвеченные верно,
    /// можно отпускать (не подмешивать), но они остаются в истории.
    func recordOutcome(childId: String, itemId: String, sound: String, correct: Bool) async

    /// Слова, созревшие для повтора к `now`, по убыванию приоритета (самые
    /// просроченные первыми). Опциональный фильтр по звуку.
    func dueReviews(for childId: String, sound: String?, now: Date, limit: Int) async -> [ReviewItemState]

    /// Полное состояние повторов ребёнка (для отчётов/тестов).
    func allItems(for childId: String) async -> [ReviewItemState]
}

public extension ReviewSchedulerService {
    /// Удобный вызов без фильтра по звуку и с дефолтным лимитом.
    func dueReviews(for childId: String, now: Date = Date(), limit: Int = 3) async -> [ReviewItemState] {
        await dueReviews(for: childId, sound: nil, now: now, limit: limit)
    }
}

// MARK: - ReviewScheduleStore (UserDefaults persistence)

/// Хранилище состояний интервального повторения per-child в UserDefaults.
///
/// ### Почему UserDefaults, а не Realm
/// Расписание повторов — производная адаптивная конфигурация планировщика, а не
/// синхронизируемый прогресс. Добавление новой Realm-модели потребовало бы bump
/// `RealmSchemaVersion` + правки DTO/репозиториев/sync-snapshot'ов — большой blast
/// radius и риск миграции. Проект уже хранит адаптивные данные вне Realm
/// (`AdaptivePlannerSeed`, `SpeechDisorderStore`); F1-016 хранится тем же способом:
/// per-child JSON-блоб под ключом `review.schedule.<childId>`. Multi-child-safe,
/// без миграций. Источник истины для прогресса звука остаётся Realm/SM-2.
enum ReviewScheduleStore {

    private static let keyPrefix = "review.schedule."

    private static func key(for childId: String) -> String { keyPrefix + childId }

    static func load(childId: String, defaults: UserDefaults = .standard) -> [String: ReviewItemState] {
        guard !childId.isEmpty,
              let data = defaults.data(forKey: key(for: childId)),
              let map = try? JSONDecoder().decode([String: ReviewItemState].self, from: data)
        else { return [:] }
        return map
    }

    static func save(_ map: [String: ReviewItemState], childId: String, defaults: UserDefaults = .standard) {
        guard !childId.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: key(for: childId))
    }

    static func clear(childId: String, defaults: UserDefaults = .standard) {
        guard !childId.isEmpty else { return }
        defaults.removeObject(forKey: key(for: childId))
    }
}

// MARK: - LiveReviewSchedulerService

/// UserDefaults-backed реализация планировщика повторов.
///
/// Сериализация и доступ изолированы actor'ом, чтобы запись из разных игр была
/// потокобезопасной без гонок над общим JSON-блобом.
public actor LiveReviewSchedulerService: ReviewSchedulerService {

    private let defaults: UserDefaults

    /// Инициализатор по имени suite (Sendable-параметр — безопасно пересекает
    /// actor-границу). `nil` → `.standard`. Используется и в проде, и в тестах
    /// (изолированный suite), без передачи non-Sendable `UserDefaults`.
    public init(suiteName: String? = nil) {
        if let suiteName, let suite = UserDefaults(suiteName: suiteName) {
            self.defaults = suite
        } else {
            self.defaults = .standard
        }
    }

    public func recordOutcome(childId: String, itemId: String, sound: String, correct: Bool) async {
        guard !childId.isEmpty, !itemId.isEmpty else { return }
        var map = ReviewScheduleStore.load(childId: childId, defaults: defaults)
        let now = Date()
        if let existing = map[itemId] {
            map[itemId] = ReviewLadder.apply(outcome: correct, to: existing, now: now)
        } else {
            map[itemId] = ReviewLadder.newItem(itemId: itemId, sound: sound, correct: correct, now: now)
        }
        ReviewScheduleStore.save(map, childId: childId, defaults: defaults)
        HSLogger.planner.debug(
            "Review recorded child=\(childId, privacy: .private) item=\(itemId, privacy: .public) correct=\(correct) step=\(map[itemId]?.step ?? -1)"
        )
    }

    public func dueReviews(for childId: String, sound: String?, now: Date, limit: Int) async -> [ReviewItemState] {
        let map = ReviewScheduleStore.load(childId: childId, defaults: defaults)
        return ReviewSelector.dueItems(from: Array(map.values), sound: sound, now: now, limit: limit)
    }

    public func allItems(for childId: String) async -> [ReviewItemState] {
        Array(ReviewScheduleStore.load(childId: childId, defaults: defaults).values)
    }
}

// MARK: - ReviewSelector (чистая логика выборки, тестируемая)

/// Чистая детерминированная выборка due-повторов. Вынесена из actor'а, чтобы
/// тестироваться без I/O.
public enum ReviewSelector {

    /// Отбирает созревшие повторы: фильтр по due и (опц.) звуку, сортировка по
    /// «насколько просрочено» (самые старые nextDue первыми), затем по ступени
    /// (менее закреплённые приоритетнее), ограничение `limit`. Полностью
    /// закреплённые (mastered) не подмешиваются — они уже автоматизированы.
    public static func dueItems(
        from items: [ReviewItemState],
        sound: String?,
        now: Date,
        limit: Int
    ) -> [ReviewItemState] {
        guard limit > 0 else { return [] }
        let filtered = items.filter { item in
            guard item.isDue(at: now), !item.isMastered else { return false }
            if let sound, item.sound != sound { return false }
            return true
        }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.nextDue != rhs.nextDue { return lhs.nextDue < rhs.nextDue }
            return lhs.step < rhs.step
        }
        return Array(sorted.prefix(limit))
    }
}
