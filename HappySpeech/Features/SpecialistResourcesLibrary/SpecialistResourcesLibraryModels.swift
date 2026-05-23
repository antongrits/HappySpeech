import Foundation

// MARK: - SpecialistResourcesLibraryModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SpecialistResourcesLibraryModels {

    enum ResourceKind: String, CaseIterable, Hashable, Identifiable {
        case all
        case pdf
        case video
        case article

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:     return "Все"
            case .pdf:     return "PDF"
            case .video:   return "Видео"
            case .article: return "Статьи"
            }
        }

        var icon: String {
            switch self {
            case .all:     return "rectangle.stack"
            case .pdf:     return "doc.text.fill"
            case .video:   return "play.rectangle.fill"
            case .article: return "newspaper.fill"
            }
        }
    }

    struct Resource: Identifiable, Hashable {
        let id: String
        let title: String
        let summary: String
        let kind: ResourceKind
        let durationLabel: String
    }

    struct ViewState: Equatable {
        var resources: [Resource]
        var filter: ResourceKind

        var filtered: [Resource] {
            filter == .all ? resources : resources.filter { $0.kind == filter }
        }

        static let initial = ViewState(
            resources: [
                Resource(id: "r1",
                         title: "Постановка звука Р",
                         summary: "Полный гайд от Фомичёвой",
                         kind: .pdf, durationLabel: "12 стр"),
                Resource(id: "r2",
                         title: "Артикуляционная гимнастика",
                         summary: "Видео-уроки для родителей",
                         kind: .video, durationLabel: "8 мин"),
                Resource(id: "r3",
                         title: "Дифференциация С/Ш",
                         summary: "Методика Ткаченко",
                         kind: .article, durationLabel: "5 мин"),
                Resource(id: "r4",
                         title: "Картотека скороговорок",
                         summary: "200+ упражнений по группам",
                         kind: .pdf, durationLabel: "34 стр"),
                Resource(id: "r5",
                         title: "Логоритмика дома",
                         summary: "Картушина / Волкова — 10 уроков",
                         kind: .video, durationLabel: "20 мин"),
                Resource(id: "r6",
                         title: "Развитие связной речи",
                         summary: "Глухов — пересказ + рассказ",
                         kind: .article, durationLabel: "7 мин"),
                Resource(id: "r7",
                         title: "Билингвизм и логопедия",
                         summary: "Цейтлин — два языка с рождения",
                         kind: .article, durationLabel: "9 мин"),
                Resource(id: "r8",
                         title: "Дыхательная гимнастика",
                         summary: "Стрельникова для детей",
                         kind: .pdf, durationLabel: "6 стр")
            ],
            filter: .all
        )
    }
}
