import Foundation
import OSLog

// MARK: - AwardsCatalogWorkerProtocol

@MainActor
protocol AwardsCatalogWorkerProtocol: AnyObject {
    /// Возвращает все награды, разблокированные детьми текущего родителя.
    /// Награды сразу группируются по `AwardTier` и сортируются по дате.
    func fetchUnlocked(parentId: String) async -> [FamilyAwardsCabinetModels.Load.ShelfBucket]
}

// MARK: - AwardsCatalogWorker

@MainActor
final class AwardsCatalogWorker: AwardsCatalogWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyAwardsCabinet.CatalogWorker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func fetchUnlocked(parentId: String) async -> [FamilyAwardsCabinetModels.Load.ShelfBucket] {
        let children: [ChildProfileDTO]
        do {
            // parentId-фильтрация: возьмём всех, потом filter (Realm возвращает копии DTO).
            // Это намеренно — Specialist может видеть нескольких родителей,
            // а filter Realm-actor'a выходит за скоуп AE batch 2.
            let all = try await childRepository.fetchAll()
            children = all.filter { $0.parentId.isEmpty || $0.parentId == parentId }
            Self.logger.debug("Children for parent=\(parentId, privacy: .private): \(children.count)")
        } catch {
            Self.logger.error("fetchAll failed: \(error.localizedDescription, privacy: .public)")
            children = []
        }

        let awards = AwardsCabinetSeed.unlocked(for: children)

        // Группируем по tier, сортируя tier-ы по rank desc, награды внутри tier — по дате desc.
        let grouped = Dictionary(grouping: awards) { $0.tier }
        let buckets: [FamilyAwardsCabinetModels.Load.ShelfBucket] = AwardTier.allCases
            .sorted { $0.rank > $1.rank }
            .map { tier in
                let inTier = (grouped[tier] ?? []).sorted { $0.unlockedDate > $1.unlockedDate }
                return FamilyAwardsCabinetModels.Load.ShelfBucket(tier: tier, awards: inTier)
            }
        return buckets
    }
}
