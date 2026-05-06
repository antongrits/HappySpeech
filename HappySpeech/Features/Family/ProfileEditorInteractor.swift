import Foundation
import OSLog

// MARK: - ProfileEditorInteractor
//
// Управляет экраном редактирования профиля ребёнка.
//
// Функциональность (D.1 v15):
//   1. Загрузка профиля по childId из Realm.
//   2. Валидация полей перед сохранением:
//      - имя: 2–30 символов, только буквы/пробелы/дефис;
//      - возраст: 5–8 лет;
//      - аватар: один из 10+ предустановленных идентификаторов;
//      - тема: одна из 5 тем.
//   3. Проверка уникальности имени среди братьев/сестёр.
//   4. Persistent save через ChildRepository.
//   5. Управление выбором целевых звуков (добавить/удалить).
//   6. Undo-логика: возврат к исходным значениям (cancelEditing).
//   7. Аватар-категории: животные, транспорт, природа — группировка для галереи.
//   8. Вычисление прогресса по звукам для preview в редакторе.

@MainActor
final class ProfileEditorInteractor {

    // MARK: - VIP wiring

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProfileEditorInteractor")
    private let childRepository: any ChildRepository
    weak var presenter: ProfileEditorPresenter?

    // MARK: - State

    /// Снимок профиля на момент загрузки (для undo).
    private var originalProfile: ChildProfileDTO?

    /// ID текущего редактируемого ребёнка.
    private var currentChildId: String = ""

    /// Кеш всех профилей семьи (для проверки уникальности имени).
    private var siblingProfiles: [ChildProfileDTO] = []

    // MARK: - Init

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    // MARK: - Load

    func load(_ request: ProfileEditor.LoadRequest) async {
        presenter?.presentLoading()
        currentChildId = request.childId
        do {
            // Загружаем целевой профиль и все профили семьи параллельно.
            async let targetFetch = childRepository.fetch(id: request.childId)
            async let allFetch    = childRepository.fetchAll()

            let dto  = try await targetFetch
            let all  = try await allFetch

            originalProfile = dto
            siblingProfiles = all.filter { $0.id != request.childId }

            let sibCount = siblingProfiles.count
            logger.info(
                "ProfileEditorInteractor: loaded child, siblings=\(sibCount, privacy: .public)"
            )

            presenter?.presentLoaded(ProfileEditor.LoadResponse(
                childId:      dto.id,
                name:         dto.name,
                age:          dto.age,
                avatarStyle:  dto.avatarStyle,
                colorTheme:   dto.colorTheme,
                targetSounds: dto.targetSounds
            ))

            // После основного load — вычисляем прогресс по звукам для preview.
            let soundProgress = buildSoundProgress(from: dto)
            presenter?.presentSoundProgress(
                ProfileEditor.SoundProgressResponse(items: soundProgress)
            )
        } catch {
            logger.error("ProfileEditorInteractor: load failed \(error.localizedDescription, privacy: .public)")
            presenter?.presentError(error)
        }
    }

    // MARK: - Validate

    /// Валидирует текущие данные формы без сохранения. Вызывается на каждое onChange.
    func validate(_ request: ProfileEditor.ValidateRequest) async {
        let result = performValidation(
            name:        request.name,
            age:         request.age,
            avatarStyle: request.avatarStyle,
            colorTheme:  request.colorTheme
        )
        presenter?.presentValidation(ProfileEditor.ValidateResponse(
            isValid:  result.isValid,
            errors:   result.errors,
            warnings: result.warnings
        ))
    }

    // MARK: - Save

