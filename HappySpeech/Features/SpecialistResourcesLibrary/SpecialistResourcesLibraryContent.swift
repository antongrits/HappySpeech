import Foundation

// MARK: - SpecialistResourcesLibraryContent

/// Курируемый каталог методических ресурсов для специалиста (логопеда).
///
/// Вынесен из ViewState — единый источник правды. Ресурсы сгруппированы по типу
/// (PDF / видео / статья) и описывают методическую литературу русской
/// логопедии. `id` стабилен (для персистентности «прочитано»/«в избранном»).
enum SpecialistResourcesLibraryContent {

    static let resources: [SpecialistResourcesLibraryModels.Resource] = [
        .init(id: "r1",
              title: String(localized: "resources.r1.title"),
              summary: String(localized: "resources.r1.summary"),
              kind: .pdf, durationLabel: "12 стр"),
        .init(id: "r2",
              title: String(localized: "resources.r2.title"),
              summary: String(localized: "resources.r2.summary"),
              kind: .video, durationLabel: "8 мин"),
        .init(id: "r3",
              title: String(localized: "resources.r3.title"),
              summary: String(localized: "resources.r3.summary"),
              kind: .article, durationLabel: "5 мин"),
        .init(id: "r4",
              title: String(localized: "resources.r4.title"),
              summary: String(localized: "resources.r4.summary"),
              kind: .pdf, durationLabel: "34 стр"),
        .init(id: "r5",
              title: String(localized: "resources.r5.title"),
              summary: String(localized: "resources.r5.summary"),
              kind: .video, durationLabel: "20 мин"),
        .init(id: "r6",
              title: String(localized: "resources.r6.title"),
              summary: String(localized: "resources.r6.summary"),
              kind: .article, durationLabel: "7 мин"),
        .init(id: "r7",
              title: String(localized: "resources.r7.title"),
              summary: String(localized: "resources.r7.summary"),
              kind: .article, durationLabel: "9 мин"),
        .init(id: "r8",
              title: String(localized: "resources.r8.title"),
              summary: String(localized: "resources.r8.summary"),
              kind: .pdf, durationLabel: "6 стр"),
        .init(id: "r9",
              title: String(localized: "resources.r9.title"),
              summary: String(localized: "resources.r9.summary"),
              kind: .video, durationLabel: "14 мин"),
        .init(id: "r10",
              title: String(localized: "resources.r10.title"),
              summary: String(localized: "resources.r10.summary"),
              kind: .pdf, durationLabel: "22 стр"),
        .init(id: "r11",
              title: String(localized: "resources.r11.title"),
              summary: String(localized: "resources.r11.summary"),
              kind: .article, durationLabel: "6 мин"),
        .init(id: "r12",
              title: String(localized: "resources.r12.title"),
              summary: String(localized: "resources.r12.summary"),
              kind: .video, durationLabel: "11 мин")
    ]
}
