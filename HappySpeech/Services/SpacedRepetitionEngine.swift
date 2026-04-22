import Foundation

// MARK: - SM-2 Spaced Repetition Algorithm
//
// Реализация алгоритма SM-2 (SuperMemo 2), адаптированного для детей 5–8 лет.
//
// Оригинальный SM-2 формула:
//   1. Оценка качества ответа q ∈ [0, 5].
//   2. Если q >= 3:
//        EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
//        EF' = max(1.3, EF')
//        repetitions' = repetitions + 1
//        interval' = 1 (если repetitions' == 1)
//                    6 (если repetitions' == 2)
//                    round(prevInterval * EF') иначе
//   3. Если q < 3:
//        repetitions' = 0
//        interval' = 1
//
// Адаптации для детей:
//   • Максимальный интервал ограничен 14 днями — нельзя позволить ребёнку
//     забыть звук больше чем на две недели.
//   • При очень низком EF (< 1.5) выставляется флаг `needsSpecialistReview`,
//     чтобы родитель/приложение предложили обратиться к логопеду.
//   • При q ∈ {0, 1} интервал принудительно = 1 день (повторить завтра).

// MARK: - SM2Quality

/// Качество ответа по 6-балльной шкале SM-2 (0…5).
public enum SM2Quality: Int, Sendable, Codable {
    /// Полный пробел — ребёнок не вспомнил, не ответил.
    case blackout = 0
    /// Неправильно, но подсказка подтолкнула.
    case wrong = 1
    /// Неправильно, хотя казалось лёгким.
    case hardWrong = 2
    /// Правильно, но с трудом и паузой.
    case hardCorrect = 3
    /// Правильно, с небольшой паузой.
    case correct = 4
    /// Правильно, мгновенно и уверенно.
    case perfect = 5

    /// Сопоставляет процент правильных попыток за сессию с SM-2 quality.
    /// Используется, когда в системе нет явной самооценки ребёнка.
    public static func fromSuccessRate(_ rate: Double, hadFatigue: Bool = false) -> SM2Quality {
        let penalty = hadFatigue ? 1 : 0
        let base: SM2Quality
        switch rate {
        case ..<0.2:            base = .blackout
        case 0.2..<0.4:         base = .wrong
        case 0.4..<0.6:         base = .hardWrong
        case 0.6..<0.8:         base = .hardCorrect
        case 0.8..<0.95:        base = .correct
        default:                base = .perfect
        }
        let adjusted = max(0, base.rawValue - penalty)
        return SM2Quality(rawValue: adjusted) ?? .blackout
    }

    /// true, если ответ считается успешным (q >= 3).
    public var isSuccessful: Bool { rawValue >= 3 }
}

// MARK: - SM2Result

/// Результат пересчёта параметров SM-2 для одного звука/слова.
public struct SM2Result: Sendable, Equatable {
    /// Интервал до следующего повторения (в днях).
    public let intervalDays: Int
    /// Обновлённый коэффициент лёгкости (EF).
    public let easinessFactor: Double
    /// Новое число успешных повторений подряд.
    public let repetitions: Int
    /// Дата следующего запланированного повторения.
    public let nextReviewDate: Date
    /// true, если EF опустился ниже 1.5 — рекомендовать встречу с логопедом.
    public let needsSpecialistReview: Bool

    public init(
        intervalDays: Int,
        easinessFactor: Double,
        repetitions: Int,
        nextReviewDate: Date,
        needsSpecialistReview: Bool
    ) {
        self.intervalDays = intervalDays
        self.easinessFactor = easinessFactor
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.needsSpecialistReview = needsSpecialistReview
    }
}

// MARK: - SM2Engine

/// Чистое вычисление SM-2. Без состояния, без I/O — полностью детерминировано.
public enum SM2Engine {

    /// Минимально допустимый EF в оригинальном SM-2.
    public static let minimumEF: Double = 1.3

    /// Стартовый EF, если ребёнок никогда не работал над звуком.
    public static let defaultEF: Double = 2.5

    /// Порог EF, ниже которого рекомендуется встреча со специалистом.
    public static let specialistReviewEFThreshold: Double = 1.5

