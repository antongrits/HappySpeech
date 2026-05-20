import Foundation

// MARK: - LogorhythmicsModels
//
// v31 Wave F Ф.7 — «Логоритмика» (Volkova / Kartushina).
//
// Ребёнок видит chant из 4–8 строк, метроном задаёт темп, ребёнок
// топает/хлопает в такт. CMMotionManager детектит тапы по пикам второй
// производной вертикального ускорения; BeatScorer считает F1 совпадения
// detected vs expected beats (окно ±150 ms).
//
// Корпус: `pack_logorhythmics.json` (12 chants — Картушина, приближение
// по слогам, см. `patternSource` в JSON).
//
// Контур: kid. Возраст 5–8 лет. Уровень: 1–3.

enum LogorhythmicsModels {

    // MARK: - LoadExercises (стартовый экран — выбор chant)

    enum LoadExercises {

        struct Response {
            let exercises: [LogorhythmicsExercise]
        }

        struct ViewModel {
            /// category → упражнения.
            let grouped: [String: [LogorhythmicsExercise]]
            let categoriesInOrder: [String]
            let categoryTitles: [String: String]
        }
    }

    // MARK: - SelectExercise (ребёнок выбрал chant — переход в playing)

    enum SelectExercise {

        struct Response {
            let exerciseId: String
        }

        struct ViewModel {
            let exercise: LogorhythmicsExercise
            let totalBeats: Int
            /// Длительность одного beat в секундах (60/BPM).
            let beatDurationSeconds: Double
            /// Подсказка над экраном — «Топай в такт!» / «Хлопай!».
            let hintMessage: String
        }
    }

    // MARK: - BeatTick (каждый beat-tick из метронома → пульс на View)

    enum BeatTick {

        struct Response {
            /// Индекс beat'а (0…totalBeats-1).
            let beatIndex: Int
            /// Сильная ли это доля.
            let isStrong: Bool
        }

        struct ViewModel {
            let beatIndex: Int
            let totalBeats: Int
            let isStrong: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: - FinishExercise (после N бaров — итог)

    enum FinishExercise {

        struct Response {
            let exercise: LogorhythmicsExercise
            let score: ExerciseScore
        }

        struct ViewModel {
            let exercise: LogorhythmicsExercise
            let stars: Int
            /// F1 в процентах (0…100).
            let f1Percent: Int
            /// «Точных попаданий: 9 из 12».
            let hitsLabel: String
            /// «Опоздал: 2», «Пропустил: 1».
            let detailLabel: String
            /// Локализованный fb-title.
            let feedbackTitle: String
            /// Локализованный fb-body.
            let feedbackBody: String
            let accessibilityLabel: String
        }
    }
}

// MARK: - LogorhythmicsExercise

/// Одно chant-упражнение из пака.
struct LogorhythmicsExercise: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    /// Минимальный рекомендованный возраст (5/6/7).
    let ageMin: Int
    /// «топот» | «хлопок» | «качание».
    let category: String
    /// Темп в ударах в минуту (60–120).
    let bpm: Int
    /// Источник паттерна — `approximation_by_syllables`.
    let patternSource: String
    /// Слоги в порядке прозноcа.
    let syllables: [String]
    /// Длительность каждой доли в quarter-notes (1 = четверть, 2 = половинка).
    /// Длина == syllables.count.
    let pattern: [Int]
    /// Индексы сильных долей (для повышения тона клика).
    let strongBeats: [Int]
    /// Многострочный текст рифмы для отображения на экране.
    let rhymeText: String

    /// Общее число beats — сумма pattern.
    var totalBeats: Int { pattern.reduce(0, +) }

    /// Длительность beat'а (секунды) при текущем BPM.
    var beatDurationSeconds: Double {
        guard bpm > 0 else { return 1.0 }
        return 60.0 / Double(bpm)
    }
}

// MARK: - ExerciseScore

/// Итог упражнения. Все поля — out-of-band, не пишутся в Realm на этой
/// итерации (CTO-decision-default Wave F Ф.7).
struct ExerciseScore: Sendable, Equatable {
    /// Expected beats — сколько beat'ов должно было прозвучать.
    let expectedBeats: Int
    /// Detected taps — сколько тапов засёк CMMotionManager.
    let detectedTaps: Int
    /// Hits — пары (expected, detected) в окне ±tolerance.
    let hits: Int
    /// Misses — expected beats без пары.
    let misses: Int
    /// Extras — detected taps без пары (лишние).
    let extras: Int
    /// Precision = hits / (hits + extras).
    let precision: Double
    /// Recall = hits / (hits + misses).
    let recall: Double
    /// F1 = 2 * precision * recall / (precision + recall).
    let f1: Double
}

// MARK: - BeatEvent / TapEvent (вспомогательные типы для BeatScorer)

/// Один ожидаемый beat в timeline'е (от старта упражнения).
struct ExpectedBeat: Sendable, Equatable {
    /// Индекс beat'а.
    let index: Int
    /// Время от старта упражнения (секунды).
    let timeSeconds: Double
    /// Сильная ли доля.
    let isStrong: Bool
}

/// Один задетектированный тап (от старта упражнения).
struct DetectedTap: Sendable, Equatable {
    /// Время от старта упражнения (секунды).
    let timeSeconds: Double
}
