import Foundation
import SwiftUI

// MARK: - FamilyHome VIP Models

enum FamilyHome {

    // MARK: - Requests

    struct LoadRequest {}

    struct SelectChildRequest {
        let childId: String
    }

    struct AddChildRequest {}

    // MARK: - Responses

    struct LoadResponse {
        let children: [ChildSummary]
        let parentName: String
    }

    // MARK: - Domain types

    struct ChildSummary: Identifiable, Sendable {
        let id: String
        let name: String
        let age: Int
        let avatarStyle: String
        let colorTheme: String
        let currentStreak: Int
        let targetSounds: [String]
        let overallProgress: Double
        let lastSessionAt: Date?
    }
}

// MARK: - FamilyHomeViewModel

@Observable
@MainActor
final class FamilyHomeViewModel {
    var children: [FamilyHome.ChildSummary] = []
    var parentName: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    var greeting: String {
        if parentName.isEmpty {
            return String(localized: "family.home.greeting.default")
        }
        return String(format: String(localized: "family.home.greeting"), parentName)
    }

    var hasMultipleChildren: Bool { children.count > 1 }

    func themeColor(for child: FamilyHome.ChildSummary) -> Color {
        switch child.colorTheme {
        case "blue":    return ColorTokens.Brand.sky
        case "green":   return ColorTokens.Brand.mint
        case "yellow":  return ColorTokens.Brand.butter
        case "purple":  return ColorTokens.Brand.lilac
        default:        return ColorTokens.Brand.primary
        }
    }

    /// D-14 v27: имя нейтральной аватар-иллюстрации (звери) из Assets.xcassets.
    /// Legacy-стили (star/rocket/dragon/unicorn) маппятся на зверей, чтобы не
    /// показывать reward-бейджи как аватар ребёнка.
    func avatarIllustrationName(for child: FamilyHome.ChildSummary) -> String {
        switch child.avatarStyle {
        case "butterfly":          return "mascot_lyalya_wave"
        case "cat", "star":        return "word_cat"
        case "fox", "rocket":      return "word_fox"
        case "bear", "dragon":     return "word_bear"
        case "frog", "unicorn":    return "word_frog"
        default:                   return "mascot_lyalya_wave"
        }
    }
}
