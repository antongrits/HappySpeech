import Foundation

// MARK: - ChildHomePresentationLogic

@MainActor
protocol ChildHomePresentationLogic: AnyObject {
    func presentFetch(_ response: ChildHomeModels.Fetch.Response)
}

// MARK: - ChildHomePresenter

@MainActor
final class ChildHomePresenter: ChildHomePresentationLogic {

    weak var viewModel: (any ChildHomeDisplayLogic)?

    func presentFetch(_ response: ChildHomeModels.Fetch.Response) {
        let mission = ChildHomeModels.DailyMission(
            targetSound: response.dailyTargetSound,
            title: formatMissionTitle(sound: response.dailyTargetSound),
            subtitle: response.dailyStage,
            progress: response.dailyProgress
        )

        let progressItems = response.soundProgress.map { data in
            ChildHomeModels.SoundProgressItem(
                sound: data.sound,
                stageName: data.stageName,
                rate: data.rate,
                accent: Self.family(for: data.sound)
            )
        }

        let vm = ChildHomeModels.Fetch.ViewModel(
            childName: response.childName,
            currentStreak: response.currentStreak,
            mascotMood: response.mascotMood,
            mascotPhrase: response.mascotPhrase,
            dailyMission: mission,
            soundProgress: progressItems
        )
        viewModel?.displayFetch(vm)
    }

    // MARK: - Formatting helpers

    private func formatMissionTitle(sound: String) -> String {
        let format = String(localized: "child.home.daily.title")
        return String.localizedStringWithFormat(format, sound)
    }

    static func family(for sound: String) -> SoundFamily {
        let upper = sound.uppercased()
        if ["С", "З", "Ц"].contains(upper) { return .whistling }
        if ["Ш", "Ж", "Ч", "Щ"].contains(upper) { return .hissing }
        if ["Р", "Л"].contains(upper) { return .sonorant }
        if ["К", "Г", "Х"].contains(upper) { return .velar }
        return .sonorant
    }
}
