import Foundation
import OSLog

// MARK: - FamilyHomeInteractor

@MainActor
final class FamilyHomeInteractor {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyHomeInteractor")
    private let childRepository: any ChildRepository
    weak var presenter: FamilyHomePresenter?

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func load(_ request: FamilyHome.LoadRequest) async {
        presenter?.presentLoading()
        do {
            let dtos = try await childRepository.fetchAll()
            let summaries = dtos.filter { !$0.isArchived }.map { dto in
                FamilyHome.ChildSummary(
                    id: dto.id,
                    name: dto.name,
                    age: dto.age,
                    avatarStyle: dto.avatarStyle,
                    colorTheme: dto.colorTheme,
                    currentStreak: dto.currentStreak,
                    targetSounds: dto.targetSounds,
                    overallProgress: dto.overallProgress,
                    lastSessionAt: dto.lastSessionAt
                )
            }
            let parentName = UserDefaults.standard.string(forKey: "parentDisplayName") ?? ""
            presenter?.presentLoad(FamilyHome.LoadResponse(
                children: summaries,
                parentName: parentName
            ))
        } catch {
            logger.error("FamilyHomeInteractor: fetchAll failed \(error.localizedDescription)")
            presenter?.presentError(error)
        }
    }
}

// MARK: - ChildProfileDTO extension

private extension ChildProfileDTO {
    var isArchived: Bool { false }

    var overallProgress: Double {
        guard !progressSummary.isEmpty else { return 0 }
        let total = progressSummary.values.reduce(0, +)
        return total / Double(progressSummary.count)
    }
}
