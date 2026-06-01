import Foundation

// MARK: - SpecialistResourcesLibraryStore

/// Персистентное хранилище состояния ресурсов специалиста: какие отмечены
/// «прочитано» и какие добавлены «в избранное».
///
/// Привязано к специалисту (`specialistId`); множества id переживают
/// перезапуск.
struct SpecialistResourcesLibraryStore {

    private let defaults: UserDefaults
    private let specialistId: String

    init(defaults: UserDefaults = .standard, specialistId: String) {
        self.defaults = defaults
        self.specialistId = specialistId
    }

    private var readKey: String { "specResources.\(specialistId).read" }
    private var savedKey: String { "specResources.\(specialistId).saved" }

    func loadRead() -> Set<String> {
        guard !specialistId.isEmpty else { return [] }
        return Set(defaults.stringArray(forKey: readKey) ?? [])
    }

    func loadSaved() -> Set<String> {
        guard !specialistId.isEmpty else { return [] }
        return Set(defaults.stringArray(forKey: savedKey) ?? [])
    }

    func saveRead(_ ids: Set<String>) {
        guard !specialistId.isEmpty else { return }
        defaults.set(Array(ids), forKey: readKey)
    }

    func saveSaved(_ ids: Set<String>) {
        guard !specialistId.isEmpty else { return }
        defaults.set(Array(ids), forKey: savedKey)
    }
}
