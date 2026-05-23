import Foundation
import SwiftUI

// MARK: - AchievementWallPresentationLogic

@MainActor
protocol AchievementWallPresentationLogic: AnyObject {
    func presentWall(response: AchievementWallModels.LoadWall.Response) async
    func presentDetail(response: AchievementWallModels.OpenDetail.Response) async
    func presentShare(response: AchievementWallModels.Share.Response) async
}

// MARK: - AchievementWallPresenter

@MainActor
final class AchievementWallPresenter: AchievementWallPresentationLogic {

    weak var displayLogic: (any AchievementWallDisplayLogic)?

    init(displayLogic: any AchievementWallDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Wall

    func presentWall(response: AchievementWallModels.LoadWall.Response) async {
        let heroTitle = "\(response.childName), \(response.childAge) лет"
        let heroSubtitle = "\(response.totalUnlocked) / \(response.totalCount) наград"
        let cells = response.entries.map { entry in
            AchievementWallCellViewModel(
                id: entry.id,
                title: entry.achievement.localizedTitle,
                iconName: entry.achievement.iconName,
                isUnlocked: entry.unlocked,
                rarity: entry.achievement.rarity,
                accessibilityLabel: makeCellA11y(entry: entry)
            )
        }
        let summary = "Моя стена. \(heroSubtitle)."

        let viewModel = AchievementWallModels.LoadWall.ViewModel(
            heroTitle: heroTitle,
            heroSubtitle: heroSubtitle,
            cells: cells,
            accessibilitySummary: summary
        )
        await displayLogic?.displayWall(viewModel: viewModel)
    }

    // MARK: - Detail

    func presentDetail(response: AchievementWallModels.OpenDetail.Response) async {
        let entry = response.entry
        let dateLabel: String? = entry.unlockedDate.map { date in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return "Получено: \(formatter.string(from: date))"
        }
        let tint = tintForRarity(entry.achievement.rarity)
        let mascotState: LyalyaState = entry.unlocked ? .celebrating : .thinking

        let viewModel = AchievementWallModels.OpenDetail.ViewModel(
            title: entry.achievement.localizedTitle,
            description: entry.achievement.localizedDescription,
            iconName: entry.achievement.iconName,
            isUnlocked: entry.unlocked,
            unlockedDateLabel: dateLabel,
            mascotState: mascotState,
            tintColor: tint,
            accessibilityLabel: makeDetailA11y(entry: entry)
        )
        await displayLogic?.displayDetail(viewModel: viewModel)
    }

    // MARK: - Share

    func presentShare(response: AchievementWallModels.Share.Response) async {
        let viewModel = AchievementWallModels.Share.ViewModel(shareText: response.shareText)
        await displayLogic?.displayShare(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func tintForRarity(_ rarity: AchievementRarity) -> Color {
        switch rarity {
        case .legendary: return ColorTokens.Brand.gold
        case .rare:      return ColorTokens.Brand.lilac
        case .common:    return ColorTokens.Brand.sky
        }
    }

    private func makeCellA11y(entry: WallEntry) -> String {
        if entry.unlocked {
            return "\(entry.achievement.localizedTitle), получено"
        }
        return "\(entry.achievement.localizedTitle), не получено"
    }

    private func makeDetailA11y(entry: WallEntry) -> String {
        if entry.unlocked {
            return "\(entry.achievement.localizedTitle). \(entry.achievement.localizedDescription). Получено."
        }
        return "\(entry.achievement.localizedTitle). \(entry.achievement.localizedDescription). Ещё не получено."
    }
}
