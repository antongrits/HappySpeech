import Foundation

// MARK: - SoundOfTheDayPresenter

@MainActor
final class SoundOfTheDayPresenter {

    weak var displayLogic: (any SoundOfTheDayDisplayLogic)?

    /// Цель «полоски стрика» — 7 дней подряд = 100%.
    private static let streakTargetDays: Double = 7

    init(displayLogic: any SoundOfTheDayDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load Today

    func presentLoadToday(response: SoundOfTheDayModels.LoadToday.Response) async {
        let greeting: String = response.childName.isEmpty
            ? String(localized: "sotd.greeting.anonymous")
            : String(
                format: String(localized: "sotd.greeting.named.format"),
                response.childName
            )
        let subtitle = String(
            format: String(localized: "sotd.subtitle.date.format"),
            response.weekdayDateText
        )
        let heroTitle = String(
            format: String(localized: "sotd.hero.title.format"),
            response.targetSound
        )
        let streakText = String.localizedStringWithFormat(
            String(localized: "sotd.streak.days.format"),
            response.streakDays
        )
        let streakProgress = min(
            1.0,
            Double(response.streakDays) / Self.streakTargetDays
        )
        let a11y = String(
            format: String(localized: "sotd.a11y.summary.format"),
            response.targetSound,
            response.streakDays
        )
        let vm = SoundOfTheDayModels.LoadToday.ViewModel(
            greeting: greeting,
            subtitle: subtitle,
            heroTitle: heroTitle,
            heroReason: response.reasonText,
            streakText: streakText,
            streakProgress: streakProgress,
            activities: response.activities,
            primaryCtaTitle: String(localized: "sotd.cta.start"),
            accessibilityLabel: a11y
        )
        await displayLogic?.displayLoadToday(viewModel: vm)
    }
}
