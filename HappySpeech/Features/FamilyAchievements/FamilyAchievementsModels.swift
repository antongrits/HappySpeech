import Foundation

// MARK: - FamilyAchievementsModels (Clean Swift: Models)
//
// Block R.4 v18 — Family Achievements Screen.
//
// Сущности фичи:
//   • FamilyAchievement — общее семейное достижение (combined progress)
//   • FamilyMemberSummary — краткая сводка по члену семьи (parent или child)
//   • FamilyStreakState — стрик «все дети активны N дней подряд»
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: UserDefaults (per-family).
// COPPA: дети представлены только агрегатами (имя + возраст + summary stats),
// никаких raw audio / personal data в shared family view.

// MARK: - FamilyAchievement

/// Семейное достижение — общая цель, достижимая совместно.
public struct FamilyAchievement: Identifiable, Sendable, Hashable {

    public let id: String
    public let titleKey: String
    public let descriptionKey: String
    public let symbolName: String
    public let totalRequired: Int
    public let category: Category

    public enum Category: String, Sendable {
        case streak       // совместный стрик активности
        case sounds       // освоено N звуков всеми детьми
        case sessions     // суммарно X занятий
        case milestone    // ключевая веха (1 месяц, 100 дней)
        case bonus        // бонусное достижение (вместе с родителем)
    }

    public var symbolColor: String {
        switch category {
        case .streak:    return "flame"
        case .sounds:    return "waveform"
        case .sessions:  return "graduationcap"
        case .milestone: return "rosette"
        case .bonus:     return "gift"
        }
    }

    public static let catalog: [FamilyAchievement] = [
        .init(
            id: "fam.streak.7",
            titleKey: "family.ach.streak7.title",
            descriptionKey: "family.ach.streak7.description",
            symbolName: "flame.fill",
            totalRequired: 7,
            category: .streak
        ),
        .init(
            id: "fam.streak.30",
            titleKey: "family.ach.streak30.title",
            descriptionKey: "family.ach.streak30.description",
            symbolName: "flame.circle.fill",
            totalRequired: 30,
            category: .streak
        ),
        .init(
            id: "fam.sounds.5",
            titleKey: "family.ach.sounds5.title",
            descriptionKey: "family.ach.sounds5.description",
            symbolName: "waveform.path",
            totalRequired: 5,
            category: .sounds
        ),
        .init(
            id: "fam.sessions.50",
            titleKey: "family.ach.sessions50.title",
            descriptionKey: "family.ach.sessions50.description",
            symbolName: "graduationcap.fill",
            totalRequired: 50,
            category: .sessions
        ),
        .init(
            id: "fam.sessions.100",
            titleKey: "family.ach.sessions100.title",
            descriptionKey: "family.ach.sessions100.description",
            symbolName: "rosette",
            totalRequired: 100,
            category: .milestone
        ),
        .init(
            id: "fam.bonus.parent",
            titleKey: "family.ach.bonusParent.title",
            descriptionKey: "family.ach.bonusParent.description",
            symbolName: "person.2.fill",
            totalRequired: 1,
            category: .bonus
        )
    ]

    public static func find(id: String) -> FamilyAchievement? {
        catalog.first { $0.id == id }
    }
}

// MARK: - FamilyMemberSummary

/// Краткая сводка по одному ребёнку семьи.
public struct FamilyMemberSummary: Identifiable, Sendable {
    public let id: String              // childId
    public let displayName: String
    public let age: Int
    public let avatarSymbol: String
    public let currentStreak: Int
    public let totalSessions: Int
    public let masteredSounds: [String]
    public let isActive: Bool
}

// MARK: - FamilyStreakState

/// Стрик «все активны».
public struct FamilyStreakState: Sendable, Equatable {
    public let combinedDays: Int          // сколько дней подряд все дети были активны
    public let allActiveToday: Bool       // все ли дети были активны сегодня
    public let totalMembers: Int
    public let activeTodayCount: Int
}

// MARK: - FamilyAchievementsModels namespace

enum FamilyAchievementsModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let familyId: String
        }

        struct Response: Sendable {
            let achievements: [FamilyAchievement]
            let unlockedIds: Set<String>
            let progressById: [String: Int]
            let members: [FamilyMemberSummary]
            let streakState: FamilyStreakState
        }

        struct ViewModel: Sendable {
            let streakHero: StreakHeroViewModel
            let memberRows: [MemberRow]
            let achievements: [AchievementRow]
            let summary: SummaryRow
        }

        struct StreakHeroViewModel: Sendable {
            let combinedDays: Int
            let activeLabel: String          // «3/3 активны сегодня»
            let allActiveToday: Bool
            let titleLabel: String
            let subtitleLabel: String
            let progressFraction: Double     // 0..1
        }

        struct MemberRow: Identifiable, Sendable {
            let id: String
            let name: String
            let ageLabel: String
            let avatarSymbol: String
            let streakLabel: String
            let masteredSoundsLabel: String
            let isActiveToday: Bool
            let accessibilityLabel: String
        }

        struct AchievementRow: Identifiable, Sendable {
            let id: String
            let title: String
            let description: String
            let symbolName: String
            let isUnlocked: Bool
            let progressLabel: String         // «3/7»
            let progressFraction: Double      // 0..1
            let categoryLabel: String
            let accessibilityLabel: String
        }

        struct SummaryRow: Sendable {
            let totalSessionsLabel: String
            let totalMasteredSoundsLabel: String
            let unlockedCount: Int
            let totalCount: Int
        }
    }

    // MARK: Recompute

    enum Recompute {

        struct Request: Sendable {
            let familyId: String
        }

        struct Response: Sendable {
            let newUnlockedIds: Set<String>
        }

        struct ViewModel: Sendable {
            let toastMessage: String?
            let unlockedAchievementsTitles: [String]
        }
    }
}
