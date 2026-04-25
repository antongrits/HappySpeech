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

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter
    }()

    func presentFetch(_ response: ChildHomeModels.Fetch.Response) {
        let vm = ChildHomeModels.Fetch.ViewModel(
            childName: response.childName,
            currentStreak: response.currentStreak,
            mascotMood: response.mascotMood,
            mascotPhrase: response.mascotPhrase,
            dailyMission: makeDailyMission(from: response),
            soundProgress: makeSoundProgress(from: response),
            quickPlayItems: makeQuickPlay(from: response),
            worldZones: makeWorldZones(from: response),
            recentSessions: makeRecentSessions(from: response),
            achievement: makeAchievement(from: response),
            dailyMissionDetail: makeMissionDetail(from: response),
            formattedDate: dateFormatter.string(from: Date()),
            isStreakHot: response.currentStreak >= 7
        )
        viewModel?.displayFetch(vm)
    }

    // MARK: - VM builders

    private func makeDailyMission(
        from response: ChildHomeModels.Fetch.Response
    ) -> ChildHomeModels.DailyMission {
        ChildHomeModels.DailyMission(
            targetSound: response.dailyTargetSound,
            title: formatMissionTitle(sound: response.dailyTargetSound),
            subtitle: response.dailyStage,
            progress: response.dailyProgress
        )
    }

    private func makeMissionDetail(
        from response: ChildHomeModels.Fetch.Response
    ) -> ChildHomeModels.DailyMissionDetail {
        let detail = response.dailyMissionDetail
        return ChildHomeModels.DailyMissionDetail(
            id: detail.id,
            title: formatMissionDetailTitle(sound: detail.targetSound, reps: detail.requiredReps),
            description: formatMissionDetailDescription(sound: detail.targetSound),
            targetSound: detail.targetSound,
            templateType: detail.templateType,
            requiredReps: detail.requiredReps,
            completedReps: detail.completedReps
        )
    }

    private func makeSoundProgress(
        from response: ChildHomeModels.Fetch.Response
    ) -> [ChildHomeModels.SoundProgressItem] {
        response.soundProgress.map { data in
            ChildHomeModels.SoundProgressItem(
                sound: data.sound,
                stageName: data.stageName,
                rate: data.rate,
                accent: Self.family(for: data.sound)
            )
        }
    }

    private func makeQuickPlay(
        from response: ChildHomeModels.Fetch.Response
    ) -> [ChildHomeModels.QuickPlayItem] {
        response.quickPlay.map { data in
            ChildHomeModels.QuickPlayItem(
                id: data.id,
                templateType: data.templateType,
                title: String(localized: String.LocalizationValue(data.titleKey)),
                icon: data.icon,
                accent: data.accent
            )
        }
    }

    private func makeWorldZones(
        from response: ChildHomeModels.Fetch.Response
    ) -> [ChildHomeModels.WorldZonePreview] {
        response.worldZones.map { data in
            ChildHomeModels.WorldZonePreview(
                id: data.id,
                sound: data.sound,
                emoji: data.emoji,
                progress: data.progress,
                family: data.family
            )
        }
    }

    private func makeRecentSessions(
        from response: ChildHomeModels.Fetch.Response
    ) -> [ChildHomeModels.RecentSession] {
        response.recentSessions.map { data -> ChildHomeModels.RecentSession in
            let title = TemplateType(rawValue: data.templateType)?.displayName
                ?? String(localized: "child.home.recent.unknown")
            return ChildHomeModels.RecentSession(
                id: data.id,
                date: data.date,
                gameTitle: title,
                soundTarget: data.targetSound,
                score: Float(data.score)
            )
        }
    }

    private func makeAchievement(
        from response: ChildHomeModels.Fetch.Response
    ) -> ChildHomeModels.Achievement? {
        response.achievement.map { data in
            ChildHomeModels.Achievement(
                id: data.id,
                title: String(localized: String.LocalizationValue(data.titleKey)),
                description: String(localized: String.LocalizationValue(data.descriptionKey)),
                emoji: data.emoji,
                isVisible: true
            )
        }
    }

    // MARK: - Formatting helpers

    private func formatMissionTitle(sound: String) -> String {
        let format = String(localized: "child.home.daily.title")
        return String.localizedStringWithFormat(format, sound)
    }

    private func formatMissionDetailTitle(sound: String, reps: Int) -> String {
        let format = String(localized: "child.home.mission.title.format")
        return String.localizedStringWithFormat(format, sound, reps)
    }

    private func formatMissionDetailDescription(sound: String) -> String {
        let format = String(localized: "child.home.mission.description.format")
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
