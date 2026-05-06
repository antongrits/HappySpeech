import Foundation
import OSLog

// MARK: - FamilyHomeInteractor
//
// Управляет главным экраном семьи (список детей + родительские инструменты).
//
// Функциональность (D.1 v15):
//   1. Загрузка до 3 профилей детей из Realm с агрегацией streak и прогресса.
//   2. Добавление нового ребёнка: валидация лимита 3 дети.
//   3. Удаление/архивирование профиля с подтверждением.
//   4. Переключение активного ребёнка (activeChildId в UserDefaults).
//   5. Сортировка: по имени / по последней сессии / по прогрессу.
//   6. Напоминание «сегодня ещё не занимались»: если lastSessionAt < начало дня.
//   7. Агрегация семейной статистики: суммарные минуты, суммарный streak,
//      средний прогресс всех детей.
//   8. Parent display name — загрузка и сохранение из UserDefaults.

@MainActor
final class FamilyHomeInteractor {

    // MARK: - VIP wiring

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyHomeInteractor")
    private let childRepository: any ChildRepository
    weak var presenter: FamilyHomePresenter?

    // MARK: - State

    /// Загруженные дети в текущей сортировке.
    private var loadedChildren: [ChildProfileDTO] = []

    /// Текущий порядок сортировки.
    private var sortOrder: FamilyHome.SortOrder = .byName

    // MARK: - Constants

    private let maxChildrenCount = 3
    private let parentNameKey    = "parentDisplayName"
    private let activeChildIdKey = "activeChildId"

    // MARK: - Init

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    // MARK: - Load

    func load(_ request: FamilyHome.LoadRequest) async {
        presenter?.presentLoading()
        do {
            let dtos = try await childRepository.fetchAll()
            let active = dtos.filter { !$0.isArchived }
            loadedChildren = active

            let sorted   = sortChildren(active, by: sortOrder)
            let summaries = sorted.map(makeSummary)
            let parentName = UserDefaults.standard.string(forKey: parentNameKey) ?? ""

            let familyStats = computeFamilyStats(from: active)
            let practiceReminders = buildPracticeReminders(for: active)

            let childCount = active.count
            let sortDesc = String(describing: sortOrder)
            logger.info(
                "FamilyHomeInteractor: loaded count=\(childCount, privacy: .public) sort=\(sortDesc, privacy: .public)"
            )

            presenter?.presentLoad(FamilyHome.LoadResponse(
                children:   summaries,
                parentName: parentName
            ))

            // Отдельно — семейная статистика и напоминания.
            presenter?.presentFamilyStats(FamilyHome.FamilyStatsResponse(stats: familyStats))

            if !practiceReminders.isEmpty {
                presenter?.presentPracticeReminders(
                    FamilyHome.PracticeReminderResponse(reminders: practiceReminders)
                )
            }
        } catch {
            logger.error(
                "FamilyHomeInteractor: load failed \(error.localizedDescription, privacy: .public)"
            )
            presenter?.presentError(error)
        }
    }

    // MARK: - Sort

    func sort(_ request: FamilyHome.SortRequest) async {
        sortOrder = request.order
        let sorted   = sortChildren(loadedChildren, by: sortOrder)
        let summaries = sorted.map(makeSummary)
        let parentName = UserDefaults.standard.string(forKey: parentNameKey) ?? ""
        presenter?.presentLoad(FamilyHome.LoadResponse(
            children:   summaries,
            parentName: parentName
        ))
        logger.debug(
            "FamilyHomeInteractor: sorted by \(String(describing: request.order), privacy: .public)"
        )
    }

    // MARK: - Select child

    func selectChild(_ request: FamilyHome.SelectChildRequest) async {
        UserDefaults.standard.set(request.childId, forKey: activeChildIdKey)
        logger.info(
            "FamilyHomeInteractor: active child → \(request.childId, privacy: .private)"
        )
        presenter?.presentChildSelected(
            FamilyHome.ChildSelectedResponse(childId: request.childId)
        )
    }

    // MARK: - Add child

    func addChild(_ request: FamilyHome.AddChildRequest) async {
        // Проверяем лимит.
        guard loadedChildren.count < maxChildrenCount else {
            let msg = String(
                format: String(localized: "family.home.error.max_children"),
                maxChildrenCount
            )
            presenter?.presentAddChildResult(
                FamilyHome.AddChildResponse(canAdd: false, errorMessage: msg)
            )
            logger.warning("FamilyHomeInteractor: max children limit reached (\(self.maxChildrenCount))")
            return
        }
        presenter?.presentAddChildResult(
            FamilyHome.AddChildResponse(canAdd: true, errorMessage: nil)
        )
    }

