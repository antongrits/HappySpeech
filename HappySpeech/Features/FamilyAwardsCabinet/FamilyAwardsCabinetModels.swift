import Foundation
import SwiftUI

// MARK: - FamilyAwardsCabinetModels (Clean Swift: Models)
//
// Block AE batch 2 v21 — 3D витрина наград семьи.
//
// Цель: показать «кабинет с трофеями» — все награды детей семьи в одном месте,
// сгруппированные по трём полкам (платина / золото / бронза). На iOS 18+
// рендерится через `RealityView` с примитивами `ModelEntity.box(...)`,
// на iOS 17 — 2D fallback с slot-карточками.
//
// Источники данных:
//   • ChildRepository → перечень детей семьи
//   • AchievementsRepository (через AppContainer) ИЛИ
//     детерминированный seed-список (для AE batch 2 v21, поскольку реальный
//     achievements-репозиторий читается из Realm/Firestore и здесь не критично
//     к скоупу — нужен deterministic preview).

// MARK: - AwardTier

public enum AwardTier: String, CaseIterable, Sendable, Equatable {
    case platinum
    case gold
    case silver
    case bronze

    public var titleKey: String {
        switch self {
        case .platinum: return "familyAwardsCabinet.tier.platinum"
        case .gold:     return "familyAwardsCabinet.tier.gold"
        case .silver:   return "familyAwardsCabinet.tier.silver"
        case .bronze:   return "familyAwardsCabinet.tier.bronze"
        }
    }

    /// Цвет «материала» полки/трофея в RealityView fallback.
    public var displayColor: Color {
        switch self {
        case .platinum: return ColorTokens.Award.platinum
        case .gold:     return ColorTokens.Brand.gold
        case .silver:   return ColorTokens.Award.silver
        case .bronze:   return ColorTokens.Badge.bronze
        }
    }

    public var rank: Int {
        switch self {
        case .platinum: return 4
        case .gold:     return 3
        case .silver:   return 2
        case .bronze:   return 1
        }
    }
}

// MARK: - FamilyAward

public struct FamilyAward: Sendable, Equatable, Identifiable, Hashable {
    public let id: String              // uuid
    public let childId: String
    public let childName: String
    public let tier: AwardTier
    public let titleKey: String        // локализованный ключ
    public let unlockedDate: Date
    public let symbolName: String      // SF Symbol — fallback и иконка над 3D кубом

    public init(
        id: String,
        childId: String,
        childName: String,
        tier: AwardTier,
        titleKey: String,
        unlockedDate: Date,
        symbolName: String
    ) {
        self.id = id
        self.childId = childId
        self.childName = childName
        self.tier = tier
        self.titleKey = titleKey
        self.unlockedDate = unlockedDate
        self.symbolName = symbolName
    }
}

// MARK: - AwardsCabinetSeed

/// Детерминированный seed-список наград — заполняется на основе streak/прогресса
/// детей. В AE batch 2 v21 фиксированный набор; в будущем — из репозитория Realm.
public enum AwardsCabinetSeed {

    /// 8 потенциальных наград, которые могут быть разблокированы детьми семьи.
    /// `predicate` — функция оценки, разблокирована ли награда для конкретного ребёнка.
    public static let catalog: [(titleKey: String, tier: AwardTier, symbol: String,
                                 predicate: @Sendable (ChildProfileDTO) -> Bool)] = [
        (
            titleKey: "familyAwardsCabinet.award.first_session",
            tier: .bronze,
            symbol: "1.circle.fill",
            predicate: { $0.totalSessionMinutes >= 1 }
        ),
        (
            titleKey: "familyAwardsCabinet.award.streak_3",
            tier: .bronze,
            symbol: "flame.fill",
            predicate: { $0.currentStreak >= 3 }
        ),
        (
            titleKey: "familyAwardsCabinet.award.streak_7",
            tier: .silver,
            symbol: "flame.fill",
            predicate: { $0.currentStreak >= 7 }
        ),
        (
            titleKey: "familyAwardsCabinet.award.streak_14",
            tier: .gold,
            symbol: "flame.circle.fill",
            predicate: { $0.currentStreak >= 14 }
        ),
        (
            titleKey: "familyAwardsCabinet.award.streak_30",
            tier: .platinum,
            symbol: "flame.circle.fill",
            predicate: { $0.currentStreak >= 30 }
        ),
        (
            titleKey: "familyAwardsCabinet.award.minutes_60",
            tier: .silver,
            symbol: "clock.badge.checkmark.fill",
            predicate: { $0.totalSessionMinutes >= 60 }
        ),
        (
            titleKey: "familyAwardsCabinet.award.minutes_180",
            tier: .gold,
            symbol: "hourglass.bottomhalf.filled",
            predicate: { $0.totalSessionMinutes >= 180 }
        ),
        (
            titleKey: "familyAwardsCabinet.award.minutes_600",
            tier: .platinum,
            symbol: "star.square.on.square.fill",
            predicate: { $0.totalSessionMinutes >= 600 }
        )
    ]

    /// Собирает все «выигранные» награды для списка детей.
    public static func unlocked(for children: [ChildProfileDTO]) -> [FamilyAward] {
        var awards: [FamilyAward] = []
        for child in children {
            for entry in catalog where entry.predicate(child) {
                awards.append(FamilyAward(
                    id: "\(child.id)-\(entry.titleKey)",
                    childId: child.id,
                    childName: child.name,
                    tier: entry.tier,
                    titleKey: entry.titleKey,
                    unlockedDate: child.lastSessionAt ?? child.createdAt,
                    symbolName: entry.symbol
                ))
            }
        }
        return awards
    }
}

// MARK: - FamilyAwardsCabinetModels namespace

enum FamilyAwardsCabinetModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let parentId: String   // ID родителя — для будущего разреза семей
        }

        struct Response: Sendable {
            let shelves: [ShelfBucket]
            let totalAwards: Int
            let totalChildren: Int
        }

        struct ShelfBucket: Sendable, Equatable, Identifiable {
            var id: String { tier.rawValue }
            let tier: AwardTier
            let awards: [FamilyAward]
        }

        struct ViewModel: Sendable {
            let heroTitle: String
            let heroSubtitle: String
            let shelves: [ShelfViewModel]
            let cabinetIsEmpty: Bool
            let emptyTitle: String
            let emptySubtitle: String
        }

        struct ShelfViewModel: Sendable, Identifiable, Equatable {
            var id: String { tierRaw }
            let tierRaw: String          // AwardTier.rawValue
            let tierTitle: String
            let tierColorName: String    // raw — View маппит на displayColor
            let trophyCount: Int
            let trophyCountLabel: String
            let trophies: [TrophyViewModel]
        }

        struct TrophyViewModel: Sendable, Identifiable, Equatable {
            let id: String
            let title: String
            let childName: String
            let dateLabel: String
            let symbolName: String
            let accessibilityLabel: String
        }
    }

    // MARK: SelectAward

    enum SelectAward {
        struct Request: Sendable {
            let awardId: String
        }

        struct Response: Sendable {
            let award: FamilyAward
        }

        struct ViewModel: Sendable {
            let title: String
            let subtitle: String       // «<имя ребёнка> · <дата>»
            let tierTitle: String
            let symbolName: String
            let detail: String         // мотивирующее описание
        }
    }
}
