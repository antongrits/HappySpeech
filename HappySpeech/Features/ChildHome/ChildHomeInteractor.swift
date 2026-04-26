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
        let completedReps = Self.completedReps(for: recent, sound: dailySound)
        let requiredReps = 5
        // B13: overdue = миссия не завершена и сейчас уже вечер (≥ 20:00).
        let hasOverdueTask = Self.computeOverdue(
            completedReps: completedReps,
            requiredReps: requiredReps
        )
        let mission = ChildHomeModels.DailyMissionDetailData(
            id: "mission-\(profile.id)-\(Self.dayOfYear)",
            titleKey: "child.home.mission.title.format",
            descriptionKey: "child.home.mission.description.format",
            targetSound: dailySound,
            templateType: TemplateType.repeatAfterModel.rawValue,
            requiredReps: requiredReps,
            completedReps: completedReps
        )
        return ChildHomeModels.Fetch.Response(
            childName: profile.name,
            currentStreak: profile.currentStreak,
            mascotMood: Self.mascotMood(
                for: profile.currentStreak,
                hasOverdueTask: hasOverdueTask
            ),
            mascotPhrase: Self.mascotPhrase(name: profile.name, sound: dailySound),
            dailyTargetSound: dailySound,
            dailyStage: Self.humanStage(for: dailyProgress),
            dailyProgress: dailyProgress,
            soundProgress: Self.makeSoundProgress(profile: profile),
            quickPlay: Self.seedQuickPlay(),
            worldZones: Self.buildWorldZones(profile: profile),
            recentSessions: Self.makeRecentForSection(from: recent),
            achievement: Self.buildAchievement(
                sessions: recent,
                dismissed: dismissedAchievementIds
            ),
            dailyMissionDetail: mission,
            recentRewards: Self.makeRewardsForSection(from: recent),
            hasOverdueTask: hasOverdueTask
        )
    }

    /// Собирает sound-progress data из профиля (extracted from buildResponse).
    private static func makeSoundProgress(
        profile: ChildProfileDTO
    ) -> [ChildHomeModels.SoundProgressData] {
        profile.targetSounds.map { sound in
            ChildHomeModels.SoundProgressData(
                sound: sound,
                stageName: humanStage(for: profile.progressSummary[sound] ?? 0.0),
                rate: profile.progressSummary[sound] ?? 0.0
            )
        }
    }

    /// Собирает recent-sessions data; fallback на seed если пусто.
    private static func makeRecentForSection(
        from recent: [SessionDTO]
    ) -> [ChildHomeModels.RecentSessionData] {
        let mapped = recent.map {
            ChildHomeModels.RecentSessionData(
                id: $0.id,
                date: $0.date,
                templateType: $0.templateType,
                targetSound: $0.targetSound,
                score: $0.successRate
            )
        }
        return mapped.isEmpty ? seedRecentSessions() : mapped
    }

    /// B13: recentRewards собираем из «успешных» сессий (≥ 0.85). Fallback на seed.
    private static func makeRewardsForSection(
        from recent: [SessionDTO]
    ) -> [ChildHomeModels.RecentRewardData] {
        let rewards = buildRecentRewards(from: recent)
        return rewards.isEmpty ? seedRecentRewards() : rewards
    }

    /// Seed-fallback: используется только если Realm-репозиторий упал.
    private func buildSeedResponse() -> ChildHomeModels.Fetch.Response {
        let dailySound = "Р"
        let completedReps = 2
        let requiredReps = 5
        let hasOverdueTask = Self.computeOverdue(
            completedReps: completedReps,
            requiredReps: requiredReps
        )
        return ChildHomeModels.Fetch.Response(
            childName: Self.seedChildName,
            currentStreak: Self.seedStreak,
            mascotMood: Self.mascotMood(
                for: Self.seedStreak,
                hasOverdueTask: hasOverdueTask
            ),
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
                requiredReps: requiredReps,
                completedReps: completedReps
            ),
            recentRewards: Self.seedRecentRewards(),
            hasOverdueTask: hasOverdueTask
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

    /// B13 mascot mapping:
    ///   - hasOverdueTask → `.thinking` (приоритет выше streak)
    ///   - streak == 0    → `.waving` (приветствие, ребёнок только пришёл)
    ///   - streak ≥ 7     → `.celebrating`
    ///   - иначе          → `.encouraging`
    private static func mascotMood(
        for streak: Int,
        hasOverdueTask: Bool
    ) -> MascotMood {
        if hasOverdueTask { return .thinking }
        switch streak {
        case 0:        return .waving
        case 1...6:    return .encouraging
        default:       return .celebrating
        }
    }

    /// Просрочена ли дневная миссия. Логика B13:
    /// `!completed && currentHour ≥ 20` (вечер, ребёнок ещё не закрыл миссию).
    private static func computeOverdue(
        completedReps: Int,
        requiredReps: Int,
        now: Date = Date()
    ) -> Bool {
        let isCompleted = completedReps >= requiredReps
        if isCompleted { return false }
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 20
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
        // B13: difficulty 1…3 — рисуется звёздочками в карточке.
        // Лёгкие шаблоны (повторение, drag) — 1; средние (hunter, memory) — 2; bingo — 3.
        [
            .init(
                id: "qp-repeat",
                templateType: TemplateType.repeatAfterModel.rawValue,
                titleKey: "child.home.quick.repeat",
                icon: "speaker.wave.2.fill",
                accent: .coral,
                difficulty: 1
            ),
            .init(
                id: "qp-hunter",
                templateType: TemplateType.soundHunter.rawValue,
                titleKey: "child.home.quick.hunter",
                icon: "binoculars.fill",
                accent: .mint,
                difficulty: 2
            ),
            .init(
                id: "qp-memory",
                templateType: TemplateType.memory.rawValue,
                titleKey: "child.home.quick.memory",
                icon: "brain.head.profile",
                accent: .lilac,
                difficulty: 2
            ),
            .init(
                id: "qp-bingo",
                templateType: TemplateType.bingo.rawValue,
                titleKey: "child.home.quick.bingo",
                icon: "square.grid.3x3.fill",
                accent: .butter,
                difficulty: 3
            ),
            .init(
                id: "qp-drag",
                templateType: TemplateType.dragAndMatch.rawValue,
                titleKey: "child.home.quick.drag",
                icon: "hand.draw.fill",
                accent: .sky,
                difficulty: 1
            )
        ]
    }

    // MARK: - Recent rewards (B13)

    /// Награда формируется из «успешной» сессии (≥ 0.85). Берём 3 последние.
    private static func buildRecentRewards(
        from sessions: [SessionDTO]
    ) -> [ChildHomeModels.RecentRewardData] {
        sessions
            .filter { $0.successRate >= 0.85 }
            .prefix(3)
            .map { session in
                ChildHomeModels.RecentRewardData(
                    id: "reward-\(session.id)",
                    emoji: rewardEmoji(for: session.successRate),
                    titleKey: rewardTitleKey(for: session.successRate),
                    earnedAt: session.date
                )
            }
    }

    private static func rewardEmoji(for score: Double) -> String {
        switch score {
        case 0.95...: return "🏆"
        case 0.90..<0.95: return "🥇"
        default: return "🥈"
        }
    }

    private static func rewardTitleKey(for score: Double) -> String {
        switch score {
        case 0.95...: return "child.home.rewards.gold"
        case 0.90..<0.95: return "child.home.rewards.silver"
        default: return "child.home.rewards.bronze"
        }
    }

    private static func seedRecentRewards() -> [ChildHomeModels.RecentRewardData] {
        let now = Date()
        return [
            .init(
                id: "seed-reward-1",
                emoji: "🏆",
                titleKey: "child.home.rewards.gold",
                earnedAt: now.addingTimeInterval(-3600)
            ),
            .init(
                id: "seed-reward-2",
                emoji: "🥇",
                titleKey: "child.home.rewards.silver",
                earnedAt: now.addingTimeInterval(-86_400)
            ),
            .init(
                id: "seed-reward-3",
                emoji: "🌟",
                titleKey: "child.home.rewards.streak",
                earnedAt: now.addingTimeInterval(-172_800)
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
