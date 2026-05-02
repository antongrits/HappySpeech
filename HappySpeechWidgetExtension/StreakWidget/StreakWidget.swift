import SwiftUI
import WidgetKit

// MARK: - StreakEntry

struct StreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let lastSessionDateString: String
    let topSoundId: String
    let gradientStart: Color
    let gradientEnd: Color
}

// MARK: - StreakProvider

struct StreakProvider: TimelineProvider {

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(
            date: Date(),
            streakDays: 7,
            lastSessionDateString: "Сегодня",
            topSoundId: "Ш",
            gradientStart: .purple,
            gradientEnd: .indigo
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        let streak     = defaults?.integer(forKey: "daily_mission.streak") ?? 0
        let lastDate   = defaults?.string(forKey: "streak.last_session_date") ?? "—"
        let topSound   = defaults?.string(forKey: "progress.top_sound") ?? "С"

        let entry = StreakEntry(
            date: Date(),
            streakDays: streak,
            lastSessionDateString: lastDate,
            topSoundId: topSound,
            gradientStart: gradientStart(for: streak),
            gradientEnd: gradientEnd(for: streak)
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func gradientStart(for streak: Int) -> Color {
        switch streak {
        case 30...: return .orange
        case 14...: return .red
        case 7...:  return .purple
        default:    return .blue
        }
    }

    private func gradientEnd(for streak: Int) -> Color {
        switch streak {
        case 30...: return .yellow
        case 14...: return .orange
        case 7...:  return .indigo
        default:    return .teal
        }
    }
}

// MARK: - StreakWidgetView

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        ZStack {
            LinearGradient(
                colors: [entry.gradientStart.opacity(0.85), entry.gradientEnd.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text("\(entry.streakDays)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(String(localized: "дней подряд"))
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(entry.lastSessionDateString)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .widgetURL(URL(string: "happyspeech://progress"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Серия: \(entry.streakDays) дней подряд. Последнее занятие: \(entry.lastSessionDateString)")
        )
    }

    // MARK: Medium

    private var mediumView: some View {
        ZStack {
            LinearGradient(
                colors: [entry.gradientStart.opacity(0.85), entry.gradientEnd.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Flame + streak count
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)

                    Text("\(entry.streakDays)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Divider()
                    .background(Color.white.opacity(0.4))

                // Right column
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Дней подряд"))
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(entry.lastSessionDateString)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(String(localized: "Звук: \(entry.topSoundId)"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Text(streakMotivation)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
            }
            .padding()
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .widgetURL(URL(string: "happyspeech://progress"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Серия \(entry.streakDays) дней. Топ-звук: \(entry.topSoundId). Последнее занятие: \(entry.lastSessionDateString)")
        )
    }

    private var streakMotivation: String {
        switch entry.streakDays {
        case 30...: return "Легендарный результат!"
        case 14...: return "Две недели без пропусков!"
        case 7...:  return "Неделя — отлично!"
        case 3...:  return "Хорошее начало!"
        default:    return "Начни сегодня!"
        }
    }
}

// MARK: - StreakWidget

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Серия дней"))
        .description(String(localized: "Твоя текущая серия непрерывных занятий"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