    /// Максимальный интервал между повторениями — 14 дней (адаптация для детей).
    public static let maxIntervalDays: Int = 14

    /// Рассчитать новые параметры SM-2 для одного элемента.
    ///
    /// - Parameters:
    ///   - quality: оценка качества последнего ответа.
    ///   - currentEF: текущий коэффициент лёгкости (если элемент новый — `defaultEF`).
    ///   - repetitions: сколько раз подряд ребёнок отвечал успешно (q >= 3).
    ///   - lastInterval: интервал последнего повтора в днях (1 для нового элемента).
    ///   - now: базовая дата для расчёта `nextReviewDate` (по умолчанию — сейчас).
    public static func calculate(
        quality: SM2Quality,
        currentEF: Double,
        repetitions: Int,
        lastInterval: Int,
        now: Date = Date()
    ) -> SM2Result {
        let qv = Double(quality.rawValue)

        // 1. Новый EF рассчитываем ВСЕГДА (по классике SM-2 — даже при fail EF падает).
        var newEF = currentEF + (0.1 - (5 - qv) * (0.08 + (5 - qv) * 0.02))
        newEF = max(minimumEF, newEF)

        let newRepetitions: Int
        let rawInterval: Int

        if quality.isSuccessful {
            // Успех — продвигаемся по лестнице SM-2.
            newRepetitions = repetitions + 1
            switch newRepetitions {
            case 1:
                rawInterval = 1
            case 2:
                rawInterval = 6
            default:
                rawInterval = Int((Double(lastInterval) * newEF).rounded())
            }
        } else {
            // Провал — сбрасываем цепочку, повторяем завтра.
            newRepetitions = 0
            rawInterval = 1
        }

        // Адаптация: детям 5–8 лет нельзя давать забывать звук дольше 14 дней.
        var clampedInterval = min(max(1, rawInterval), maxIntervalDays)

        // При blackout / wrong принудительно возвращаемся на 1 день.
        if quality == .blackout || quality == .wrong {
            clampedInterval = 1
        }

        let nextDate = Calendar.current.date(
            byAdding: .day,
            value: clampedInterval,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(TimeInterval(clampedInterval) * 86_400)

        let specialistFlag = newEF < specialistReviewEFThreshold

        return SM2Result(
            intervalDays: clampedInterval,
            easinessFactor: newEF,
            repetitions: newRepetitions,
            nextReviewDate: nextDate,
            needsSpecialistReview: specialistFlag
        )
    }
}

// MARK: - SoundProgressState

/// Per-sound SM-2 state, агрегированный из истории сессий.
/// Codable — для сериализации в JSON (например, отчёт специалисту).
public struct SoundProgressState: Sendable, Codable, Equatable {

    /// Целевой звук, например "Р", "С".
    public let soundTarget: String
    /// Текущий этап коррекции.
    public let stage: CorrectionStage
    /// SM-2 easiness factor (>= 1.3).
    public let easinessFactor: Double
    /// Число успешных повторений подряд.
    public let repetitions: Int
    /// Интервал последнего успешного повторения (дни).
    public let lastIntervalDays: Int
    /// Дата последней сессии с этим звуком.
    public let lastReviewDate: Date?
    /// Процент правильных попыток за последние 10 attempts (0…1).
    public let successRate: Double
    /// Сколько подряд правильных попыток.
    public let consecutiveCorrect: Int
    /// Сколько подряд неправильных попыток — индикатор усталости / трудности.
    public let consecutiveWrong: Int
    /// Флаг «EF слишком низкий, рекомендуется логопед».
    public let needsSpecialistReview: Bool

