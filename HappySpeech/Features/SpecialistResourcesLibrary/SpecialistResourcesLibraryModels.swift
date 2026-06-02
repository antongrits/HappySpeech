import Foundation

// MARK: - SpecialistResourcesLibraryModels

/// Модели библиотеки методических ресурсов специалиста.
///
/// Ресурсы берутся из `SpecialistResourcesLibraryContent`; «прочитано» и
/// «избранное» персистятся через `SpecialistResourcesLibraryStore`.
enum SpecialistResourcesLibraryModels {

    enum ResourceKind: String, CaseIterable, Hashable, Identifiable {
        case all
        case pdf
        case video
        case article
        case saved

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:     return String(localized: "resourcesLibrary.kind.all")
            case .pdf:     return String(localized: "resourcesLibrary.kind.pdf")
            case .video:   return String(localized: "resourcesLibrary.kind.video")
            case .article: return String(localized: "resourcesLibrary.kind.article")
            case .saved:   return String(localized: "resourcesLibrary.kind.saved")
            }
        }

        var icon: String {
            switch self {
            case .all:     return "rectangle.stack"
            case .pdf:     return "doc.text.fill"
            case .video:   return "play.rectangle.fill"
            case .article: return "newspaper.fill"
            case .saved:   return "bookmark.fill"
            }
        }
    }

    struct Resource: Identifiable, Hashable {
        let id: String
        let title: String
        let summary: String
        /// Реальный методический текст ресурса — открывается в ридере.
        let body: String
        let kind: ResourceKind
        let durationLabel: String
        var isRead: Bool = false
        var isSaved: Bool = false
    }

    struct ViewState: Equatable {
        var resources: [Resource]
        var filter: ResourceKind
        /// Открытый в ридере ресурс (`nil` — ридер закрыт).
        var openedResource: Resource?

        var filtered: [Resource] {
            switch filter {
            case .all:   return resources
            case .saved: return resources.filter(\.isSaved)
            default:     return resources.filter { $0.kind == filter }
            }
        }

        var readCount: Int { resources.filter(\.isRead).count }
        var savedCount: Int { resources.filter(\.isSaved).count }

        static let initial = ViewState(
            resources: SpecialistResourcesLibraryContent.resources,
            filter: .all
        )
    }
}