    // MARK: - Delete child

    func deleteChild(_ request: FamilyHome.DeleteChildRequest) async {
        // Нельзя удалить последнего ребёнка.
        guard loadedChildren.count > 1 else {
            let msg = String(localized: "family.home.error.cannot_delete_last")
            presenter?.presentDeleteResult(
                FamilyHome.DeleteChildResponse(success: false, errorMessage: msg)
            )
            return
        }

        do {
            try await childRepository.delete(id: request.childId)
            loadedChildren.removeAll { $0.id == request.childId }

            // Если удалили активного — переключаемся на первого из оставшихся.
            let currentActive = UserDefaults.standard.string(forKey: activeChildIdKey)
            if currentActive == request.childId, let first = loadedChildren.first {
                UserDefaults.standard.set(first.id, forKey: activeChildIdKey)
            }

            logger.info(
                "FamilyHomeInteractor: deleted child \(request.childId, privacy: .private)"
            )
            presenter?.presentDeleteResult(
                FamilyHome.DeleteChildResponse(success: true, errorMessage: nil)
            )

            // Перезагружаем список.
            await load(FamilyHome.LoadRequest())
        } catch {
            logger.error(
                "FamilyHomeInteractor: delete failed \(error.localizedDescription, privacy: .public)"
            )
            presenter?.presentDeleteResult(
                FamilyHome.DeleteChildResponse(success: false, errorMessage: error.localizedDescription)
            )
        }
    }

    // MARK: - Parent name

    func updateParentName(_ request: FamilyHome.UpdateParentNameRequest) async {
        let trimmed = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50 else {
            presenter?.presentParentNameUpdate(
                FamilyHome.ParentNameResponse(
                    success: false,
                    errorMessage: String(localized: "family.home.error.invalid_parent_name")
                )
            )
            return
        }
        UserDefaults.standard.set(trimmed, forKey: parentNameKey)
        logger.info("FamilyHomeInteractor: parent name updated")
        presenter?.presentParentNameUpdate(
            FamilyHome.ParentNameResponse(success: true, errorMessage: nil)
        )
    }

    // MARK: - Streak nudge

    /// Проверяет, требуется ли показать мотивационный nudge о стрике.
    func checkStreakNudge() async {
        let atRiskChildren = loadedChildren.filter { dto in
            // Стрик есть, но не занимались больше суток.
            guard dto.currentStreak > 0 else { return false }
            guard let last = dto.lastSessionAt else { return true }
            let elapsed = Date().timeIntervalSince(last)
            return elapsed > 20 * 3600  // 20 часов — предупреждение заранее
        }

        guard !atRiskChildren.isEmpty else { return }

        let names = atRiskChildren.prefix(2).map(\.name).joined(separator: ", ")
        let message = String(
            format: String(localized: "family.home.streak.at_risk"),
            names
        )
        logger.info(
            "FamilyHomeInteractor: streak at risk for \(atRiskChildren.count, privacy: .public) children"
        )
        presenter?.presentStreakNudge(
            FamilyHome.StreakNudgeResponse(
                message:       message,
                childrenAtRisk: atRiskChildren.map(\.id)
            )
        )
    }

    // MARK: - Private: sort

    private func sortChildren(
        _ children: [ChildProfileDTO],
        by order: FamilyHome.SortOrder
    ) -> [ChildProfileDTO] {
        switch order {
        case .byName:
            return children.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .byLastSession:
            return children.sorted { lhs, rhs in
                let lDate = lhs.lastSessionAt ?? .distantPast
                let rDate = rhs.lastSessionAt ?? .distantPast
                return lDate > rDate
            }
        case .byProgress:
            return children.sorted { $0.overallProgress > $1.overallProgress }
        }
    }

    // MARK: - Private: summary builder

    private func makeSummary(from dto: ChildProfileDTO) -> FamilyHome.ChildSummary {
        FamilyHome.ChildSummary(
            id:              dto.id,
            name:            dto.name,
            age:             dto.age,
            avatarStyle:     dto.avatarStyle,
            colorTheme:      dto.colorTheme,
            currentStreak:   dto.currentStreak,
            targetSounds:    dto.targetSounds,
            overallProgress: dto.overallProgress,
            lastSessionAt:   dto.lastSessionAt
        )
    }

    // MARK: - Private: family stats

