import Foundation

// MARK: - FamilyChallengeModels
//
// Еженедельный челлендж всей семьи: общая цель в минутах практики,
// новых звуках или совместных играх. Виден всем родителям/детям,
// общий прогресс-бар + индивидуальные вклады.
//
// Контур: parent (управление) + kid (просмотр). Сейчас mock — Realm-схема
// будет добавлена в следующей итерации (CTO-decision-default).

enum FamilyChallengeModels {

    // MARK: - LoadChallenge

    enum LoadChallenge {
        struct Request {
            let parentId: String
        }

        struct Response {
            let challenge: FamilyChallengeDTO
            /// `true` если ребёнок (kid contour) — скрыть кнопки "Сменить челлендж".
            let isKidContext: Bool
        }

        struct ViewModel {
            let title: String
            let subtitle: String
            let iconSystemName: String
            let emojiTag: String
            let progressFraction: Double
            let progressLabel: String
            let goalLabel: String
            let contributions: [ContributionRowViewModel]
            let streakLabel: String
            let canManage: Bool
            let accessibilitySummary: String
        }
    }

    // MARK: - ClaimReward

    enum ClaimReward {
        struct Request {
            let challengeId: String
        }

        struct Response {
            let challengeId: String
            let confettiShown: Bool
        }

        struct ViewModel {
            let toastMessage: String
            let confettiShown: Bool
        }
    }

    // MARK: - ShareProgress

    enum ShareProgress {
        struct Request {
            let challengeId: String
        }

        struct Response {
            let shareText: String
        }

        struct ViewModel {
            let shareText: String
        }
    }
}

// MARK: - FamilyChallengeDTO

struct FamilyChallengeDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    let parentId: String
    let type: ChallengeType
    let goal: Int
    let current: Int
    let weekStart: Date
    let contributions: [Contribution]
    /// Сколько недель подряд семья закрывает челлендж — для streak-индикатора.
    let streakWeeks: Int

    var progressFraction: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(current) / Double(goal))
    }

    var isCompleted: Bool { current >= goal }
}

// MARK: - ChallengeType

enum ChallengeType: String, Sendable, CaseIterable {
    case totalMinutes
    case newSounds
    case coPlaySessions
    case fluencyDiaryEntries

    var unitLabel: String {
        switch self {
        case .totalMinutes:        return "мин"
        case .newSounds:           return "звуков"
        case .coPlaySessions:      return "игр"
        case .fluencyDiaryEntries: return "записей"
        }
    }

    var emoji: String {
        switch self {
        case .totalMinutes:        return "🏆"
        case .newSounds:           return "🎯"
        case .coPlaySessions:      return "🎮"
        case .fluencyDiaryEntries: return "📔"
        }
    }

    var iconSystemName: String {
        switch self {
        case .totalMinutes:        return "clock.badge.checkmark.fill"
        case .newSounds:           return "speaker.wave.3.fill"
        case .coPlaySessions:      return "person.2.fill"
        case .fluencyDiaryEntries: return "book.fill"
        }
    }

    var localizedTitle: String {
        switch self {
        case .totalMinutes:        return "Минуты вместе"
        case .newSounds:           return "Новые звуки"
        case .coPlaySessions:      return "Совместные игры"
        case .fluencyDiaryEntries: return "Записи дневника"
        }
    }
}

// MARK: - Contribution

struct Contribution: Sendable, Identifiable, Equatable {
    let id: String
    /// Имя участника — «Миша», «Папа», «Соня».
    let memberName: String
    /// Эмодзи рядом с именем — 🌟, 🎯, 👨.
    let memberEmoji: String
    /// Вклад в единицах челленджа.
    let value: Int
    /// Был ли это ребёнок (для accessibility / tinting).
    let isChild: Bool
}

// MARK: - ContributionRowViewModel

struct ContributionRowViewModel: Identifiable, Sendable {
    let id: String
    let label: String
    let valueLabel: String
    let progressFraction: Double
    let isChild: Bool
    let accessibilityLabel: String
}
