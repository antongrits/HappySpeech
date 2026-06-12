import Foundation
import OSLog

// MARK: - FamilyChallengeBusinessLogic

@MainActor
protocol FamilyChallengeBusinessLogic: AnyObject {
    func loadChallenge(_ request: FamilyChallengeModels.LoadChallenge.Request) async
    func claimReward(_ request: FamilyChallengeModels.ClaimReward.Request) async
    func shareProgress(_ request: FamilyChallengeModels.ShareProgress.Request) async
}

// MARK: - FamilyChallengeInteractor

/// Управляет загрузкой активного семейного челленджа, claim-награды и
/// шерингом прогресса.
///
/// Данные реальные:
/// - Тип/цель/закрытые недели челленджа персистятся в `FamilyChallengeObject`
///   (Realm) через `RealmActor`.
/// - Вклады участников считаются из реальных сессий детей семьи: для каждого
///   ребёнка с этим `parentId` суммируются минуты практики за текущую неделю
///   (`SessionRepository`). Никаких dummy «Миша/Соня/Папа».
/// - `claimReward` персистит закрытие недели (идемпотентно).
/// - Если у родителя нет детей — отдаётся честное пустое состояние (нулевой
///   прогресс, пустой список вкладов), View показывает CTA «добавьте детей».
@MainActor
final class FamilyChallengeInteractor: FamilyChallengeBusinessLogic {

    var presenter: (any FamilyChallengePresentationLogic)?

