import SwiftUI
import WidgetKit

// MARK: - DailyMissionWidget

struct DailyMissionWidget: Widget {
    let kind: String = "DailyMissionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyMissionProvider()) { entry in
            DailyMissionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Задание дня"))
        .description(String(localized: "Сегодняшнее задание Ляли и серия"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
