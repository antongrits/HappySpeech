import Foundation

// MARK: - Specialist Models
//
// Типы специалистского контура, используемые живым экраном `SpecialistHomeView`
// (и его подкомпонентами `SpecialistHomeViewComponents` / `SpecialistHomeViewSheets`).
//
// Прежний VIP-стек (Interactor / Presenter / Router / DisplayLogic) удалён как
// неиспользуемый — живой путь рендерит экран напрямую через репозитории
// `AppContainer` и `SpecialistExportServiceLive`. Здесь остаются только те модели,
// на которые ссылается живой UI.

enum SpecialistModels {

    // MARK: - Fetch (сортировка списка детей)
    enum Fetch {
        struct Request {
            enum SortOrder: String, CaseIterable, Sendable {
                case byLastActivity = "По активности"
                case byName         = "По имени"
                case byProgress     = "По прогрессу"
            }
        }
    }

    // MARK: - RequestExport (формат экспорта отчёта)
    enum RequestExport {
        enum ExportFormat: String, CaseIterable, Sendable, Equatable {
            case pdf = "PDF"
            case csv = "CSV"
        }
    }
}

// MARK: - Domain Types

/// Заметка специалиста о ребёнке. Хранится в `@State` дашборда специалиста.
struct SpecialistNote: Identifiable, Sendable, Equatable {
    let id: String
    let childId: String
    let specialistId: String
    let text: String
    let createdAt: Date
}
