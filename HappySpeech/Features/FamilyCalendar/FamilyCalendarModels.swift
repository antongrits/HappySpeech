import Foundation

// MARK: - FamilyCalendar Models (Request / Response / ViewModel)
//
// Parent-контур. Семейный календарь — агрегированная статистика по всем детям семьи.
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

// MARK: - Requests

enum FamilyCalendarRequest {
    struct LoadData {
        let parentId: String
    }
    struct SelectChild {
        let childId: String?   // nil = «Все»
    }
    struct ChangeMonth {
        let direction: MonthDirection
        enum MonthDirection { case previous, next }
    }
    struct SelectDay {
        let date: Date
    }
    struct GenerateComparison {
        let leftChildId: String
        let rightChildId: String
    }
}

// MARK: - Responses

enum FamilyCalendarResponse {
    struct DataLoaded {
        let children: [ChildProfileDTO]
        let sessions: [SessionDTO]
        let selectedChildId: String?
        let currentMonth: Date
    }
    struct ChildSelected {
        let childId: String?
        let children: [ChildProfileDTO]
        let sessions: [SessionDTO]
        let currentMonth: Date
    }
    struct MonthChanged {
        let newMonth: Date
        let sessions: [SessionDTO]
        let selectedChildId: String?
        let children: [ChildProfileDTO]
    }
    struct DaySelected {
        let date: Date
        let sessions: [SessionDTO]
        let children: [ChildProfileDTO]
    }
    struct InsightsGenerated {
        let insights: [InsightItem]
    }
    struct ErrorOccurred {
        let message: String
    }
}

// MARK: - Domain Types

struct InsightItem: Identifiable, Sendable {
    let id: UUID
    let iconName: String
    let text: String

    init(id: UUID = UUID(), iconName: String, text: String) {
        self.id = id
        self.iconName = iconName
        self.text = text
    }
}

struct FamilyStatsAggregation: Sendable {
    let childId: String
    let childName: String
    let streak: Int
    let totalSessions: Int
    let avgSuccessRate: Double
    let bestSound: String?
    let bestSoundRate: Double
    let dayActivities: [Date: Int]   // date → sessionCount
    let heatmapEntries: [HeatmapEntry]
}

struct HeatmapEntry: Sendable, Identifiable {
    let id: UUID
    let weekIndex: Int    // 0 = самая старая, 11 = текущая
    let weekday: Int      // 0 = Пн, 6 = Вс
    let sessionCount: Int
    let date: Date

    init(id: UUID = UUID(), weekIndex: Int, weekday: Int, sessionCount: Int, date: Date) {
        self.id = id
        self.weekIndex = weekIndex
        self.weekday = weekday
        self.sessionCount = sessionCount
        self.date = date
    }
}

// MARK: - ViewModels

struct FamilyCalendarViewModel: Equatable {
    var children: [ChildAvatarViewModel]
    var selectedChildId: String?
    var currentMonth: Date
    var calendarDays: [CalendarDayViewModel]
    var heatmapEntries: [HeatmapEntryViewModel]
    var comparisonCards: [ChildSummaryViewModel]
    var insights: [InsightItemViewModel]
    var isLoading: Bool
    var isLoadingInsights: Bool
    var toastMessage: String?
    var isEmpty: Bool
    var selectedDayDetail: DayDetailViewModel?

    static let empty = FamilyCalendarViewModel(
        children: [],
        selectedChildId: nil,
        currentMonth: Date(),
        calendarDays: [],
        heatmapEntries: [],
        comparisonCards: [],
        insights: [],
        isLoading: true,
        isLoadingInsights: false,
        toastMessage: nil,
        isEmpty: true,
        selectedDayDetail: nil
    )
}

struct ChildAvatarViewModel: Identifiable, Equatable {
    let id: String
    let name: String
    let initials: String
    let avatarStyle: String
    let streak: Int
    let isAll: Bool         // специальный элемент «Все»
}

struct CalendarDayViewModel: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let dayNumber: Int
    let sessionCount: Int
    let isToday: Bool
    let isCurrentMonth: Bool
    let isFuture: Bool
    let activityLevel: Int  // 0–4: 0=нет, 1=1-3, 2=4-6, 3=7+, 4=сегодня-активен

    init(
        id: UUID = UUID(),
        date: Date,
        dayNumber: Int,
        sessionCount: Int,
        isToday: Bool,
        isCurrentMonth: Bool,
        isFuture: Bool,
        activityLevel: Int
    ) {
        self.id = id
        self.date = date
        self.dayNumber = dayNumber
        self.sessionCount = sessionCount
        self.isToday = isToday
        self.isCurrentMonth = isCurrentMonth
        self.isFuture = isFuture
        self.activityLevel = activityLevel
    }
}

struct HeatmapEntryViewModel: Identifiable, Equatable {
    let id: UUID
    let weekIndex: Int
    let weekday: Int
    let sessionCount: Int
    let date: Date
    let label: String   // «Пн 14 апр»

    init(id: UUID = UUID(), weekIndex: Int, weekday: Int, sessionCount: Int, date: Date, label: String) {
        self.id = id
        self.weekIndex = weekIndex
        self.weekday = weekday
        self.sessionCount = sessionCount
        self.date = date
        self.label = label
    }
}

struct ChildSummaryViewModel: Identifiable, Equatable {
    let id: String
    let name: String
    let initials: String
    let avatarStyle: String
    let bestSound: String
    let bestSoundRate: Double
    let comparisonDelta: Double?   // vs. семейное среднее, nil если единственный ребёнок
    let isLeader: Bool
}

struct InsightItemViewModel: Identifiable, Equatable {
    let id: UUID
    let iconName: String
    let text: String

    init(id: UUID = UUID(), iconName: String, text: String) {
        self.id = id
        self.iconName = iconName
        self.text = text
    }
}

struct DayDetailViewModel: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let dateText: String
    let sessionItems: [DaySessionItem]
    let isEmpty: Bool

    init(id: UUID = UUID(), date: Date, dateText: String, sessionItems: [DaySessionItem], isEmpty: Bool) {
        self.id = id
        self.date = date
        self.dateText = dateText
        self.sessionItems = sessionItems
        self.isEmpty = isEmpty
    }
}

struct DaySessionItem: Identifiable, Equatable {
    let id: UUID
    let childName: String
    let sessionCount: Int
    let accuracyPercent: Int

    init(id: UUID = UUID(), childName: String, sessionCount: Int, accuracyPercent: Int) {
        self.id = id
        self.childName = childName
        self.sessionCount = sessionCount
        self.accuracyPercent = accuracyPercent
    }
}
