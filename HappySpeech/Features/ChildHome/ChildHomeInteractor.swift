import Foundation
import OSLog

// MARK: - ChildHomeBusinessLogic

@MainActor
protocol ChildHomeBusinessLogic: AnyObject {
    func fetchChildData(_ request: ChildHomeModels.Fetch.Request) async
    func dismissAchievement(id: String) async
    func recordMissionTap() async
}

// MARK: - ChildHomeInteractor

@MainActor
final class ChildHomeInteractor: ChildHomeBusinessLogic {

    var presenter: (any ChildHomePresentationLogic)?

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ChildHome")

    /// Список ID скрытых ачивок (in-memory, на сессию).
    private var dismissedAchievementIds: Set<String> = []

    /// Кэш последнего ID — для повторного presentFetch при `dismissAchievement`.
    private var lastChildId: String?

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    // MARK: - Public API

    func fetchChildData(_ request: ChildHomeModels.Fetch.Request) async {
        lastChildId = request.childId

        // Реальные данные из Realm — основной путь.
        do {
            let profile = try await childRepository.fetch(id: request.childId)
            let recentSessions = (try? await sessionRepository.fetchRecent(
                childId: request.childId,
                limit: 3
            )) ?? []

            let response = buildResponse(profile: profile, recent: recentSessions)
            presenter?.presentFetch(response)
        } catch {
            logger.error("ChildHome fetch failed, fallback to seed: \(error.localizedDescription, privacy: .public)")
            // Fallback на seed-данные (M8.7) — гарантирует, что у ребёнка всегда есть что показать.
            let response = buildSeedResponse()
            presenter?.presentFetch(response)
        }
    }

    func dismissAchievement(id: String) async {
        dismissedAchievementIds.insert(id)
        logger.info("Achievement dismissed: \(id, privacy: .public)")
        if let childId = lastChildId {
            await fetchChildData(.init(childId: childId))
        }
    }

    func recordMissionTap() async {
        logger.info("Daily mission tapped from ChildHome")
        // M10: продвинуть completedReps. Сейчас — no-op.
    }

    // MARK: - Response building

    private func buildResponse(
        profile: ChildProfileDTO,
        recent: [SessionDTO]
    ) -> ChildHomeModels.Fetch.Response {
        let dailySound = profile.targetSounds.first ?? "Р"
        let dailyProgress = profile.progressSummary[dailySound] ?? 0.0
        let stageText = Self.humanStage(for: dailyProgress)

        let soundProgress = profile.targetSounds.map { sound in
            ChildHomeModels.SoundProgressData(
                sound: sound,
                stageName: Self.humanStage(for: profile.progressSummary[sound] ?? 0.0),
                rate: profile.progressSummary[sound] ?? 0.0
            )
        }

        let recentData = recent.map {
            ChildHomeModels.RecentSessionData(
                id: $0.id,
                date: $0.date,
                templateType: $0.templateType,
                targetSound: $0.targetSound,
                score: $0.successRate
            )
        }
        let recentForSection = recentData.isEmpty ? Self.seedRecentSessions() : recentData

        let achievement = Self.buildAchievement(
            sessions: recent,
            dismissed: dismissedAchievementIds
        )

        let mission = ChildHomeModels.DailyMissionDetailData(
            id: "mission-\(profile.id)-\(Self.dayOfYear)",
            titleKey: "child.home.mission.title.format",
            descriptionKey: "child.home.mission.description.format",
            targetSound: dailySound,
            templateType: TemplateType.repeatAfterModel.rawValue,
            requiredReps: 5,
            completedReps: Self.completedReps(for: recent, sound: dailySound)
        )

        return ChildHomeModels.Fetch.Response(
            childName: profile.name,
            currentStreak: profile.currentStreak,
            mascotMood: Self.mascotMood(for: profile.currentStreak),
            mascotPhrase: Self.mascotPhrase(name: profile.name, sound: dailySound),
            dailyTargetSound: dailySound,
            dailyStage: stageText,
            dailyProgress: dailyProgress,
            soundProgress: soundProgress,
            quickPlay: Self.seedQuickPlay(),
            worldZones: Self.buildWorldZones(profile: profile),
            recentSessions: recentForSection,
            achievement: achievement,
            dailyMissionDetail: mission
        )
    }

