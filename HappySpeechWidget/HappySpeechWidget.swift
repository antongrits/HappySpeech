import SwiftUI
import WidgetKit

// MARK: - Shared storage keys

private enum SharedStorage {
    static let appGroupID      = "group.ru.happyspeech.app"
    static let keyCurrentSound = "widget.currentSound"
    static let keyStreak       = "widget.streak"
}

// MARK: - Entry

struct HappySpeechEntry: TimelineEntry {
    let date: Date
    let currentSound: String
    let streak: Int
}

// MARK: - Provider

struct HappySpeechProvider: TimelineProvider {

    // MARK: - Shared defaults

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedStorage.appGroupID)
    }

    private var currentSound: String {
        sharedDefaults?.string(forKey: SharedStorage.keyCurrentSound) ?? "Р"
    }

    private var streak: Int {
        sharedDefaults?.integer(forKey: SharedStorage.keyStreak) ?? 0
    }

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> HappySpeechEntry {
        HappySpeechEntry(date: .now, currentSound: "Р", streak: 7)
    }

    func getSnapshot(in context: Context, completion: @escaping (HappySpeechEntry) -> Void) {
        completion(HappySpeechEntry(date: .now, currentSound: currentSound, streak: streak))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HappySpeechEntry>) -> Void) {
        let entry = HappySpeechEntry(date: .now, currentSound: currentSound, streak: streak)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget View

struct HappySpeechWidgetEntryView: View {

    let entry: HappySpeechEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.purple)
                    .font(.title2)
                Spacer()
                if entry.streak > 0 {
                    Label("\(entry.streak)", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            Text("Сегодня учим")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Звук \(entry.currentSound)")
                .font(.title2.bold())
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct HappySpeechWidget: Widget {
    let kind: String = "HappySpeechWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HappySpeechProvider()) { entry in
            HappySpeechWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HappySpeech")
        .description("Сегодняшний звук и серия занятий.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    HappySpeechWidget()
} timeline: {
    HappySpeechEntry(date: .now, currentSound: "Р", streak: 5)
    HappySpeechEntry(date: .now, currentSound: "Ш", streak: 6)
}