    func save(_ request: ProfileEditor.SaveRequest) async {
        let trimmedName = request.name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Предварительная валидация.
        let validation = performValidation(
            name:        trimmedName,
            age:         request.age,
            avatarStyle: request.avatarStyle,
            colorTheme:  request.colorTheme
        )
        guard validation.isValid else {
            presenter?.presentSaved(ProfileEditor.SaveResponse(
                success:      false,
                errorMessage: validation.errors.first
            ))
            let errSummary = validation.errors.joined(separator: ", ")
            logger.warning(
                "ProfileEditorInteractor: save aborted — \(errSummary, privacy: .public)"
            )
            return
        }

        // Проверка уникальности имени среди братьев/сестёр.
        if let duplicate = siblingProfiles.first(where: {
            $0.name.lowercased() == trimmedName.lowercased()
        }) {
            let msg = String(
                format: String(localized: "profile.editor.error.duplicate_name"),
                duplicate.name
            )
            presenter?.presentSaved(ProfileEditor.SaveResponse(success: false, errorMessage: msg))
            logger.warning(
                "ProfileEditorInteractor: duplicate name '\(trimmedName, privacy: .private)'"
            )
            return
        }

        presenter?.presentSaving()

        do {
            guard let existing = originalProfile else {
                throw ProfileEditorError.profileNotLoaded
            }

            let updated = ChildProfileDTO(
                id:                existing.id,
                name:              trimmedName,
                age:               request.age,
                targetSounds:      existing.targetSounds,
                createdAt:         existing.createdAt,
                parentId:          existing.parentId,
                progressSummary:   existing.progressSummary,
                avatarStyle:       request.avatarStyle,
                colorTheme:        request.colorTheme,
                sensitivityLevel:  existing.sensitivityLevel,
                totalSessionMinutes: existing.totalSessionMinutes,
                currentStreak:     existing.currentStreak,
                lastSessionAt:     existing.lastSessionAt
            )

            try await childRepository.save(updated)
            originalProfile = updated

            logger.info(
                "ProfileEditorInteractor: saved child '\(trimmedName, privacy: .private)'"
            )
            presenter?.presentSaved(ProfileEditor.SaveResponse(success: true, errorMessage: nil))
        } catch {
            logger.error("ProfileEditorInteractor: save failed \(error.localizedDescription, privacy: .public)")
            presenter?.presentSaved(ProfileEditor.SaveResponse(
                success:      false,
                errorMessage: error.localizedDescription
            ))
        }
    }

    // MARK: - Cancel (Undo)

    /// Возвращает форму к исходным значениям профиля.
    func cancelEditing() async {
        guard let original = originalProfile else { return }
        presenter?.presentLoaded(ProfileEditor.LoadResponse(
            childId:      original.id,
            name:         original.name,
            age:          original.age,
            avatarStyle:  original.avatarStyle,
            colorTheme:   original.colorTheme,
            targetSounds: original.targetSounds
        ))
        logger.debug("ProfileEditorInteractor: undo — restored original profile")
    }

    // MARK: - Target sounds management