    public init(
        soundTarget: String,
        stage: CorrectionStage,
        easinessFactor: Double = SM2Engine.defaultEF,
        repetitions: Int = 0,
        lastIntervalDays: Int = 0,
        lastReviewDate: Date? = nil,
        successRate: Double = 0,
        consecutiveCorrect: Int = 0,
        consecutiveWrong: Int = 0,
        needsSpecialistReview: Bool = false
    ) {
        self.soundTarget = soundTarget
        self.stage = stage
        self.easinessFactor = easinessFactor
        self.repetitions = repetitions
        self.lastIntervalDays = lastIntervalDays
        self.lastReviewDate = lastReviewDate
        self.successRate = successRate
        self.consecutiveCorrect = consecutiveCorrect
        self.consecutiveWrong = consecutiveWrong
        self.needsSpecialistReview = needsSpecialistReview
    }

    /// Сколько дней прошло с последнего повторения (nil — если ещё не было).
    public func daysSinceLastReview(now: Date = Date()) -> Int? {
        guard let last = lastReviewDate else { return nil }
        let calendar = Calendar.current
        let a = calendar.startOfDay(for: last)
        let b = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: a, to: b).day
    }

    /// Насколько звук «просрочен» для повтора.
    /// Отрицательный — ещё рано; 0 — пора сегодня; положительный — опоздание.
    public func overdueDays(now: Date = Date()) -> Int {
        guard let last = lastReviewDate else { return Int.max }
        let daysPassed = daysSinceLastReview(now: now) ?? 0
        return daysPassed - lastIntervalDays
    }
}

// MARK: - SoundProgressAggregator

/// Собирает `SoundProgressState` из истории сессий Realm (через DTO).
/// Чистая функциональная логика — без I/O.
public enum SoundProgressAggregator {

    /// Сформировать состояние по одному звуку из отсортированных сессий.
    /// Сессии должны быть отсортированы от новой к старой.
    public static func aggregate(
        soundTarget: String,
        sessions: [SessionDTO],
        now: Date = Date()
    ) -> SoundProgressState {
        let soundSessions = sessions.filter { $0.targetSound == soundTarget }

        guard !soundSessions.isEmpty else {
            // Звук ещё не отрабатывали — стартовые значения.
            return SoundProgressState(
                soundTarget: soundTarget,
                stage: .isolated
            )
        }

        // Последние 10 attempts (по всем сессиям этого звука, свежие первыми).
        let recentAttempts = soundSessions
            .flatMap(\.attempts)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(10)

        let recentArray = Array(recentAttempts)
        let correct = recentArray.filter(\.isCorrect).count
        let rate: Double = recentArray.isEmpty
            ? (soundSessions.first?.successRate ?? 0)
            : Double(correct) / Double(recentArray.count)

        // Consecutive streaks — от самого свежего attempt.
        var consecutiveCorrect = 0
        var consecutiveWrong = 0
        for attempt in recentArray {
            if attempt.isCorrect {
                if consecutiveWrong > 0 { break }
                consecutiveCorrect += 1
            } else {
                if consecutiveCorrect > 0 { break }
                consecutiveWrong += 1
            }
        }

        // Текущий этап — из последней сессии.
        let latestSession = soundSessions.max(by: { $0.date < $1.date })
        let stage = CorrectionStage(rawValue: latestSession?.stage ?? "") ?? .isolated

        // Проходим по сессиям от старой к новой, накапливая SM-2 state.
        let chronological = soundSessions.sorted { $0.date < $1.date }
        var ef = SM2Engine.defaultEF
        var reps = 0
        var interval = 0
        var lastReview: Date?

        for session in chronological {
            let quality = SM2Quality.fromSuccessRate(
                session.successRate,
                hadFatigue: session.fatigueDetected
            )
            let result = SM2Engine.calculate(
                quality: quality,
                currentEF: ef,
                repetitions: reps,
                lastInterval: max(1, interval),
                now: session.date
            )
            ef = result.easinessFactor
            reps = result.repetitions
            interval = result.intervalDays
            lastReview = session.date
        }

        return SoundProgressState(
            soundTarget: soundTarget,
            stage: stage,
            easinessFactor: ef,
            repetitions: reps,
            lastIntervalDays: interval,
            lastReviewDate: lastReview,
            successRate: rate,
            consecutiveCorrect: consecutiveCorrect,
            consecutiveWrong: consecutiveWrong,
            needsSpecialistReview: ef < SM2Engine.specialistReviewEFThreshold
        )
    }
}
