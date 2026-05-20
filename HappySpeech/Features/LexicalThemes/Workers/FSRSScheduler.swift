import Foundation
import OSLog

// MARK: - FSRSRating
//
// v31 Волна D Ф.2 «FSRS-6 spaced repetition».
//
// Ratings ребёнка после показа слова (3 — попадание в цель сразу).
// Соответствуют SuperMemo/Anki:
//   • again — забыл, дать снова сегодня;
//   • hard  — вспомнил с трудом;
//   • good  — нормально (стандарт);
//   • easy  — легко.
//
// Источник: open-spaced-repetition/fsrs6 (MIT) — алгоритм портирован
// в чистый Swift, без внешних SPM (CLAUDE.md §3 — никаких новых
// зависимостей без согласования). Параметры w[0..18] — дефолтные из
// open-spaced-repetition, оптимизированы на ~1M anki-review-датасете.

public enum FSRSRating: Int, Sendable, CaseIterable, Equatable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

// MARK: - FSRSParameters

/// Набор из 19 весов алгоритма FSRS-6 + параметры desired retention.
public struct FSRSParameters: Sendable, Equatable {

    /// Дефолтные параметры FSRS-6 (open-spaced-repetition):
    /// median-оптимизированные на публичном Anki-датасете.
    public static let `default` = FSRSParameters(
        weights: [
            0.4072, 1.1829, 3.1262, 15.4722,
            7.2102, 0.5316, 1.0651, 0.0234,
            1.616, 0.1544, 1.0824, 1.9813,
            0.0953, 0.2975, 2.2042, 0.2407,
            2.9466, 0.5034, 0.6567
        ],
        desiredRetention: 0.9
    )

    public let weights: [Double]
    /// Целевая ретенция при назначении следующего интервала (обычно 0.9).
    public let desiredRetention: Double

    public init(weights: [Double], desiredRetention: Double) {
        self.weights = weights
        self.desiredRetention = desiredRetention
    }
}

// MARK: - FSRSReviewState

/// Состояние одного слова между ревью.
public struct FSRSReviewState: Sendable, Equatable {
    public var stability: Double
    public var difficulty: Double
    public var lastReview: Date
    public var nextReview: Date
    public var reps: Int
    public var lapses: Int

    public init(
        stability: Double,
        difficulty: Double,
        lastReview: Date,
        nextReview: Date,
        reps: Int,
        lapses: Int
    ) {
        self.stability = stability
        self.difficulty = difficulty
        self.lastReview = lastReview
        self.nextReview = nextReview
        self.reps = reps
        self.lapses = lapses
    }

    /// Стартовое состояние для нового слова — пустые поля, due сегодня.
    public static func newCard(date: Date = Date()) -> FSRSReviewState {
        FSRSReviewState(
            stability: 0,
            difficulty: 0,
            lastReview: date,
            nextReview: date,
            reps: 0,
            lapses: 0
        )
    }

    /// Истекло ли время следующего ревью к указанному моменту.
    public func isDue(at date: Date = Date()) -> Bool {
        nextReview <= date
    }
}

// MARK: - FSRSScheduler
//
// Чистый Swift-порт FSRS-6 (см. https://github.com/open-spaced-repetition).
//
// Контракт:
//   • newCard() → пустое состояние, nextReview = сейчас (карточка due).
//   • next(state, rating, now) → новое состояние с обновлёнными
//     stability/difficulty/lastReview/nextReview/reps/lapses.
//   • interval(stability) → интервал в днях через формулу обратной R(t,S).
//
// Чистая функция — без I/O. Тестируется детерминированно (см.
// `FSRSSchedulerTests`).

public struct FSRSScheduler: Sendable {

    public let parameters: FSRSParameters

    /// FSRS-6 FACTOR = 19/81, DECAY = -0.5 — производные от
    /// функции R(t,S) = (1 + FACTOR · t/S)^DECAY.
    private static let factor: Double = 19.0 / 81.0
    private static let decay: Double = -0.5

    public init(parameters: FSRSParameters = .default) {
        self.parameters = parameters
    }

    // MARK: - Public

    /// Стартовое состояние для нового слова. Карточка сразу due.
    public func newCard(date: Date = Date()) -> FSRSReviewState {
        FSRSReviewState.newCard(date: date)
    }

