import Foundation

// MARK: - ParentHomePresentationLogic

@MainActor
protocol ParentHomePresentationLogic: AnyObject {
    func presentFetch(_ response: ParentHomeModels.Fetch.Response)
    func presentLoading(_ isLoading: Bool)
    func presentEmpty()
}

// MARK: - ParentHomePresenter

@MainActor
final class ParentHomePresenter: ParentHomePresentationLogic {

    weak var viewModel: (any ParentHomeDisplayLogic)?

    func presentFetch(_ response: ParentHomeModels.Fetch.Response) {
        let sessions = response.recentSessions.map { Self.summary(from: $0) }
        let soundProgress = response.targetSounds.map { sound in
            Self.progress(sound: sound, summary: response.progressSummary)
        }

        let recommendations = Self.recommendations(
            for: response.targetSounds,
            summary: response.progressSummary
        )

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
            recommendations: recommendations
        )
        viewModel?.displayFetch(vm)
    }

    func presentLoading(_ isLoading: Bool) {
        viewModel?.displayLoading(isLoading)
    }

    func presentEmpty() {
        viewModel?.displayEmptyState()
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

    private static func progress(sound: String, summary: [String: Double]) -> ParentHomeModels.SoundProgress {
        let rate = summary[sound] ?? 0.0
        return ParentHomeModels.SoundProgress(
            sound: sound,
            familyName: familyName(for: sound),
            currentStage: stageName(for: rate),
            overallRate: rate
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