    private let realmActor: RealmActor
    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let isKidContext: Bool

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyChallenge.Interactor"
    )

    // MARK: - Init

    init(
        realmActor: RealmActor,
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        isKidContext: Bool = false
    ) {
        self.realmActor = realmActor
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.isKidContext = isKidContext
    }

    // MARK: - Load

    func loadChallenge(_ request: FamilyChallengeModels.LoadChallenge.Request) async {
        logger.info("loadChallenge parentId=\(request.parentId, privacy: .private)")
        let challenge = await fetchActiveFamilyChallenge(parentId: request.parentId)
        await presenter?.presentChallenge(
            response: .init(challenge: challenge, isKidContext: isKidContext)
        )
    }

    // MARK: - Claim

    func claimReward(_ request: FamilyChallengeModels.ClaimReward.Request) async {
        logger.info("claimReward parentId=\(request.challengeId, privacy: .public)")
        // request.challengeId здесь — parentId (см. View.claimTapped).
        let weekStart = weekStart(for: Date())

        // P2-6: НЕ доверяем только видимости кнопки во View — проверяем реальный
        // прогресс в интеракторе. `current` собирается из недельных минут реальных
        // детей семьи. Если цель не достигнута — claim отклоняется (награда не
        // персистится, конфетти не показываются).
        let challenge = await fetchActiveFamilyChallenge(parentId: request.challengeId)
        guard challenge.current >= challenge.goal else {
            logger.info(
                "claimReward rejected: progress \(challenge.current, privacy: .public)/\(challenge.goal, privacy: .public) < goal"
            )
            await presenter?.presentClaimedReward(
                response: .init(challengeId: request.challengeId, confettiShown: false)
            )
            return
        }

        // Цель достигнута — персистим claim (идемпотентно: повторный claim той же
        // недели не дублирует запись).
        _ = await realmActor.claimFamilyChallengeWeek(
            parentId: request.challengeId,
            weekStart: weekStart
        )
        await presenter?.presentClaimedReward(
            response: .init(challengeId: request.challengeId, confettiShown: true)
        )
    }

    // MARK: - Share

    func shareProgress(_ request: FamilyChallengeModels.ShareProgress.Request) async {
        logger.info("shareProgress parentId=\(request.challengeId, privacy: .public)")
        let challenge = await fetchActiveFamilyChallenge(parentId: request.challengeId)
        let shareText = buildShareText(challenge: challenge)
        await presenter?.presentShareProgress(
            response: .init(shareText: shareText)
        )
    }

    // MARK: - Private

    private static let defaultGoalMinutes = 300

    /// Собирает активный челлендж семьи из реальных данных: тип/цель/серия из
    /// `FamilyChallengeObject`, вклады — из недельных минут реальных детей.
    private func fetchActiveFamilyChallenge(parentId: String) async -> FamilyChallengeDTO {
        let weekStart = weekStart(for: Date())
        let stored = await realmActor.fetchOrCreateFamilyChallenge(
            parentId: parentId,
            defaultType: ChallengeType.totalMinutes.rawValue,
            defaultGoal: Self.defaultGoalMinutes,
            weekStart: weekStart
        )
        let type = ChallengeType(rawValue: stored.type) ?? .totalMinutes

        let contributions = await buildContributions(
            parentId: parentId,
            type: type,
            weekStart: weekStart
        )
        let totalCurrent = contributions.reduce(0) { $0 + $1.value }
        // streakWeeks — число закрытых недель подряд, заканчивающееся текущей
        // или предыдущей неделей.
        let streakWeeks = consecutiveClaimedWeeks(
            claimed: stored.claimedWeekStarts,
            currentWeekStart: weekStart
        )

        return FamilyChallengeDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000C001") ?? UUID(),
            parentId: parentId,
            type: type,
            goal: stored.goal,
            current: totalCurrent,
            weekStart: weekStart,
            contributions: contributions,
            streakWeeks: streakWeeks
        )
    }

    /// Реальные вклады: для каждого ребёнка семьи — сумма единиц челленджа за
    /// текущую неделю. Пусто, если детей нет (честное пустое состояние).
    private func buildContributions(
        parentId: String,
        type: ChallengeType,
        weekStart: Date
    ) async -> [Contribution] {
        let children = (try? await childRepository.fetchAll()) ?? []
        let familyChildren = children.filter { $0.parentId == parentId }
        guard !familyChildren.isEmpty else { return [] }

        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        var result: [Contribution] = []
        for child in familyChildren {
            let sessions = (try? await sessionRepository.fetchAll(childId: child.id)) ?? []
            let weekSessions = sessions.filter { $0.date >= weekStart && $0.date < weekEnd }
            let value = contributionValue(type: type, sessions: weekSessions)
            result.append(
                Contribution(
                    id: child.id,
                    memberName: child.name,
                    memberEmoji: "🌟",
                    value: value,
                    isChild: true
                )
            )
        }
        return result
    }

    /// Считает вклад ребёнка в единицах конкретного типа челленджа за неделю.
    private func contributionValue(type: ChallengeType, sessions: [SessionDTO]) -> Int {
        switch type {
        case .totalMinutes:
            let seconds = sessions.reduce(0) { $0 + $1.durationSeconds }
            return max(0, Int((Double(seconds) / 60.0).rounded()))
        case .newSounds:
            return Set(sessions.map(\.targetSound)).count
        case .coPlaySessions, .fluencyDiaryEntries:
            return sessions.count
        }
    }

    /// Число закрытых недель подряд (claim), оканчивающееся текущей или
    /// прошлой неделей.
    private func consecutiveClaimedWeeks(claimed: [Date], currentWeekStart: Date) -> Int {
        guard !claimed.isEmpty else { return 0 }
        let calendar = Calendar(identifier: .iso8601)
        let claimedDays = Set(claimed.map { calendar.startOfDay(for: $0) })

        var cursor = calendar.startOfDay(for: currentWeekStart)
        if !claimedDays.contains(cursor) {
            guard let prevWeek = calendar.date(byAdding: .day, value: -7, to: cursor),
                  claimedDays.contains(prevWeek) else {
                return 0
            }
            cursor = prevWeek
        }
        var streak = 0
        while claimedDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -7, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func buildShareText(challenge: FamilyChallengeDTO) -> String {
        String(
            format: String(localized: "family.challenge.share.text %lld %lld %@"),
            challenge.current,
            challenge.goal,
            challenge.type.unitLabel
        )
    }

    /// Понедельник 00:00 текущей недели.
    private func weekStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}
