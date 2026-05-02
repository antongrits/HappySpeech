import Foundation

// MARK: - FamilyCalendar Models (Request / Response / ViewModel)
//
// Parent-контур. Семейный календарь с недельным планированием, многодетным
// режимом, целями, повторяющимися расписаниями и визитами к специалисту.
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

    struct ChangeWeek {
        let direction: WeekDirection
        enum WeekDirection { case previous, next }
    }

    struct SelectDay {
        let date: Date
    }

    struct GenerateComparison {
        let leftChildId: String
        let rightChildId: String
    }

    struct ScheduleLesson {
        let childId: String
        let childName: String
        let date: Date
        let lessonTemplate: String
        let enableReminder: Bool
    }

    struct AddRecurringPlan {
        let childId: String
        let weekday: Int   // 0=Пн … 6=Вс
        let hour: Int
        let minute: Int
        let lessonTemplate: String
    }

    struct RemoveRecurringPlan {
        let planId: String
    }

    struct SetWeeklyGoal {
        let childId: String
        let sessionsPerWeek: Int
    }

    struct AddSpecialistVisit {
        let childId: String
        let childName: String
        let date: Date
        let specialistName: String
        let notes: String
        let requestReport: Bool
        let enableReminder: Bool
    }

    struct RemovePlannedSession {
        let sessionId: String
    }

    struct GenerateWeekSummary {
        let weekStart: Date
    }
}

// MARK: - Responses

enum FamilyCalendarResponse {

    struct DataLoaded {
        let children: [ChildProfileDTO]
        let sessions: [SessionDTO]
        let selectedChildId: String?
        let currentMonth: Date
        let weekOffset: Int
        let weeklyGoals: [String: Int]
        let plannedSessions: [PlannedSession]
        let recurringPlans: [RecurringPlan]
        let specialistVisits: [SpecialistVisit]
    }

    struct ChildSelected {
        let childId: String?
        let children: [ChildProfileDTO]
        let sessions: [SessionDTO]
        let currentMonth: Date
        let weekOffset: Int
        let weeklyGoals: [String: Int]
        let plannedSessions: [PlannedSession]
        let recurringPlans: [RecurringPlan]
        let specialistVisits: [SpecialistVisit]
    }

    struct MonthChanged {
        let newMonth: Date
        let sessions: [SessionDTO]
        let selectedChildId: String?
        let children: [ChildProfileDTO]
    }

    struct WeekChanged {
        let weekStart: Date
        let weekOffset: Int
        let sessions: [SessionDTO]
        let selectedChildId: String?
        let children: [ChildProfileDTO]
        let weeklyGoals: [String: Int]
        let plannedSessions: [PlannedSession]
        let specialistVisits: [SpecialistVisit]
    }

    struct DaySelected {
        let date: Date
        let sessions: [SessionDTO]
        let children: [ChildProfileDTO]
        let dayPlans: [PlannedSession]
        let specialistVisits: [SpecialistVisit]
    }

    struct InsightsGenerated {
        let insights: [InsightItem]
    }

    struct LessonScheduled {
        let plan: PlannedSession
        let childName: String
        let voiceHint: String
    }

    struct RecurringPlanAdded {
        let plan: RecurringPlan
    }

    struct RecurringPlanRemoved {
        let planId: String
    }

    struct SpecialistVisitAdded {
        let visit: SpecialistVisit
    }

    struct WeekSummaryGenerated {
        let weekStart: Date
        let weekEnd: Date
        let childSummaries: [WeekChildSummary]
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
    let weekIndex: Int
    let weekday: Int
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

// MARK: - Planning Domain Types

struct PlannedSession: Sendable, Identifiable, Codable {
    let id: String
    let childId: String
    let date: Date
    let lessonTemplate: String
    let notificationScheduled: Bool
}

struct RecurringPlan: Sendable, Identifiable, Codable {
    let id: String
    let childId: String
    let weekday: Int       // 0=Пн … 6=Вс
    let hour: Int
    let minute: Int
    let lessonTemplate: String
    let isActive: Bool
}

struct SpecialistVisit: Sendable, Identifiable, Codable {
    let id: String
    let childId: String
    let date: Date
    let specialistName: String
    let notes: String
    let reportRequested: Bool
}

struct WeekChildSummary: Sendable, Identifiable {
    let childId: String
    let childName: String
    let sessionsAchieved: Int
    let sessionsGoal: Int
    let goalReached: Bool
    let avgSuccessRate: Double
    let totalMinutes: Int
    let plannedCount: Int

    var id: String { childId }
}

struct FamilyNotificationContent: Codable {
    let identifier: String
    let title: String
    let body: String
    let scheduledDate: Date
}

// MARK: - Plan Store (UserDefaults persistence для планов)

final class FamilyPlanStore: @unchecked Sendable {

    private let plannedKey = "hs.family.plannedSessions"
    private let recurringKey = "hs.family.recurringPlans"
    private let visitsKey = "hs.family.specialistVisits"
    private let defaults = UserDefaults.standard

    func loadPlannedSessions() -> [PlannedSession] {
        guard let data = defaults.data(forKey: plannedKey),
              let plans = try? JSONDecoder().decode([PlannedSession].self, from: data)
        else { return [] }
        return plans
    }

