import SwiftUI
import WidgetKit

// MARK: - QuickLessonItem

struct QuickLessonItem: Codable {
    let soundId: String
    let title: String
    let deepLink: String
    let type: QuickLessonType

    enum QuickLessonType: String, Codable {
        case recent
        case favorite
        case recommended
    }
}

// MARK: - LessonQuickEntry

struct LessonQuickEntry: TimelineEntry {
    let date: Date
    let items: [QuickLessonItem]
}

// MARK: - LessonQuickProvider

struct LessonQuickProvider: TimelineProvider {

    func placeholder(in context: Context) -> LessonQuickEntry {
        LessonQuickEntry(
            date: Date(),
            items: placeholderItems
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LessonQuickEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LessonQuickEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        let items = loadItems(from: defaults)
        let entry = LessonQuickEntry(date: Date(), items: items)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // MARK: Private

    private var placeholderItems: [QuickLessonItem] {
        [
            QuickLessonItem(soundId: "Ш", title: "Звук Ш", deepLink: "happyspeech://lesson?sound=Ш", type: .recent),
            QuickLessonItem(soundId: "Р", title: "Звук Р", deepLink: "happyspeech://lesson?sound=Р", type: .favorite),
            QuickLessonItem(soundId: "С", title: "Звук С", deepLink: "happyspeech://lesson?sound=С", type: .recommended)
        ]
    }

    private func loadItems(from defaults: UserDefaults?) -> [QuickLessonItem] {
        var result: [QuickLessonItem] = []

        if let recentSound = defaults?.string(forKey: "quick_lesson.recent_sound") {
            result.append(QuickLessonItem(
                soundId: recentSound,
                title: "Звук \(recentSound)",
                deepLink: "happyspeech://lesson?sound=\(recentSound)",
                type: .recent
            ))
        }

        if let favoriteSound = defaults?.string(forKey: "quick_lesson.favorite_sound") {
            result.append(QuickLessonItem(
                soundId: favoriteSound,
                title: "Звук \(favoriteSound)",
                deepLink: "happyspeech://lesson?sound=\(favoriteSound)",
                type: .favorite
            ))
        }

        if let recommendedSound = defaults?.string(forKey: "quick_lesson.recommended_sound") {
            result.append(QuickLessonItem(
                soundId: recommendedSound,
                title: "Звук \(recommendedSound)",
                deepLink: "happyspeech://lesson?sound=\(recommendedSound)",
                type: .recommended
            ))
        }

        return result.isEmpty ? placeholderItems : Array(result.prefix(3))
    }
}

// MARK: - LessonQuickWidgetView

struct LessonQuickWidgetView: View {
    let entry: LessonQuickEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "face.smiling.fill")
                    .foregroundStyle(.purple)
                    .accessibilityHidden(true)
                Text(String(localized: "Быстрый урок"))
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Spacer()
            }

            Divider()

            // Lesson CTAs
            if entry.items.isEmpty {
                Text(String(localized: "Нет доступных уроков"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.items, id: \.soundId) { item in
                    lessonRow(item)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .widgetURL(URL(string: "happyspeech://lesson-player"))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func lessonRow(_ item: QuickLessonItem) -> some View {
        let fallback = URL(fileURLWithPath: "/")
        let destination = URL(string: item.deepLink) ?? fallback
        return Link(destination: destination) {
            HStack(spacing: 8) {
                Circle()
                    .fill(typeColor(item.type).opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(item.soundId)
                            .font(.caption2.bold())
                            .foregroundStyle(typeColor(item.type))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(typeLabel(item.type))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(
            String(localized: "\(item.title), \(typeLabel(item.type)). Нажмите для начала.")
        )
    }

    private func typeColor(_ type: QuickLessonItem.QuickLessonType) -> Color {
        switch type {
        case .recent:      return .blue
        case .favorite:    return .pink
        case .recommended: return .purple
        }
    }

    private func typeLabel(_ type: QuickLessonItem.QuickLessonType) -> String {
        switch type {
        case .recent:      return "Недавний"
        case .favorite:    return "Любимый"
        case .recommended: return "Рекомендован"
        }
    }
}

// MARK: - LessonQuickWidget

struct LessonQuickWidget: Widget {
    let kind: String = "LessonQuickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LessonQuickProvider()) { entry in
            LessonQuickWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Быстрый урок"))
        .description(String(localized: "Три быстрых урока: недавний, любимый и рекомендованный Лялей"))
        .supportedFamilies([.systemMedium])
    }
}
