import Foundation

// MARK: - ParentHomePresentationLogic

@MainActor
protocol ParentHomePresentationLogic: AnyObject {
    func presentFetch(_ response: ParentHomeModels.Fetch.Response)
    func presentLoading(_ isLoading: Bool)
    func presentEmpty()
    // A.6
    func presentWeeklyInsight(_ response: ParentHomeModels.WeeklyInsightResponse)
    func presentError(_ message: String)
    func presentAddChild()
    func presentExportSpecialist(childId: String)
    func presentStartLesson(childId: String)
}

// MARK: - ParentHomePresenter

@MainActor
final class ParentHomePresenter: ParentHomePresentationLogic {

    weak var viewModel: (any ParentHomeDisplayLogic)?

    // MARK: - presentFetch

    func presentFetch(_ response: ParentHomeModels.Fetch.Response) {
        let sessions = response.recentSessions.map { Self.summary(from: $0) }

        let soundProgress = response.targetSounds.map { sound in
            Self.progress(
                sound: sound,
                summary: response.progressSummary,
                sessions: response.weekSessions.filter { $0.targetSound == sound }.count
            )
        }

        let recommendations = Self.recommendations(
            for: response.targetSounds,
            summary: response.progressSummary
        )

        let screeningCard = Self.makeScreeningCard(from: response.screeningOutcome)

        let quickActions = Self.buildQuickActions(childId: response.childId)

        let needsSpecialistReview = soundProgress.contains { $0.overallRate < 0.3 && $0.sessions >= 3 }

        let calendar = Calendar.current
        let todaySessions = response.weekSessions.filter { calendar.isDateInToday($0.date) }
        let todayMinutes = todaySessions.reduce(0) { $0 + $1.durationSeconds / 60 }

        let vm = ParentHomeModels.Fetch.ViewModel(
            childId: response.childId,
            childName: response.childName,
            childAge: response.childAge,
            targetSoundsText: response.targetSounds.joined(separator: ", "),
            greeting: Self.greeting(for: Date()),
            currentStreak: response.currentStreak,
            totalSessionMinutes: response.totalSessionMinutes,
            overallRate: response.overallRate,
            lastSession: sessions.first,
            recentSessions: sessions,
            soundProgress: soundProgress,
            homeTask: response.homeTask,
            recommendations: recommendations,
            screeningCard: screeningCard,
            allChildren: response.allChildren,
            weekStats: [],    // заполнится из presentWeeklyInsight
            weeklyInsight: nil,
            achievements: response.achievements,
            notifications: response.notifications,
            quickActions: quickActions,
            needsSpecialistReview: needsSpecialistReview,
            todaySessionsCount: todaySessions.count,
            todayMinutes: todayMinutes
        )
        viewModel?.displayFetch(vm)
    }

    func presentLoading(_ isLoading: Bool) {
        viewModel?.displayLoading(isLoading)
    }

    func presentEmpty() {
        viewModel?.displayEmptyState()
    }

    func presentWeeklyInsight(_ response: ParentHomeModels.WeeklyInsightResponse) {
        viewModel?.displayWeeklyInsight(response)
    }

    func presentError(_ message: String) {
        viewModel?.displayError(message)
    }

    func presentAddChild() {
        viewModel?.displayNavigateToAddChild()
    }

    func presentExportSpecialist(childId: String) {
        viewModel?.displayNavigateToSpecialistExport(childId: childId)
    }

    func presentStartLesson(childId: String) {
        viewModel?.displayNavigateToStartLesson(childId: childId)
    }

    // MARK: - Helpers

    private static func summary(from data: ParentHomeModels.SessionData) -> ParentHomeModels.SessionSummary {
        let successRate = data.totalAttempts > 0
            ? Double(data.correctAttempts) / Double(data.totalAttempts)
            : 0.0
        return ParentHomeModels.SessionSummary(
            id: data.id,
            targetSound: data.targetSound,
            templateName: templateName(for: data.templateType),
            dateText: dateText(for: data.date),
            durationText: durationText(for: data.durationSeconds),
            totalAttempts: data.totalAttempts,
            correctAttempts: data.correctAttempts,
            successRate: successRate
        )
    }

    private static func progress(
        sound: String,
        summary: [String: Double],
        sessions: Int
    ) -> ParentHomeModels.SoundProgress {
        let rate = summary[sound] ?? 0.0
        return ParentHomeModels.SoundProgress(
            sound: sound,
            familyName: familyName(for: sound),
            currentStage: stageName(for: rate),
            overallRate: rate,
            sessions: sessions,
            trend: .stable
        )
    }

