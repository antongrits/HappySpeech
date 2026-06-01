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
        /// Отмечен ли как «повторил / получилось».
        var isPracticed: Bool
    }

    struct ViewState: Equatable {
        var samples: [SoundSample]
        var currentSampleId: String?
        var bestStars: Int = 0
        var isLoaded: Bool = false

        var practicedCount: Int { samples.filter(\.isPracticed).count }

        var isComplete: Bool {
            !samples.isEmpty && samples.allSatisfy(\.isPracticed)
        }

        /// Звёзды по доле отработанных образцов (мягко: завершение = максимум).
        var stars: Int {
            guard !samples.isEmpty else { return 0 }
            let ratio = Double(practicedCount) / Double(samples.count)
            switch ratio {
            case 1.0: return 3
            case 0.66..<1.0: return 2
            case 0.33..<0.66: return 1
            default: return 0
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