    /// Применяет одно ревью к карточке.
    ///
    /// - Parameters:
    ///   - state: текущее состояние карточки (или `newCard()` для первого ревью);
    ///   - rating: оценка ребёнка;
    ///   - now: момент ревью (для тестов передаётся явно).
    /// - Returns: новое состояние с обновлёнными S/D/nextReview/reps/lapses.
    public func next(
        state: FSRSReviewState,
        rating: FSRSRating,
        now: Date = Date()
    ) -> FSRSReviewState {
        let isInitialReview = state.reps == 0

        let newStability: Double
        let newDifficulty: Double
        if isInitialReview {
            newStability = initialStability(rating: rating)
            newDifficulty = initialDifficulty(rating: rating)
        } else {
            // Время с последнего ревью в днях.
            let elapsedDays = max(
                0,
                now.timeIntervalSince(state.lastReview) / 86_400
            )
            let retrievability = self.retrievability(
                elapsedDays: elapsedDays,
                stability: state.stability
            )
            newDifficulty = nextDifficulty(
                difficulty: state.difficulty,
                rating: rating
            )
            switch rating {
            case .again:
                newStability = forgottenStability(
                    difficulty: newDifficulty,
                    stability: state.stability,
                    retrievability: retrievability
                )
            case .hard, .good, .easy:
                newStability = recalledStability(
                    difficulty: newDifficulty,
                    stability: state.stability,
                    retrievability: retrievability,
                    rating: rating
                )
            }
        }

        let intervalDays = interval(stability: newStability)
        let nextReview = now.addingTimeInterval(intervalDays * 86_400)

        return FSRSReviewState(
            stability: newStability,
            difficulty: newDifficulty,
            lastReview: now,
            nextReview: nextReview,
            reps: state.reps + 1,
            lapses: rating == .again ? state.lapses + 1 : state.lapses
        )
    }

    /// Интервал до следующего ревью в днях, обратная функция R(t,S).
    /// Минимум 1 день, максимум 365 (защита от убегающего числа).
    public func interval(stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        let r = parameters.desiredRetention
        // R(t,S) = (1 + FACTOR · t/S)^DECAY  ⟹  t = S/FACTOR · (r^(1/DECAY) - 1)
        let raw = (stability / Self.factor) *
            (pow(r, 1.0 / Self.decay) - 1.0)
        return min(365.0, max(1.0, raw))
    }

    /// Текущая ретенция (вероятность вспомнить) через t дней.
    public func retrievability(
        elapsedDays: Double,
        stability: Double
    ) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1.0 + Self.factor * elapsedDays / stability, Self.decay)
    }

    // MARK: - Private helpers (FSRS-6 formulas)

    /// w[0..3] — стартовая stability для каждого рейтинга.
    private func initialStability(rating: FSRSRating) -> Double {
        let idx = max(0, min(3, rating.rawValue - 1))
        return max(0.1, parameters.weights[idx])
    }

    /// w[4] + w[5] · (rating-3) — стартовая сложность.
    private func initialDifficulty(rating: FSRSRating) -> Double {
        let w = parameters.weights
        let value = w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1
        return clampDifficulty(value)
    }

    /// D' = D - w[6] · (rating - 3); затем mean-reversion к initialDifficulty(.easy).
    private func nextDifficulty(difficulty: Double, rating: FSRSRating) -> Double {
        let w = parameters.weights
        let delta = -w[6] * Double(rating.rawValue - 3)
        let dPrime = difficulty + delta * (10 - difficulty) / 9
        // mean-reversion к target = initialDifficulty(.easy)
        let target = initialDifficulty(rating: .easy)
        let damped = w[7] * target + (1 - w[7]) * dPrime
        return clampDifficulty(damped)
    }

    private func clampDifficulty(_ value: Double) -> Double {
        min(10.0, max(1.0, value))
    }

    /// Stability после успешного ревью (Hard/Good/Easy).
    private func recalledStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: FSRSRating
    ) -> Double {
        let w = parameters.weights
        let hardPenalty = rating == .hard ? w[15] : 1.0
        let easyBonus = rating == .easy ? w[16] : 1.0
        let sInc = exp(w[8]) *
            (11 - difficulty) *
            pow(stability, -w[9]) *
            (exp(w[10] * (1 - retrievability)) - 1) *
            hardPenalty * easyBonus
        return stability * (1 + sInc)
    }

    /// Stability после лапса (Again).
    private func forgottenStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double
    ) -> Double {
        let w = parameters.weights
        return w[11] *
            pow(difficulty, -w[12]) *
            (pow(stability + 1, w[13]) - 1) *
            exp(w[14] * (1 - retrievability))
    }
}

// MARK: - FSRSScheduler.Logger

extension FSRSScheduler {
    static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FSRSScheduler"
    )
}
