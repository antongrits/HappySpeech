import Foundation
import OSLog

// MARK: - ChildHomeBusinessLogic

@MainActor
protocol ChildHomeBusinessLogic: AnyObject {
    func fetchChildData(_ request: ChildHomeModels.Fetch.Request) async
    func dismissAchievement(id: String) async
    func recordMissionTap() async
    func tapMascot() async
    func refreshData(childId: String) async
}

// MARK: - ChildHomeInteractor

@MainActor
final class ChildHomeInteractor: ChildHomeBusinessLogic {

    var presenter: (any ChildHomePresentationLogic)?

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let missionSyncService: any DailyMissionSyncServiceProtocol
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ChildHome")

    private static let dismissedAchievementsKey = "hs.childHome.dismissedAchievementIds"

    /// Список ID скрытых ачивок — персистируется в UserDefaults.
    /// Аналогично `readNotificationIds` в ParentHomeInteractor.
    private var dismissedAchievementIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: Self.dismissedAchievementsKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.dismissedAchievementsKey)
        }
    }

    /// Кэш последнего ID — для повторного presentFetch при `dismissAchievement`.
    private var lastChildId: String?

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        missionSyncService: any DailyMissionSyncServiceProtocol = MockDailyMissionSyncService()
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.missionSyncService = missionSyncService
    }

    // MARK: - Public API

    func fetchChildData(_ request: ChildHomeModels.Fetch.Request) async {
        lastChildId = request.childId

        // Показываем честное пустое состояние немедленно, чтобы экран не мигал
        // во время async-загрузки из Realm. Никаких фейк-сессий/наград/серии —
        // реальные данные перетирают его, когда готовы.
        presenter?.presentFetch(buildEmptyResponse())

        // Реальные данные из Realm — основной путь.
        do {
            let profile = try await childRepository.fetch(id: request.childId)
            // Загружаем до 120 сессий для точного trailing-run стрика
            // (аналогично WorldMapInteractor.resolveDailyStreak).
            let recentSessions = (try? await sessionRepository.fetchRecent(
                childId: request.childId,
                limit: 120
            )) ?? []

            let response = buildResponse(profile: profile, recent: recentSessions)
            presenter?.presentFetch(response)
            // Синхронизируем виджет: анонимные данные, без имени ребёнка (COPPA-safe)
            await syncMissionWidget(response: response, streak: response.currentStreak)
        } catch {
            logger.error("ChildHome fetch failed: \(error.localizedDescription, privacy: .public)")
            // Профиль не загрузился — честное пустое состояние, без фабрикации.
            presenter?.presentFetch(buildEmptyResponse())
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
    }

    func tapMascot() async {
        logger.info("Mascot tapped — presenting encouragement phrase")
        presenter?.presentMascotTap(.init())
    }

    func refreshData(childId: String) async {
        logger.info("Pull-to-refresh: childId=\(childId, privacy: .public)")
        await fetchChildData(.init(childId: childId))
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
        // Стрик: единый trailing-run алгоритм через StreakCalculator (аналогично WorldMap).
        // recent содержит до 120 сессий — достаточно для точного подсчёта.
        // Если сессий нет (новый ребёнок) — берём значение из профиля.
        let streak = recent.isEmpty
            ? profile.currentStreak
            : StreakCalculator.activeDayStreak(in: recent)
        return ChildHomeModels.Fetch.Response(
            childName: profile.name,
            currentStreak: streak,
            mascotMood: Self.mascotMood(
                for: streak,
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
            hasOverdueTask: hasOverdueTask,
            todayWords: Self.buildTodayWords(sound: dailySound),
            // Реальных назначений ДЗ нет в этом источнике → честно пусто.
            homeTasks: []
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

    /// Собирает recent-sessions data из реальных сессий. Пусто → честно пусто
    /// (никаких seed-сессий новому ребёнку).
    private static func makeRecentForSection(
        from recent: [SessionDTO]
    ) -> [ChildHomeModels.RecentSessionData] {
        recent.map {
            ChildHomeModels.RecentSessionData(
                id: $0.id,
                date: $0.date,
                templateType: $0.templateType,
                targetSound: $0.targetSound,
                score: $0.successRate
            )
        }
    }

    /// B13: recentRewards из «успешных» сессий (≥ 0.85). Пусто → честно пусто.
    private static func makeRewardsForSection(
        from recent: [SessionDTO]
    ) -> [ChildHomeModels.RecentRewardData] {
        buildRecentRewards(from: recent)
    }

    /// Честное пустое состояние: показывается мгновенно во время загрузки и
    /// при ошибке загрузки профиля. Никаких фейк-сессий/наград/серии/заданий —
    /// нулевой прогресс и приветственный маскот-CTA для онбординга.
    private func buildEmptyResponse() -> ChildHomeModels.Fetch.Response {
        let dailySound = "Р"
        let requiredReps = 5
        let childName = String(localized: "child.default.name")
        return ChildHomeModels.Fetch.Response(
            childName: childName,
            currentStreak: 0,
            mascotMood: Self.mascotMood(for: 0, hasOverdueTask: false),
            mascotPhrase: Self.mascotPhrase(name: childName, sound: dailySound),
            dailyTargetSound: dailySound,
            dailyStage: Self.humanStage(for: 0.0),
            dailyProgress: 0.0,
            soundProgress: [],
            quickPlay: Self.seedQuickPlay(),
            worldZones: [],
            recentSessions: [],
            // Приветственная ачивка-онбординг (не фабрикация статистики):
            // показываем «первый урок впереди», пока ребёнок не скрыл её.
            achievement: dismissedAchievementIds.contains("seed-first-session")
                ? nil
                : ChildHomeModels.AchievementData(
                    id: "seed-first-session",
                    titleKey: "child.home.achievement.first.title",
                    descriptionKey: "child.home.achievement.first.description",
                    emoji: "party.popper.fill",
                    isNew: true
                ),
            dailyMissionDetail: ChildHomeModels.DailyMissionDetailData(
                id: "seed-mission-\(Self.dayOfYear)",
                titleKey: "child.home.mission.title.format",
                descriptionKey: "child.home.mission.description.format",
                targetSound: dailySound,
                templateType: TemplateType.repeatAfterModel.rawValue,
                requiredReps: requiredReps,
                completedReps: 0
            ),
            recentRewards: [],
            hasOverdueTask: false,
            todayWords: Self.buildTodayWords(sound: dailySound),
            homeTasks: []
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

    /// Сколько раз сегодня ребёнок уже корректно произнёс целевой звук
    /// (из реальных сессий) — прогресс дневной миссии, ограничен 5.
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
                emoji: "party.popper.fill",
                isNew: true
            )
        }
        let id = "ach-\(last.id)"
        if dismissed.contains(id) { return nil }
        return ChildHomeModels.AchievementData(
            id: id,
            titleKey: "child.home.achievement.streak.title",
            descriptionKey: "child.home.achievement.streak.description",
            emoji: "sparkles",
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
        .init(sound: "С", emoji: "water.waves", family: .whistling),
        .init(sound: "Ш", emoji: "leaf.fill", family: .hissing),
        .init(sound: "Р", emoji: "flame.fill", family: .sonorant),
        .init(sound: "Л", emoji: "moon.fill", family: .sonorant),
        .init(sound: "К", emoji: "mountain.2.fill", family: .velar)
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

    // MARK: - Curated quick-play tiles (legitimate content, not fabricated stats)

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
            ),
            .init(
                id: "qp-sorting",
                templateType: TemplateType.sorting.rawValue,
                titleKey: "child.home.quick.sorting",
                icon: "tray.2.fill",
                accent: .rose,
                difficulty: 2
            ),
            .init(
                id: "qp-minimalpairs",
                templateType: TemplateType.minimalPairs.rawValue,
                titleKey: "child.home.quick.minimalpairs",
                icon: "waveform.and.magnifyingglass",
                accent: .gold,
                difficulty: 3
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
        case 0.95...: return "trophy.fill"
        case 0.90..<0.95: return "medal.fill"
        default: return "medal"
        }
    }

    private static func rewardTitleKey(for score: Double) -> String {
        switch score {
        case 0.95...: return "child.home.rewards.gold"
        case 0.90..<0.95: return "child.home.rewards.silver"
        default: return "child.home.rewards.bronze"
        }
    }

    private static var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    // MARK: - TodayWords (curated word set per sound)

    /// Формирует список слов дня из курируемого методического набора для
    /// целевого звука (легитимный контент, не фабрикация статистики).
    private static func buildTodayWords(
        sound: String
    ) -> [ChildHomeModels.TodayWordData] {
        let wordMap: [String: [(word: String, syllables: String, pos: String)]] = [
            "Р": [
                ("рыба",  "ры-ба",    "init"),
                ("гора",  "го-ра",    "final"),
                ("ворона","во-ро-на", "mid"),
                ("рот",   "рот",      "init"),
                ("тигр",  "тигр",     "final")
            ],
            "Л": [
                ("лиса",  "ли-са",    "init"),
                ("стол",  "стол",     "final"),
                ("палка", "пал-ка",   "mid"),
                ("луна",  "лу-на",    "init"),
                ("вилка", "вил-ка",   "mid")
            ],
            "Ш": [
                ("шапка", "шап-ка",   "init"),
                ("кошка", "кош-ка",   "mid"),
                ("камыш", "ка-мыш",   "final"),
                ("шуба",  "шу-ба",    "init"),
                ("мишка", "миш-ка",   "mid")
            ],
            "С": [
                ("сова",  "со-ва",    "init"),
                ("оса",   "о-са",     "final"),
                ("весна", "вес-на",   "mid"),
                ("сок",   "сок",      "init"),
                ("лиса",  "ли-са",    "final")
            ]
        ]
        let pairs = wordMap[sound] ?? wordMap["Р"] ?? []
        return pairs.enumerated().map { idx, pair in
            ChildHomeModels.TodayWordData(
                id: "tw-\(sound)-\(idx)",
                word: pair.word,
                syllables: pair.syllables,
                targetSound: sound,
                soundPosition: pair.pos,
                successRate: nil
            )
        }
    }

    // MARK: - Widget Sync

    /// Синхронизирует App Group UserDefaults для виджета.
    /// COPPA: передаются только анонимные данные задания — без имени ребёнка.
    private func syncMissionWidget(
        response: ChildHomeModels.Fetch.Response,
        streak: Int
    ) async {
        let mission = response.dailyMissionDetail
        let soundName = response.dailyTargetSound.isEmpty
            ? String(localized: "child.home.widget.default_sound")
            : response.dailyTargetSound
        let title = String(
            format: String(localized: "child.home.widget.sound_title"),
            soundName
        )
        let description = String(
            format: NSLocalizedString("child.home.mission.rounds_count", comment: ""),
            mission.requiredReps
        )
        let progress: Double = mission.requiredReps > 0
            ? Double(mission.completedReps) / Double(mission.requiredReps)
            : 0.0
        let lyalyaState: String
        switch response.mascotMood {
        case .happy, .celebrating, .waving:
            lyalyaState = "happy"
        case .sad, .thinking:
            lyalyaState = "sleepy"
        default:
            lyalyaState = "encouraging"
        }
        await missionSyncService.updateMission(
            title: title,
            description: description,
            streakDays: streak,
            lyalyaState: lyalyaState,
            progress: min(progress, 1.0)
        )
    }
}
