import Foundation
import OSLog

// MARK: - ChildHomeBusinessLogic

@MainActor
protocol ChildHomeBusinessLogic: AnyObject {
    func fetchChildData(_ request: ChildHomeModels.Fetch.Request) async
}

// MARK: - ChildHomeInteractor

@MainActor
final class ChildHomeInteractor: ChildHomeBusinessLogic {

    var presenter: (any ChildHomePresentationLogic)?

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    func fetchChildData(_ request: ChildHomeModels.Fetch.Request) async {
        do {
            let profile = try await childRepository.fetch(id: request.childId)
            let recent = (try? await sessionRepository.fetchRecent(childId: request.childId, limit: 5)) ?? []

            let dailySound = profile.targetSounds.first ?? "Р"
            let stageText = Self.stageText(for: profile, recent: recent)
            let dailyProgress = profile.progressSummary[dailySound] ?? 0.0
            let soundProgress = profile.targetSounds.map { sound in
                ChildHomeModels.SoundProgressData(
                    sound: sound,
                    stageName: Self.humanStage(for: profile.progressSummary[sound] ?? 0.0),
                    rate: profile.progressSummary[sound] ?? 0.0
                )
            }

            let response = ChildHomeModels.Fetch.Response(
                childName: profile.name,
                currentStreak: profile.currentStreak,
                mascotMood: Self.mascotMood(for: profile.currentStreak),
                mascotPhrase: Self.mascotPhrase(name: profile.name, sound: dailySound),
                dailyTargetSound: dailySound,
                dailyStage: stageText,
                dailyProgress: dailyProgress,
                soundProgress: soundProgress
            )
            presenter?.presentFetch(response)
        } catch {
            HSLogger.ui.error("ChildHome fetch failed: \(error)")
            // Fall back to empty state — Presenter handles placeholder values.
            let dailySound = "Р"
            let response = ChildHomeModels.Fetch.Response(
                childName: "",
                currentStreak: 0,
                mascotMood: .idle,
                mascotPhrase: nil,
                dailyTargetSound: dailySound,
                dailyStage: Self.humanStage(for: 0.0),
                dailyProgress: 0.0,
                soundProgress: []
            )
            presenter?.presentFetch(response)
        }
    }

    // MARK: - Helpers

    private static func humanStage(for rate: Double) -> String {
        switch rate {
        case ..<0.2:  return String(localized: "stage.isolated")
        case ..<0.4:  return String(localized: "stage.syllable")
        case ..<0.7:  return String(localized: "stage.wordInit")
        case ..<0.9:  return String(localized: "stage.phrase")
        default:       return String(localized: "stage.story")
        }
    }

    private static func stageText(for profile: ChildProfileDTO, recent: [SessionDTO]) -> String {
        let rate = profile.progressSummary[profile.targetSounds.first ?? "Р"] ?? 0.0
        return humanStage(for: rate)
    }

    private static func mascotMood(for streak: Int) -> MascotMood {
        switch streak {
        case 0: return .idle
        case 1...2: return .happy
        case 3...6: return .encouraging
        default: return .celebrating
        }
    }

    private static func mascotPhrase(name: String, sound: String) -> String {
        let format = String(localized: "child.home.mascot.phrase")
        let displayName = name.isEmpty ? String(localized: "child.default.name") : name
        return String.localizedStringWithFormat(format, displayName, sound)
    }
}
