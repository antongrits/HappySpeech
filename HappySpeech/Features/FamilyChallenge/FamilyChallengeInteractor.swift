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
/// шерингом прогресса. Сейчас Realm-схемы для `FamilyChallengeObject` нет —
/// возвращается mock из `defaultMockChallenge(parentId:)`. Это позволяет
/// демонстрировать экран без блокирующей зависимости на миграцию схемы.
///
/// Следующая итерация: добавить `FamilyChallengeObject` в Realm + метод
/// `realmActor.fetchActiveFamilyChallenge(parentId:)`, заменить mock на
/// реальное чтение. Сигнатура `loadChallenge(_:)` останется без изменений.
@MainActor
final class FamilyChallengeInteractor: FamilyChallengeBusinessLogic {

    var presenter: (any FamilyChallengePresentationLogic)?

    private let realmActor: RealmActor
    private let childRepository: any ChildRepository
    private let isKidContext: Bool

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyChallenge.Interactor"
    )

    // MARK: - Init

    init(
        realmActor: RealmActor,
        childRepository: any ChildRepository,
        isKidContext: Bool = false
    ) {
        self.realmActor = realmActor
        self.childRepository = childRepository
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
        logger.info("claimReward challengeId=\(request.challengeId, privacy: .public)")
        // В Realm пока не пишем — следующая итерация. Сейчас просто
        // презентуем тост-конфетти.
        await presenter?.presentClaimedReward(
            response: .init(challengeId: request.challengeId, confettiShown: true)
        )
    }

    // MARK: - Share

    func shareProgress(_ request: FamilyChallengeModels.ShareProgress.Request) async {
        logger.info("shareProgress challengeId=\(request.challengeId, privacy: .public)")
        let shareText = buildShareText()
        await presenter?.presentShareProgress(
            response: .init(shareText: shareText)
        )
    }

    // MARK: - Private

    /// Возвращает активный челлендж семьи. Если Realm-объекта нет — отдаёт
    /// детерминированный mock. Аргумент `parentId` идёт в DTO, чтобы View
    /// показывал корректный заголовок при смене profile.
    private func fetchActiveFamilyChallenge(parentId: String) async -> FamilyChallengeDTO {
        // Будущее: await realmActor.fetchActiveFamilyChallenge(parentId:).
        // Сейчас mock с детерминированной структурой.
        let mockContribs = await buildMockContributions(parentId: parentId)
        let totalCurrent = mockContribs.reduce(0) { $0 + $1.value }
        return FamilyChallengeDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000C001") ?? UUID(),
            parentId: parentId,
            type: .totalMinutes,
            goal: 300,
            current: totalCurrent,
            weekStart: weekStart(for: Date()),
            contributions: mockContribs,
            streakWeeks: 3
        )
    }

    /// Собирает mock-вклады. Если у родителя есть дети в Realm — добавляет
    /// их имена с детерминированными минутами. Плюс один взрослый-контрибьютор.
    private func buildMockContributions(parentId: String) async -> [Contribution] {
        var contribs: [Contribution] = []
        let children = (try? await childRepository.fetchAll()) ?? []
        // Берём первых двух детей с parentId.
        let filtered = children.filter { $0.parentId == parentId }.prefix(2)
        for (index, child) in filtered.enumerated() {
            // Детерминированные минуты: 95 / 70 — соответствует ТЗ.
            let value = index == 0 ? 95 : 70
            contribs.append(
                Contribution(
                    id: child.id,
                    memberName: child.name,
                    memberEmoji: "🌟",
                    value: value,
                    isChild: true
                )
            )
        }
        // Если детей нет — добавим dummy «Миша» и «Соня».
        if contribs.isEmpty {
            contribs.append(Contribution(id: "kid-1", memberName: "Миша", memberEmoji: "🌟", value: 95, isChild: true))
            contribs.append(Contribution(id: "kid-2", memberName: "Соня", memberEmoji: "🌟", value: 70, isChild: true))
        }
        // Взрослый-контрибьютор.
        contribs.append(
            Contribution(id: "adult-1", memberName: "Папа", memberEmoji: "🎯", value: 30, isChild: false)
        )
        return contribs
    }

    private func buildShareText() -> String {
        "Наша семья прошла 195 из 300 минут речевой практики на этой неделе! 🏆"
    }

    /// Понедельник 00:00 текущей недели.
    private func weekStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}
