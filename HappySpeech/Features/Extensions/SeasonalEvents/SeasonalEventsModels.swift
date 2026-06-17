import Foundation
import SwiftUI

// MARK: - SeasonalEventsModels
// Доменная модель сезонного события: окно активности по дате, методический
// целевой звук тематической сессии и оформление баннера.

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

    /// Целевой звук тематической сессии события. Выбран по методике русской
    /// логопедии так, чтобы праздничная лексика реально тренировала группу:
    ///   * Хэллоуин → «Ш» (шипящие: шуршит, шорох, шипит, шляпа) — звукоподражание
    ///     осенне-страшной темы естественно изобилует шипящими.
    ///   * Новый год → «С» (свистящие: снег, снеговик, санки, сосулька) — зимняя
    ///     лексика концентрирует свистящие.
    ///   * Пасха → «К» (заднеязычные: кулич, краска, корзинка) — весенне-пасхальная
    ///     лексика опирается на заднеязычные.
    /// Эти группы реально наполнены словами с картинками в `word_manifest`, поэтому
    /// сессия открывает работающий word-picture контент, а не пустые слоты.
    var targetSound: String {
        switch self {
        case .halloween: return "Ш"
        case .newYear:   return "С"
        case .easter:    return "К"
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

    /// Максимальный день активного месяца, когда событие заканчивается.
    var endDayOfMonth: Int {
        switch self {
        case .halloween: return 2  // 2 ноября
        case .newYear:   return 20 // 20 января
        case .easter:    return 30 // конец апреля
        }
    }

    /// Конечная дата события (последний день в activeMonths.last).
    func endDate(relativeTo date: Date = Date()) -> Date? {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let endMonth = activeMonths.last ?? activeMonths[0]
        var comps = DateComponents()
        comps.year = year
        comps.month = endMonth
        comps.day = endDayOfMonth
        comps.hour = 23
        comps.minute = 59
        return cal.date(from: comps)
    }

    /// Количество оставшихся дней до конца события (0 если последний день).
    func daysRemaining(from date: Date = Date()) -> Int {
        guard let end = endDate(relativeTo: date) else { return 0 }
        let diff = Calendar.current.dateComponents([.day], from: date, to: end)
        return max(0, diff.day ?? 0)
    }

    /// Цель по звёздным очкам события.
    var starGoal: Int { 10 }
}
