import Foundation
import OSLog

// MARK: - SpecialistResourcesLibraryInteractor

/// Бизнес-логика библиотеки ресурсов специалиста.
///
/// Ресурсы берутся из `SpecialistResourcesLibraryContent`; состояние
/// «прочитано»/«избранное» восстанавливается из
/// `SpecialistResourcesLibraryStore` при старте и сохраняется при изменениях —
/// переживает перезапуск. Поддерживает фильтр по типу и по избранному.
@MainActor
@Observable
final class SpecialistResourcesLibraryInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistResourcesLibrary"
    )

    let specialistId: String
    var state: SpecialistResourcesLibraryModels.ViewState

    private let store: SpecialistResourcesLibraryStore

    init(specialistId: String, defaults: UserDefaults = .standard) {
        self.specialistId = specialistId
        self.store = SpecialistResourcesLibraryStore(defaults: defaults, specialistId: specialistId)
        var initial = SpecialistResourcesLibraryModels.ViewState.initial
        let read = store.loadRead()
        let saved = store.loadSaved()
        initial.resources = initial.resources.map { resource in
            var copy = resource
            copy.isRead = read.contains(resource.id)
            copy.isSaved = saved.contains(resource.id)
            return copy
        }
        self.state = initial
    }

    func setFilter(_ kind: SpecialistResourcesLibraryModels.ResourceKind) {
        state.filter = kind
        Self.logger.info("setFilter \(kind.rawValue, privacy: .public)")
    }

    /// Открыть ресурс в ридере (показ методического текста) и пометить
    /// прочитанным — открытие = чтение.
    func open(_ id: String) {
        guard let idx = state.resources.firstIndex(where: { $0.id == id }) else { return }
        if !state.resources[idx].isRead {
            state.resources[idx].isRead = true
            persistRead()
        }
        state.openedResource = state.resources[idx]
        Self.logger.info("open \(id, privacy: .public)")
    }

    /// Закрыть ридер.
    func closeReader() {
        state.openedResource = nil
    }

    /// Отметить/снять «прочитано» для ресурса.
    func toggleRead(_ id: String) {
        guard let idx = state.resources.firstIndex(where: { $0.id == id }) else { return }
        state.resources[idx].isRead.toggle()
        persistRead()
        Self.logger.info("toggleRead \(id, privacy: .public) → \(self.state.resources[idx].isRead)")
    }

    /// Добавить/убрать «в избранное».
    func toggleSaved(_ id: String) {
        guard let idx = state.resources.firstIndex(where: { $0.id == id }) else { return }
        state.resources[idx].isSaved.toggle()
        persistSaved()
        Self.logger.info("toggleSaved \(id, privacy: .public) → \(self.state.resources[idx].isSaved)")
    }

    private func persistRead() {
        store.saveRead(Set(state.resources.filter(\.isRead).map(\.id)))
    }

    private func persistSaved() {
        store.saveSaved(Set(state.resources.filter(\.isSaved).map(\.id)))
    }
}