    /// Seed-fallback: используется только если Realm-репозиторий упал.
    private func buildSeedResponse() -> ChildHomeModels.Fetch.Response {
        let dailySound = "Р"
        return ChildHomeModels.Fetch.Response(
            childName: Self.seedChildName,
            currentStreak: Self.seedStreak,
            mascotMood: Self.mascotMood(for: Self.seedStreak),
            mascotPhrase: Self.mascotPhrase(name: Self.seedChildName, sound: dailySound),
            dailyTargetSound: dailySound,
            dailyStage: Self.humanStage(for: 0.4),
            dailyProgress: 0.4,
            soundProgress: Self.seedSoundProgress(),
            quickPlay: Self.seedQuickPlay(),
            worldZones: Self.seedWorldZones(),
            recentSessions: Self.seedRecentSessions(),
            achievement: dismissedAchievementIds.contains("seed-first-session")
                ? nil
                : ChildHomeModels.AchievementData(
                    id: "seed-first-session",
                    titleKey: "child.home.achievement.first.title",
                    descriptionKey: "child.home.achievement.first.description",
                    emoji: "🎉",
                    isNew: true
                ),
            dailyMissionDetail: ChildHomeModels.DailyMissionDetailData(
                id: "seed-mission-\(Self.dayOfYear)",
                titleKey: "child.home.mission.title.format",
                descriptionKey: "child.home.mission.description.format",
                targetSound: dailySound,
                templateType: TemplateType.repeatAfterModel.rawValue,
                requiredReps: 5,
                completedReps: 2
            )
        )
    }

    // MARK: - Helpers (stage / mood / phrase)

    private static func humanStage(for rate: Double) -> String {
        switch rate {
        case ..<0.2:  return String(localized: "stage.isolated")
        case ..<0.4:  return String(localized: "stage.syllable")
        case ..<0.7:  return String(localized: "stage.wordInit")
        case ..<0.9:  return String(localized: "stage.phrase")
        default:       return String(localized: "stage.story")
        }
    }

    private static func mascotMood(for streak: Int) -> MascotMood {
        switch streak {
        case 0:        return .idle
        case 1...2:    return .happy
        case 3...6:    return .encouraging
        default:       return .celebrating
        }
    }

    private static func mascotPhrase(name: String, sound: String) -> String {
        let format = String(localized: "child.home.mascot.phrase")
        let displayName = name.isEmpty ? String(localized: "child.default.name") : name
        return String.localizedStringWithFormat(format, displayName, sound)
    }

    /// Подсчитываем, сколько раз сегодня ребёнок уже произнёс целевой звук —
    /// прокси-метрика «выполнено повторений миссии». Для M10 заменим на реальный счётчик.
    private static func completedReps(for sessions: [SessionDTO], sound: String) -> Int {
        let calendar = Calendar.current
        let today = sessions.filter {
            calendar.isDateInToday($0.date) && $0.targetSound == sound
        }
        let total = today.reduce(0) { $0 + $1.correctAttempts }
        return min(total, 5)
    }

    private static func buildAchievement(
        sessions: [SessionDTO],
        dismissed: Set<String>
    ) -> ChildHomeModels.AchievementData? {
        guard let last = sessions.first, last.successRate >= 0.85 else {
            // Может всё ещё показать «первый урок» если сессий мало.
            let placeholderId = "seed-first-session"
            if dismissed.contains(placeholderId) { return nil }
            return ChildHomeModels.AchievementData(
                id: placeholderId,
                titleKey: "child.home.achievement.first.title",
                descriptionKey: "child.home.achievement.first.description",
                emoji: "🎉",
                isNew: true
            )
        }
        let id = "ach-\(last.id)"
        if dismissed.contains(id) { return nil }
        return ChildHomeModels.AchievementData(
            id: id,
            titleKey: "child.home.achievement.streak.title",
            descriptionKey: "child.home.achievement.streak.description",
            emoji: "🌟",
            isNew: true
        )
    }

