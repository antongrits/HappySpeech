import Foundation

// MARK: - ImitationLabModels

/// Модели «Лаборатории подражания» (шаблон articulation-imitation: слушай →
/// повтори → отметь).
///
/// Образцы звукоподражаний берутся из `ImitationLabContent` и отбираются под
/// рабочие звуки ребёнка. Ребёнок слушает образец, повторяет вслух и отмечает
/// «получилось»; отработанные образцы идут в outcome планировщика.
enum ImitationLabModels {

    struct SoundSample: Identifiable, Hashable {
        let id: String
        let emoji: String
        let name: String
        let onomatopoeia: String
        /// Группа звука, который тренирует образец («С», «Ж», «Р» …).
        let soundFamily: String
        /// Прослушан ли образец.
        var isPlayed: Bool
        /// Отработан ли образец (ребёнок повторил вслух и попытка засчитана).
        var isPracticed: Bool
        /// Реальная оценка произношения попытки `[0...1]` (ML-скорер + ASR).
        /// `nil`, пока образец не отработан или не было входного сигнала.
        var score: Float?
        /// Засчитан ли образец как удачный (произношение прошло порог).
        var didPass: Bool = false
    }

    struct ViewState: Equatable {
        var samples: [SoundSample]
        var currentSampleId: String?
        var bestStars: Int = 0
        var isLoaded: Bool = false

        var practicedCount: Int { samples.filter(\.isPracticed).count }

        /// Образцы, произношение которых реально прошло порог.
        var passedCount: Int { samples.filter(\.didPass).count }

        var isComplete: Bool {
            !samples.isEmpty && samples.allSatisfy(\.isPracticed)
        }

        /// Звёзды по реальному среднему баллу произношения отработанных образцов.
        /// Если ни одной засчитанной попытки с баллом нет — 0 (никаких звёзд за
        /// молчание / отказ микрофона).
        var stars: Int {
            let scored = samples.compactMap(\.score)
            guard !scored.isEmpty else { return 0 }
            let average = scored.reduce(0, +) / Float(scored.count)
            switch average {
            case 0.8...:      return 3
            case 0.6..<0.8:   return 2
            case 0.4..<0.6:   return 1
            default:          return 0
            }
        }

        static let empty = ViewState(samples: [], currentSampleId: nil)

        static let initial = ViewState(
            samples: ImitationLabContent.samples(forTargetSounds: []),
            currentSampleId: nil,
            isLoaded: true
        )
    }
}