    func addTargetSound(_ request: ProfileEditor.AddTargetSoundRequest) async {
        guard let existing = originalProfile else { return }
        guard !existing.targetSounds.contains(request.sound) else {
            logger.debug(
                "ProfileEditorInteractor: sound '\(request.sound, privacy: .public)' already in targets"
            )
            return
        }

        let updated = ChildProfileDTO(
            id:                  existing.id,
            name:                existing.name,
            age:                 existing.age,
            targetSounds:        existing.targetSounds + [request.sound],
            createdAt:           existing.createdAt,
            parentId:            existing.parentId,
            progressSummary:     existing.progressSummary,
            avatarStyle:         existing.avatarStyle,
            colorTheme:          existing.colorTheme,
            sensitivityLevel:    existing.sensitivityLevel,
            totalSessionMinutes: existing.totalSessionMinutes,
            currentStreak:       existing.currentStreak,
            lastSessionAt:       existing.lastSessionAt
        )

        do {
            try await childRepository.save(updated)
            originalProfile = updated
            let soundProgress = buildSoundProgress(from: updated)
            presenter?.presentSoundProgress(
                ProfileEditor.SoundProgressResponse(items: soundProgress)
            )
            logger.info(
                "ProfileEditorInteractor: added target sound '\(request.sound, privacy: .public)'"
            )
        } catch {
            logger.error(
                "ProfileEditorInteractor: addTargetSound failed \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func removeTargetSound(_ request: ProfileEditor.RemoveTargetSoundRequest) async {
        guard let existing = originalProfile else { return }
        let newSounds = existing.targetSounds.filter { $0 != request.sound }

        // Нельзя убрать все звуки — должен остаться хотя бы один.
        guard !newSounds.isEmpty else {
            presenter?.presentValidation(ProfileEditor.ValidateResponse(
                isValid:  false,
                errors:   [String(localized: "profile.editor.error.at_least_one_sound")],
                warnings: []
            ))
            return
        }

        let updated = ChildProfileDTO(
            id:                  existing.id,
            name:                existing.name,
            age:                 existing.age,
            targetSounds:        newSounds,
            createdAt:           existing.createdAt,
            parentId:            existing.parentId,
            progressSummary:     existing.progressSummary,
            avatarStyle:         existing.avatarStyle,
            colorTheme:          existing.colorTheme,
            sensitivityLevel:    existing.sensitivityLevel,
            totalSessionMinutes: existing.totalSessionMinutes,
            currentStreak:       existing.currentStreak,
            lastSessionAt:       existing.lastSessionAt
        )

        do {
            try await childRepository.save(updated)
            originalProfile = updated
            let soundProgress = buildSoundProgress(from: updated)
            presenter?.presentSoundProgress(
                ProfileEditor.SoundProgressResponse(items: soundProgress)
            )
            logger.info(
                "ProfileEditorInteractor: removed target sound '\(request.sound, privacy: .public)'"
            )
        } catch {
            logger.error(
                "ProfileEditorInteractor: removeTargetSound failed \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Avatar gallery

    func loadAvatarGallery() async {
        let categories = ProfileEditorInteractor.buildAvatarCategories()
        presenter?.presentAvatarGallery(
            ProfileEditor.AvatarGalleryResponse(categories: categories)
        )
        logger.debug(
            "ProfileEditorInteractor: avatar gallery — \(categories.count, privacy: .public) categories"
        )
    }

    // MARK: - Private: validation

    private struct ValidationResult {
        let isValid: Bool
        let errors:   [String]
        let warnings: [String]
    }

    private func performValidation(
        name:        String,
        age:         Int,
        avatarStyle: String,
        colorTheme:  String
    ) -> ValidationResult {
        var errors:   [String] = []
        var warnings: [String] = []

        // Валидация имени
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            errors.append(String(localized: "profile.editor.error.name_too_short"))
        } else if trimmed.count > 30 {
            errors.append(String(localized: "profile.editor.error.name_too_long"))
        } else if !isValidNameCharacters(trimmed) {
            errors.append(String(localized: "profile.editor.error.name_invalid_chars"))
        }

        // Валидация возраста
        if age < 5 {
            errors.append(String(localized: "profile.editor.error.age_too_young"))
        } else if age > 8 {
            errors.append(String(localized: "profile.editor.error.age_too_old"))
        }

        // Валидация аватара
        let validAvatars = ProfileEditorInteractor.allAvatarIds
        if !validAvatars.contains(avatarStyle) {
            errors.append(String(localized: "profile.editor.error.invalid_avatar"))
        }

        // Валидация темы
        let validThemes = ["coral", "blue", "green", "yellow", "purple"]
        if !validThemes.contains(colorTheme) {
            errors.append(String(localized: "profile.editor.error.invalid_theme"))
        }

        // Предупреждения (не блокирующие)
        if trimmed.count > 20 {
            warnings.append(String(localized: "profile.editor.warning.name_long"))
        }

        return ValidationResult(
            isValid:  errors.isEmpty,
            errors:   errors,
            warnings: warnings
        )
    }

    /// Проверка допустимых символов: буквы (кириллица/латиница), пробел, дефис, апостроф.
    private func isValidNameCharacters(_ name: String) -> Bool {
        let allowed = CharacterSet.letters
            .union(.init(charactersIn: " -'"))
        return name.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Private: sound progress

    private func buildSoundProgress(from dto: ChildProfileDTO) -> [ProfileEditor.SoundProgressItem] {
        dto.targetSounds.map { sound in
            let accuracy = dto.progressSummary[sound] ?? 0.0
            let level = progressLevel(accuracy: accuracy)
            return ProfileEditor.SoundProgressItem(
                sound:    sound,
                accuracy: accuracy,
                level:    level
            )
        }.sorted { $0.sound < $1.sound }
    }

    private func progressLevel(accuracy: Double) -> ProfileEditor.ProgressLevel {
        switch accuracy {
        case ..<0.4:   return .beginning
        case 0.4..<0.7: return .developing
        case 0.7..<0.9: return .proficient
        default: return .achieved
        }
    }

    // MARK: - Static avatar catalog

    static let allAvatarIds: [String] = [
        // Животные
        "butterfly", "dragon", "unicorn", "cat", "fox",
        // Транспорт
        "rocket", "train", "boat",
        // Природа
        "star", "sun"
    ]

    static func buildAvatarCategories() -> [ProfileEditor.AvatarCategory] {
        [
            ProfileEditor.AvatarCategory(
                id: "animals",
                localizedName: String(localized: "avatar.category.animals"),
                avatarIds: ["butterfly", "dragon", "unicorn", "cat", "fox"]
            ),
            ProfileEditor.AvatarCategory(
                id: "transport",
                localizedName: String(localized: "avatar.category.transport"),
                avatarIds: ["rocket", "train", "boat"]
            ),
            ProfileEditor.AvatarCategory(
                id: "nature",
                localizedName: String(localized: "avatar.category.nature"),
                avatarIds: ["star", "sun"]
            )
        ]
    }
}

// MARK: - ProfileEditorError

private enum ProfileEditorError: LocalizedError {
    case profileNotLoaded

    var errorDescription: String? {
        switch self {
        case .profileNotLoaded:
            return String(localized: "profile.editor.error.not_loaded")
        }
    }
}

// MARK: - ProfileEditor Models extension (D.1 v15)

extension ProfileEditor {

    struct ValidateRequest {
        let name:        String
        let age:         Int
        let avatarStyle: String
        let colorTheme:  String
    }

    struct ValidateResponse {
        let isValid:  Bool
        let errors:   [String]
        let warnings: [String]
    }

    struct AddTargetSoundRequest { let sound: String }
    struct RemoveTargetSoundRequest { let sound: String }

    struct SoundProgressResponse {
        let items: [SoundProgressItem]
    }

    struct SoundProgressItem: Identifiable {
        var id: String { sound }
        let sound:    String
        let accuracy: Double
        let level:    ProgressLevel
    }

    enum ProgressLevel: String {
        case beginning
        case developing
        case proficient
        case achieved

        var localizedLabel: String {
            switch self {
            case .beginning: return String(localized: "progress.level.beginning")
            case .developing: return String(localized: "progress.level.developing")
            case .proficient: return String(localized: "progress.level.proficient")
            case .achieved: return String(localized: "progress.level.mastered")
            }
        }
    }

    struct AvatarGalleryResponse {
        let categories: [AvatarCategory]
    }

    struct AvatarCategory: Identifiable {
        let id:            String
        let localizedName: String
        let avatarIds:     [String]
    }
}

// MARK: - ProfileEditorPresenter extension (D.1 v15)

extension ProfileEditorPresenter {
    func presentValidation(_ response: ProfileEditor.ValidateResponse) {}
    func presentSoundProgress(_ response: ProfileEditor.SoundProgressResponse) {}
    func presentAvatarGallery(_ response: ProfileEditor.AvatarGalleryResponse) {}
}
