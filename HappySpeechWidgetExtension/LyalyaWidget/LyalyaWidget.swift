import SwiftUI
import WidgetKit

// MARK: - LyalyaEntry

struct LyalyaEntry: TimelineEntry {
    let date: Date
    let missionTitle: String
    let missionDescription: String
    let streakDays: Int
    let completedRounds: Int
    let totalRounds: Int
    let lyalyaMood: LyalyaMood
    let progressPercent: Double

    enum LyalyaMood: String {
        case happy
        case encouraging
        case sleepy
        case celebrating
    }
}

// MARK: - LyalyaProvider

struct LyalyaProvider: TimelineProvider {

    func placeholder(in context: Context) -> LyalyaEntry {
        LyalyaEntry(
            date: Date(),
            missionTitle: "Звук Ш",
            missionDescription: "Шипящие звуки • 5 раундов",
            streakDays: 7,
            completedRounds: 3,
            totalRounds: 5,
            lyalyaMood: .happy,
            progressPercent: 0.6
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LyalyaEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyalyaEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        let entry = loadEntry(from: defaults)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry(from defaults: UserDefaults?) -> LyalyaEntry {
        let title       = defaults?.string(forKey: "daily_mission.title") ?? "Звук Ш"
        let description = defaults?.string(forKey: "daily_mission.description") ?? "5 раундов"
        let streak      = defaults?.integer(forKey: "daily_mission.streak") ?? 0
        let progress    = defaults?.double(forKey: "daily_mission.progress") ?? 0.0
        let moodRaw     = defaults?.string(forKey: "daily_mission.lyalya_state") ?? "happy"
        let completed   = defaults?.integer(forKey: "daily_mission.completed_rounds") ?? 0
        let total       = defaults?.integer(forKey: "daily_mission.total_rounds") ?? 5

        let mood: LyalyaEntry.LyalyaMood
        switch moodRaw {
        case "encouraging":  mood = .encouraging
        case "sleepy":       mood = .sleepy
        case "celebrating":  mood = .celebrating
        default:             mood = .happy
        }

        return LyalyaEntry(
            date: Date(),
            missionTitle: title,
            missionDescription: description,
            streakDays: streak,
            completedRounds: completed,
            totalRounds: max(total, 1),
            lyalyaMood: mood,
            progressPercent: progress
        )
    }
}

// MARK: - LyalyaWidgetView

struct LyalyaWidgetView: View {
    let entry: LyalyaEntry

    private var accessibilityDescription: String {
        let pct = Int(entry.progressPercent * 100)
        let completed = entry.completedRounds
        let total = entry.totalRounds
        let streak = entry.streakDays
        let title = entry.missionTitle
        return "Ляля. Задание: \(title). \(completed) из \(total) раундов. Прогресс \(pct)%. Серия \(streak) дней."
    }

    var body: some View {
        VStack(spacing: 12) {

            // MARK: Top — маскот + настроение
            HStack(alignment: .top) {
                lyalyaView
                    .accessibilityHidden(true)

                Spacer()

                // Streak badge
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("\(entry.streakDays)")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText())
                    Text(String(localized: "дней"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Серия \(entry.streakDays) дней"))
            }

            // MARK: Middle — задание
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.missionTitle)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(entry.missionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // MARK: Bottom — progress bar + rounds
            VStack(spacing: 6) {
                HStack {
                    Text(String(localized: "Раундов: \(entry.completedRounds)/\(entry.totalRounds)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(localized: "\(Int(entry.progressPercent * 100))%"))
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }

                ProgressView(value: entry.progressPercent)
                    .tint(.purple)
                    .accessibilityLabel(
                        String(localized: "Прогресс: \(Int(entry.progressPercent * 100))%")
                    )
            }

            // MARK: Lyalya phrase
            Text(lyalyaPhrase)
                .font(.caption2.italic())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding()
        .widgetURL(URL(string: "happyspeech://child-home"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Lyalya Illustration

    @ViewBuilder
    private var lyalyaView: some View {
        ZStack {
            Circle()
                .fill(lyalyaBackgroundGradient)
                .frame(width: 72, height: 72)

            Image(systemName: lyalyaIconName)
                .font(.system(size: 40))
                .foregroundStyle(.white)
        }
    }

    private var lyalyaBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [lyalyaGradientStart, lyalyaGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lyalyaIconName: String {
        switch entry.lyalyaMood {
        case .happy:       return "face.smiling.fill"
        case .encouraging: return "star.circle.fill"
        case .sleepy:      return "moon.zzz.fill"
        case .celebrating: return "party.popper.fill"
        }
    }

    private var lyalyaGradientStart: Color {
        switch entry.lyalyaMood {
        case .happy:       return .purple
        case .encouraging: return .orange
        case .sleepy:      return .indigo
        case .celebrating: return .pink
        }
    }

    private var lyalyaGradientEnd: Color {
        switch entry.lyalyaMood {
        case .happy:       return .indigo
        case .encouraging: return .yellow
        case .sleepy:      return .blue
        case .celebrating: return .orange
        }
    }

    private var lyalyaPhrase: String {
        switch entry.lyalyaMood {
        case .happy:       return "Ляля рада тебя видеть!"
        case .encouraging: return "Ты молодец! Продолжай!"
        case .sleepy:      return "Ляля скучает. Зайди?"
        case .celebrating: return "Ура! Задание выполнено!"
        }
    }
}

// MARK: - LyalyaWidget

struct LyalyaWidget: Widget {
    let kind: String = "LyalyaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyalyaProvider()) { entry in
            LyalyaWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Ляля"))
        .description(String(localized: "Маскот Ляля с заданием дня, прогрессом и серией"))
        .supportedFamilies([.systemLarge])
    }
}
