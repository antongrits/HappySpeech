import SwiftUI
import WidgetKit

// MARK: - DailyMissionWidgetView

struct DailyMissionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyMissionEntry

    private var widgetAccessibilityLabel: String {
        let progress = Int(entry.progressPercent * 100)
        return "Задание дня: \(entry.missionTitle), \(entry.missionDescription). "
            + "Серия \(entry.streakDays) дней. Прогресс \(progress)%"
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    // MARK: Small (2×2)

    private var smallView: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("\(entry.streakDays)")
                    .font(.caption.bold())
                    .accessibilityLabel(String(localized: "Серия: \(entry.streakDays) дней"))
                Spacer()
            }
            Spacer()
            Text(entry.missionTitle)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            Text(entry.missionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            ProgressView(value: entry.progressPercent)
                .tint(.purple)
                .accessibilityLabel(String(localized: "Прогресс: \(Int(entry.progressPercent * 100))%"))
        }
        .padding(8)
        .widgetURL(URL(string: "happyspeech://daily-mission"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            widgetAccessibilityLabel
        )
    }

    // MARK: Medium (4×2)

    private var mediumView: some View {
        HStack(spacing: 12) {
            lyalyaIcon(size: 60)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text(String(localized: "\(entry.streakDays) дн."))
                        .font(.caption.bold())
                        .accessibilityLabel(String(localized: "Серия \(entry.streakDays) дней"))
                }

                Text(entry.missionTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(entry.missionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                ProgressView(value: entry.progressPercent)
                    .tint(.purple)
                    .accessibilityLabel(String(localized: "Прогресс: \(Int(entry.progressPercent * 100))%"))
            }
            Spacer()
        }
        .padding()
        .widgetURL(URL(string: "happyspeech://daily-mission"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            widgetAccessibilityLabel
        )
    }

    // MARK: Large (4×4)

    private var largeView: some View {
        VStack(spacing: 12) {
            HStack {
                lyalyaIcon(size: 80)
                    .accessibilityHidden(true)
                Spacer()
                VStack(alignment: .trailing) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(String(localized: "\(entry.streakDays) дней"))
                        .font(.subheadline.bold())
                        .accessibilityLabel(String(localized: "Серия \(entry.streakDays) дней"))
                }
            }

            Text(entry.missionTitle)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)

            Text(entry.missionDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            ProgressView(value: entry.progressPercent)
                .tint(.purple)
                .accessibilityLabel(String(localized: "Прогресс: \(Int(entry.progressPercent * 100))%"))

            Text(progressLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .widgetURL(URL(string: "happyspeech://daily-mission"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Задание дня: \(entry.missionTitle), \(entry.missionDescription). Серия \(entry.streakDays) дней. \(progressLabel)")
        )
    }

    // MARK: - Helpers

    private func lyalyaIcon(size: CGFloat) -> some View {
        Image(systemName: lyalyaSystemName)
            .font(.system(size: size))
            .foregroundStyle(.purple)
    }

    private var lyalyaSystemName: String {
        switch entry.lyalyaState {
        case "encouraging":
            return "star.circle.fill"
        case "sleepy":
            return "moon.zzz.fill"
        default:
            return "face.smiling.fill"
        }
    }

    private var progressLabel: String {
        let percent = Int(entry.progressPercent * 100)
        return String(localized: "Сегодня выполнено: \(percent)%")
    }
}