    /// Шаблон одной зоны на карте мира (sound + emoji + family).
    /// Прогресс берётся из профиля при сборке зон.
    private struct WorldZoneTemplate {
        let sound: String
        let emoji: String
        let family: SoundFamily
    }

    private static let worldZoneTemplates: [WorldZoneTemplate] = [
        .init(sound: "С", emoji: "🌊", family: .whistling),
        .init(sound: "Ш", emoji: "🐍", family: .hissing),
        .init(sound: "Р", emoji: "🐯", family: .sonorant),
        .init(sound: "Л", emoji: "🌙", family: .sonorant),
        .init(sound: "К", emoji: "🏔", family: .velar)
    ]

    private static func buildWorldZones(profile: ChildProfileDTO) -> [ChildHomeModels.WorldZoneData] {
        worldZoneTemplates.map { template in
            ChildHomeModels.WorldZoneData(
                id: "zone-\(template.sound)",
                sound: template.sound,
                emoji: template.emoji,
                progress: profile.progressSummary[template.sound] ?? 0.0,
                family: template.family
            )
        }
    }

    // MARK: - Seed data (fallback only)

    private static let seedChildName = String(localized: "child.default.name")
    private static let seedStreak = 5

    private static func seedSoundProgress() -> [ChildHomeModels.SoundProgressData] {
        [
            .init(sound: "Р", stageName: humanStage(for: 0.4), rate: 0.4),
            .init(sound: "Ш", stageName: humanStage(for: 0.6), rate: 0.6)
        ]
    }

    private static func seedQuickPlay() -> [ChildHomeModels.QuickPlayData] {
        [
            .init(
                id: "qp-repeat",
                templateType: TemplateType.repeatAfterModel.rawValue,
                titleKey: "child.home.quick.repeat",
                icon: "speaker.wave.2.fill",
                accent: .coral
            ),
            .init(
                id: "qp-hunter",
                templateType: TemplateType.soundHunter.rawValue,
                titleKey: "child.home.quick.hunter",
                icon: "binoculars.fill",
                accent: .mint
            ),
            .init(
                id: "qp-memory",
                templateType: TemplateType.memory.rawValue,
                titleKey: "child.home.quick.memory",
                icon: "brain.head.profile",
                accent: .lilac
            ),
            .init(
                id: "qp-bingo",
                templateType: TemplateType.bingo.rawValue,
                titleKey: "child.home.quick.bingo",
                icon: "square.grid.3x3.fill",
                accent: .butter
            ),
            .init(
                id: "qp-drag",
                templateType: TemplateType.dragAndMatch.rawValue,
                titleKey: "child.home.quick.drag",
                icon: "hand.draw.fill",
                accent: .sky
            )
        ]
    }

    private static func seedWorldZones() -> [ChildHomeModels.WorldZoneData] {
        [
            .init(id: "zone-С", sound: "С", emoji: "🌊", progress: 0.7, family: .whistling),
            .init(id: "zone-Ш", sound: "Ш", emoji: "🐍", progress: 0.5, family: .hissing),
            .init(id: "zone-Р", sound: "Р", emoji: "🐯", progress: 0.4, family: .sonorant),
            .init(id: "zone-Л", sound: "Л", emoji: "🌙", progress: 0.3, family: .sonorant),
            .init(id: "zone-К", sound: "К", emoji: "🏔", progress: 0.2, family: .velar)
        ]
    }

    private static func seedRecentSessions() -> [ChildHomeModels.RecentSessionData] {
        let now = Date()
        return [
            .init(
                id: "seed-rs-1",
                date: now.addingTimeInterval(-3600),
                templateType: TemplateType.repeatAfterModel.rawValue,
                targetSound: "Р",
                score: 0.92
            ),
            .init(
                id: "seed-rs-2",
                date: now.addingTimeInterval(-86_400),
                templateType: TemplateType.soundHunter.rawValue,
                targetSound: "Ш",
                score: 0.78
            ),
            .init(
                id: "seed-rs-3",
                date: now.addingTimeInterval(-172_800),
                templateType: TemplateType.memory.rawValue,
                targetSound: "С",
                score: 0.65
            )
        ]
    }

    private static var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }
}
