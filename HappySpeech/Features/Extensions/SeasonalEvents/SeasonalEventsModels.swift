import Foundation
import SwiftUI

// MARK: - SeasonalEventsModels
// Clean Swift: Request / Response / ViewModel для SeasonalEvents

// MARK: - SeasonalEvent

enum SeasonalEvent: String, CaseIterable, Sendable {

    case halloween
    case newYear
    case easter

    var activeMonths: [Int] {
        switch self {
        case .halloween: return [10, 11]
        case .newYear:   return [12, 1]
        case .easter:    return [3, 4, 5]
        }
    }

    var packId: String {
        switch self {
        case .halloween: return "pack_halloween"
        case .newYear:   return "pack_new_year"
        case .easter:    return "pack_easter"
        }
    }

    var localizedTitle: String {
        switch self {
        case .halloween: return String(localized: "seasonal.event.halloween")
        case .newYear:   return String(localized: "seasonal.event.new_year")
        case .easter:    return String(localized: "seasonal.event.easter")
        }
    }

    var iconName: String {
        switch self {
        case .halloween: return "moon.stars.fill"
        case .newYear:   return "sparkles"
        case .easter:    return "leaf.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .halloween: return ColorTokens.Brand.lilac
        case .newYear:   return ColorTokens.Brand.butter
        case .easter:    return ColorTokens.Brand.mint
        }
    }
}

// MARK: - SeasonalEvents.Request

enum SeasonalEventsRequest {
    struct LoadEvent {
        let date: Date
    }
    struct OverrideEvent {
        let event: SeasonalEvent?
    }
}

// MARK: - SeasonalEvents.Response

enum SeasonalEventsResponse {
    struct EventLoaded {
        let event: SeasonalEvent?
    }
}

// MARK: - SeasonalEventsViewModel

@Observable
final class SeasonalEventsViewModel {
    var activeEvent: SeasonalEvent?
    var isLoading: Bool = false
    var packLoaded: Bool = false
}
