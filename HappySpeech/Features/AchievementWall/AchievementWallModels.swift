import Foundation
import SwiftUI

// MARK: - AchievementWallModels
//
// «Стена достижений ребёнка» — большая визуальная mosaic-стена с
// разблокированными значками. Делится фотографией стены через share sheet.
//
// Контур: kid (просмотр) + parent (поделиться). Использует общий каталог
// `Achievement.allCases` — добавление новых достижений автоматически
// расширяет стену без правки этого экрана.

enum AchievementWallModels {

    // MARK: - LoadWall

    enum LoadWall {
        struct Request {
            let childId: String
        }

        struct Response {
            let childId: String
            let childName: String
            let childAge: Int
            let entries: [WallEntry]
            let totalUnlocked: Int
            let totalCount: Int
        }

        struct ViewModel {
            let heroTitle: String
            let heroSubtitle: String
            let cells: [AchievementWallCellViewModel]
            let accessibilitySummary: String
        }
    }

    // MARK: - OpenDetail

    enum OpenDetail {
        struct Request {
            let achievementId: String
        }

        struct Response {
            let entry: WallEntry
        }

        struct ViewModel {
            let title: String
            let description: String
            let iconName: String
            let isUnlocked: Bool
            let unlockedDateLabel: String?
            let mascotState: LyalyaState
            let tintColor: Color
            let accessibilityLabel: String
        }
    }

    // MARK: - Share

    enum Share {
        struct Request {
            let childName: String
        }

        struct Response {
            let shareText: String
        }

        struct ViewModel {
            let shareText: String
        }
    }
}

// MARK: - WallEntry

struct WallEntry: Sendable, Identifiable, Equatable {
    let achievement: Achievement
    let unlocked: Bool
    let unlockedDate: Date?

    var id: String { achievement.rawValue }
}

// MARK: - AchievementWallCellViewModel

struct AchievementWallCellViewModel: Identifiable, Sendable {
    let id: String
    let title: String
    let iconName: String
    let isUnlocked: Bool
    let rarity: AchievementRarity
    let accessibilityLabel: String
}