    private static func greeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return String(localized: "parent.home.greeting.morning")
        case 12..<17: return String(localized: "parent.home.greeting.day")
        case 17..<23: return String(localized: "parent.home.greeting.evening")
        default:       return String(localized: "parent.home.greeting.night")
        }
    }

    private static func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        if Calendar.current.isDateInToday(date) {
            return String(localized: "parent.home.date.today")
        }
        if Calendar.current.isDateInYesterday(date) {
            return String(localized: "parent.home.date.yesterday")
        }
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private static func durationText(for seconds: Int) -> String {
        let minutes = max(1, seconds / 60)
        let format = String(localized: "parent.home.duration.minutes")
        return String.localizedStringWithFormat(format, minutes)
    }

    private static func templateName(for type: String) -> String {
        let key = "template.\(type).name"
        let localized = String(localized: String.LocalizationValue(key))
        return localized == key ? type : localized
    }

    private static func familyName(for sound: String) -> String {
        let upper = sound.uppercased()
        if ["С", "З", "Ц"].contains(upper) { return String(localized: "sound.family.whistling") }
        if ["Ш", "Ж", "Ч", "Щ"].contains(upper) { return String(localized: "sound.family.hissing") }
        if ["Р", "Л"].contains(upper) { return String(localized: "sound.family.sonorant") }
        if ["К", "Г", "Х"].contains(upper) { return String(localized: "sound.family.velar") }
        return String(localized: "sound.family.other")
    }

    private static func stageName(for rate: Double) -> String {
        switch rate {
        case ..<0.2:  return String(localized: "stage.isolated")
        case ..<0.4:  return String(localized: "stage.syllable")
        case ..<0.7:  return String(localized: "stage.wordInit")
        case ..<0.9:  return String(localized: "stage.phrase")
        default:       return String(localized: "stage.story")
        }
    }

    private static func buildQuickActions(childId: String) -> [ParentHomeModels.QuickAction] {
        [
            .init(
                id: "start_lesson",
                icon: "play.circle.fill",
                title: String(localized: "parent.quickaction.start_lesson"),
                destination: .startLesson(childId: childId)
            ),
            .init(
                id: "export_specialist",
                icon: "square.and.arrow.up",
                title: String(localized: "parent.quickaction.export"),
                destination: .exportToSpecialist(childId: childId)
            ),
            .init(
                id: "view_history",
                icon: "clock.arrow.circlepath",
                title: String(localized: "parent.quickaction.history"),
                destination: .viewHistory(childId: childId)
            ),
            .init(
                id: "settings",
                icon: "gearshape.fill",
                title: String(localized: "parent.quickaction.settings"),
                destination: .openSettings
            )
        ]
    }

    // MARK: - M6.16: Screening Card

    private static func makeScreeningCard(
        from outcome: ScreeningOutcomeDTO?
    ) -> ParentHomeModels.ScreeningCardViewModel? {
        guard let outcome else { return nil }

        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateStyle = .long
        df.timeStyle = .none
        let dateText = df.string(from: outcome.completedAt)

        let sounds = outcome.problematicSounds
        let soundsText = sounds.isEmpty
            ? String(localized: "screening.card.no_issues")
            : sounds.joined(separator: ", ")

        let recommendation: String
        switch outcome.overallSeverity {
        case "mild":
            recommendation = String(localized: "screening.card.reco.mild")
        case "moderate":
            let format = String(localized: "screening.card.reco.moderate")
            recommendation = String.localizedStringWithFormat(format, soundsText)
        case "severe":
            let format = String(localized: "screening.card.reco.severe")
            recommendation = String.localizedStringWithFormat(format, soundsText)
        default:
            recommendation = String(localized: "screening.card.reco.mild")
        }

        let daysSince = Calendar.current.dateComponents(
            [.day], from: outcome.completedAt, to: Date()
        ).day ?? 0
        let canRetake = daysSince >= 14

        return ParentHomeModels.ScreeningCardViewModel(
            completedAtText: dateText,
            severityText: outcome.severityDisplayText,
            problematicSoundsText: soundsText,
            recommendationText: recommendation,
            canRetake: canRetake,
            severityColorToken: outcome.overallSeverity
        )
    }

    private static func recommendations(for sounds: [String], summary: [String: Double]) -> [String] {
        var result: [String] = []
        for sound in sounds {
            let rate = summary[sound] ?? 0.0
            if rate < 0.3 {
                let format = String(localized: "parent.home.reco.early")
                result.append(String.localizedStringWithFormat(format, sound))
            } else if rate < 0.7 {
                let format = String(localized: "parent.home.reco.middle")
                result.append(String.localizedStringWithFormat(format, sound))
            } else if rate < 0.95 {
                let format = String(localized: "parent.home.reco.late")
                result.append(String.localizedStringWithFormat(format, sound))
            }
        }
        if result.isEmpty {
            result.append(String(localized: "parent.home.reco.default"))
        }
        return result
    }
}
