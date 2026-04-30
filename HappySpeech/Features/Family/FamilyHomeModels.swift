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

    func avatarEmoji(for child: FamilyHome.ChildSummary) -> String {
        switch child.avatarStyle {
        case "butterfly":  return "🦋"
        case "star":       return "⭐"
        case "rocket":     return "🚀"
        case "dragon":     return "🐉"
        case "unicorn":    return "🦄"
        default:           return "🧒"
        }
    }
}