    func savePlannedSessions(_ plans: [PlannedSession]) {
        guard let data = try? JSONEncoder().encode(plans) else { return }
        defaults.set(data, forKey: plannedKey)
    }

    func loadRecurringPlans() -> [RecurringPlan] {
        guard let data = defaults.data(forKey: recurringKey),
              let plans = try? JSONDecoder().decode([RecurringPlan].self, from: data)
        else { return [] }
        return plans
    }

    func saveRecurringPlans(_ plans: [RecurringPlan]) {
        guard let data = try? JSONEncoder().encode(plans) else { return }
        defaults.set(data, forKey: recurringKey)
    }

    func loadSpecialistVisits() -> [SpecialistVisit] {
        guard let data = defaults.data(forKey: visitsKey),
              let visits = try? JSONDecoder().decode([SpecialistVisit].self, from: data)
        else { return [] }
        return visits
    }

    func saveSpecialistVisits(_ visits: [SpecialistVisit]) {
        guard let data = try? JSONEncoder().encode(visits) else { return }
        defaults.set(data, forKey: visitsKey)
    }
}

// MARK: - ViewModels

struct FamilyCalendarViewModel: Equatable {
    var children: [ChildAvatarViewModel]
    var selectedChildId: String?
    var currentMonth: Date
    var weekOffset: Int
    var weekDays: [WeekDayViewModel]
    var calendarDays: [CalendarDayViewModel]
    var heatmapEntries: [HeatmapEntryViewModel]
    var comparisonCards: [ChildSummaryViewModel]
    var weekGoalCards: [WeekGoalCardViewModel]
    var insights: [InsightItemViewModel]
    var isLoading: Bool
    var isLoadingInsights: Bool
    var toastMessage: String?
    var isEmpty: Bool
    var selectedDayDetail: DayDetailViewModel?
    var weekSummary: WeekSummaryViewModel?

    static let empty = FamilyCalendarViewModel(
        children: [],
        selectedChildId: nil,
        currentMonth: Date(),
        weekOffset: 0,
        weekDays: [],
        calendarDays: [],
        heatmapEntries: [],
        comparisonCards: [],
        weekGoalCards: [],
        insights: [],
        isLoading: true,
        isLoadingInsights: false,
        toastMessage: nil,
        isEmpty: true,
        selectedDayDetail: nil,
        weekSummary: nil
    )
}

struct ChildAvatarViewModel: Identifiable, Equatable {
    let id: String
    let name: String
    let initials: String
    let avatarStyle: String
    let streak: Int
    let isAll: Bool
}

struct WeekDayViewModel: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let dayNumber: Int
    let weekdayShort: String
    let sessionCount: Int
    let plannedCount: Int
    let hasSpecialistVisit: Bool
    let isToday: Bool
    let isFuture: Bool
    let activityLevel: Int   // 0–4

    init(
        id: UUID = UUID(),
        date: Date,
        dayNumber: Int,
        weekdayShort: String,
        sessionCount: Int,
        plannedCount: Int,
        hasSpecialistVisit: Bool,
        isToday: Bool,
        isFuture: Bool,
        activityLevel: Int
    ) {
        self.id = id
        self.date = date
        self.dayNumber = dayNumber
        self.weekdayShort = weekdayShort
        self.sessionCount = sessionCount
        self.plannedCount = plannedCount
        self.hasSpecialistVisit = hasSpecialistVisit
        self.isToday = isToday
        self.isFuture = isFuture
        self.activityLevel = activityLevel
    }
}

struct CalendarDayViewModel: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let dayNumber: Int
    let sessionCount: Int
    let isToday: Bool
    let isCurrentMonth: Bool
    let isFuture: Bool
    let activityLevel: Int

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
    let label: String

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
    let comparisonDelta: Double?
    let isLeader: Bool
}

struct WeekGoalCardViewModel: Identifiable, Equatable {
    let id: String      // childId
    let childName: String
    let initials: String
    let sessionsAchieved: Int
    let sessionsGoal: Int
    let progressFraction: Double
    let goalReached: Bool
    let streakDays: Int
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
    let dayPlans: [DayPlanItem]
    let specialistVisit: DayVisitItem?
    let isEmpty: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        dateText: String,
        sessionItems: [DaySessionItem],
        dayPlans: [DayPlanItem] = [],
        specialistVisit: DayVisitItem? = nil,
        isEmpty: Bool
    ) {
        self.id = id
        self.date = date
        self.dateText = dateText
        self.sessionItems = sessionItems
        self.dayPlans = dayPlans
        self.specialistVisit = specialistVisit
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

struct DayPlanItem: Identifiable, Equatable {
    let id: String
    let childName: String
    let lessonTemplate: String
    let timeText: String
}

struct DayVisitItem: Equatable {
    let specialistName: String
    let notes: String
    let reportRequested: Bool
}

struct WeekSummaryViewModel: Equatable {
    let weekRangeText: String
    let childRows: [WeekSummaryRowViewModel]
    let familyTotalMinutes: Int
    let familyTotalSessions: Int
    let allGoalsReached: Bool
}

struct WeekSummaryRowViewModel: Identifiable, Equatable {
    let id: String
    let childName: String
    let initials: String
    let sessionsText: String
    let progressFraction: Double
    let goalReached: Bool
    let durationText: String
    let accuracyPercent: Int
}