    private func computeFamilyStats(from children: [ChildProfileDTO]) -> FamilyHome.FamilyStats {
        let totalMinutes   = children.map(\.totalSessionMinutes).reduce(0, +)
        let maxStreak      = children.map(\.currentStreak).max() ?? 0
        let avgProgress    = children.isEmpty ? 0.0 :
            children.map(\.overallProgress).reduce(0, +) / Double(children.count)
        let activeToday    = children.filter { dto in
            guard let last = dto.lastSessionAt else { return false }
            return Calendar.current.isDateInToday(last)
        }.count

        return FamilyHome.FamilyStats(
            childCount:      children.count,
            totalMinutes:    totalMinutes,
            bestStreak:      maxStreak,
            averageProgress: avgProgress,
            activeTodayCount: activeToday
        )
    }

    // MARK: - Private: practice reminders

    private func buildPracticeReminders(
        for children: [ChildProfileDTO]
    ) -> [FamilyHome.PracticeReminder] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        return children.compactMap { dto -> FamilyHome.PracticeReminder? in
            // Проверяем, была ли сессия сегодня.
            if let last = dto.lastSessionAt, last >= todayStart {
                return nil  // Занимались сегодня — напоминание не нужно.
            }
            let daysSinceLast: Int
            if let last = dto.lastSessionAt {
                let diff = calendar.dateComponents([.day], from: last, to: Date())
                daysSinceLast = max(0, diff.day ?? 0)
            } else {
                daysSinceLast = 999  // Никогда не занимались.
            }

            let urgency: FamilyHome.ReminderUrgency
            switch daysSinceLast {
            case 0:      return nil  // Занимались сегодня (уже отфильтровали выше).
            case 1:      urgency = .gentle
            case 2...3:  urgency = .moderate
            default:     urgency = .strong
            }

            return FamilyHome.PracticeReminder(
                childId:       dto.id,
                childName:     dto.name,
                daysSinceLast: daysSinceLast,
                urgency:       urgency
            )
        }
    }
}

// MARK: - ChildProfileDTO private extension

private extension ChildProfileDTO {
    var isArchived: Bool { false }

    var overallProgress: Double {
        guard !progressSummary.isEmpty else { return 0 }
        return progressSummary.values.reduce(0, +) / Double(progressSummary.count)
    }
}

// MARK: - FamilyHome Models extension (D.1 v15)

extension FamilyHome {

    enum SortOrder: String, CaseIterable {
        case byName
        case byLastSession
        case byProgress

        var localizedLabel: String {
            switch self {
            case .byName:        return String(localized: "family.home.sort.by_name")
            case .byLastSession: return String(localized: "family.home.sort.by_last_session")
            case .byProgress:    return String(localized: "family.home.sort.by_progress")
            }
        }
    }

    struct SortRequest { let order: SortOrder }
    struct DeleteChildRequest { let childId: String }
    struct UpdateParentNameRequest { let name: String }

    struct ChildSelectedResponse { let childId: String }

    struct AddChildResponse {
        let canAdd:       Bool
        let errorMessage: String?
    }

    struct DeleteChildResponse {
        let success:      Bool
        let errorMessage: String?
    }

    struct ParentNameResponse {
        let success:      Bool
        let errorMessage: String?
    }

    struct FamilyStats {
        let childCount:       Int
        let totalMinutes:     Int
        let bestStreak:       Int
        let averageProgress:  Double
        let activeTodayCount: Int
    }

    struct FamilyStatsResponse { let stats: FamilyStats }

    struct PracticeReminder: Identifiable {
        var id: String { childId }
        let childId:       String
        let childName:     String
        let daysSinceLast: Int
        let urgency:       ReminderUrgency
    }

    enum ReminderUrgency {
        case gentle, moderate, strong
    }

    struct PracticeReminderResponse { let reminders: [PracticeReminder] }

    struct StreakNudgeResponse {
        let message:        String
        let childrenAtRisk: [String]
    }
}

// MARK: - FamilyHomePresenter extension (D.1 v15)

extension FamilyHomePresenter {
    func presentFamilyStats(_ response: FamilyHome.FamilyStatsResponse) {}
    func presentPracticeReminders(_ response: FamilyHome.PracticeReminderResponse) {}
    func presentChildSelected(_ response: FamilyHome.ChildSelectedResponse) {}
    func presentAddChildResult(_ response: FamilyHome.AddChildResponse) {}
    func presentDeleteResult(_ response: FamilyHome.DeleteChildResponse) {}
    func presentParentNameUpdate(_ response: FamilyHome.ParentNameResponse) {}
    func presentStreakNudge(_ response: FamilyHome.StreakNudgeResponse) {}
}
