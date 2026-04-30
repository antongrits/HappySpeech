import Foundation
import OSLog

// MARK: - ProfileEditorInteractor

@MainActor
final class ProfileEditorInteractor {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProfileEditorInteractor")
    private let childRepository: any ChildRepository
    weak var presenter: ProfileEditorPresenter?

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func load(_ request: ProfileEditor.LoadRequest) async {
        presenter?.presentLoading()
        do {
            let dto = try await childRepository.fetch(id: request.childId)
            presenter?.presentLoaded(ProfileEditor.LoadResponse(
                childId: dto.id,
                name: dto.name,
                age: dto.age,
                avatarStyle: dto.avatarStyle,
                colorTheme: dto.colorTheme,
                targetSounds: dto.targetSounds
            ))
        } catch {
            logger.error("ProfileEditorInteractor: load failed \(error.localizedDescription)")
            presenter?.presentError(error)
        }
    }

    func save(_ request: ProfileEditor.SaveRequest) async {
        presenter?.presentSaving()
        do {
            let existing = try await childRepository.fetch(id: request.childId)
            let updated = ChildProfileDTO(
                id: existing.id,
                name: request.name.trimmingCharacters(in: .whitespaces),
                age: request.age,
                targetSounds: existing.targetSounds,
                createdAt: existing.createdAt,
                parentId: existing.parentId,
                progressSummary: existing.progressSummary,
                avatarStyle: request.avatarStyle,
                colorTheme: request.colorTheme,
                sensitivityLevel: existing.sensitivityLevel,
                totalSessionMinutes: existing.totalSessionMinutes,
                currentStreak: existing.currentStreak,
                lastSessionAt: existing.lastSessionAt
            )
            try await childRepository.save(updated)
            presenter?.presentSaved(ProfileEditor.SaveResponse(success: true, errorMessage: nil))
        } catch {
            logger.error("ProfileEditorInteractor: save failed \(error.localizedDescription)")
            presenter?.presentSaved(ProfileEditor.SaveResponse(
                success: false,
                errorMessage: error.localizedDescription
            ))
        }
    }
}
