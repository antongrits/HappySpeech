import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - LessonSessionLiveActivity

/// Live Activity + Dynamic Island для активного урока HappySpeech.
///
/// Отображает:
/// - Lock Screen: название урока, прогресс раундов, счёт, таймер
/// - Dynamic Island expanded: маскот-иконка, счёт, название, прогресс + таймер
/// - Dynamic Island compact: flame-иконка стрика + таймер
/// - Dynamic Island minimal: иконка маскота
@available(iOSApplicationExtension 16.1, *)
struct LessonSessionLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonSessionAttributes.self) { context in
            // MARK: Lock Screen UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "face.smiling.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                        .accessibilityLabel(String(localized: "Ляля — маскот HappySpeech"))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.score)")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        Text(String(localized: "очков"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.lessonTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(
                            String(localized: "Раунд \(context.state.currentRound) из \(context.attributes.totalRounds)"),
                            systemImage: "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Label(
                            formatTimer(context.state.elapsedSeconds),
                            systemImage: "clock"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                // MARK: Compact leading — стрик
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    if context.state.streakCount > 0 {
                        Text("\(context.state.streakCount)")
                            .font(.caption2.bold())
                    }
                }
                .accessibilityLabel(String(localized: "Стрик: \(context.state.streakCount)"))
            } compactTrailing: {
                // MARK: Compact trailing — таймер
                Text(formatTimer(context.state.elapsedSeconds))
                    .font(.caption.monospacedDigit())
                    .accessibilityLabel(String(localized: "Время: \(formatTimer(context.state.elapsedSeconds))"))
            } minimal: {
                // MARK: Minimal
                Image(systemName: "face.smiling.fill")
                    .foregroundStyle(.purple)
                    .accessibilityLabel(String(localized: "Урок HappySpeech"))
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<LessonSessionAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Заголовок: название урока + прогресс раундов
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "face.smiling.fill")
                        .foregroundStyle(.purple)
                    Text(context.attributes.lessonTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Text("\(context.state.currentRound)/\(context.attributes.totalRounds)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        String(localized: "Раунд \(context.state.currentRound) из \(context.attributes.totalRounds)")
                    )
            }

            // Прогресс-бар раундов
            ProgressView(
                value: Double(context.state.currentRound),
                total: Double(max(context.attributes.totalRounds, 1))
            )
            .tint(.purple)
            .accessibilityLabel(
                String(localized: "Прогресс урока \(context.state.currentRound) из \(context.attributes.totalRounds) раундов")
            )

            // Нижняя строка: счёт + стрик + таймер
            HStack {
                Label("\(context.state.score)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(String(localized: "Счёт: \(context.state.score)"))

                if context.state.streakCount > 1 {
                    Label("\(context.state.streakCount)", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(String(localized: "Стрик: \(context.state.streakCount)"))
                }

                Spacer()

                Label(formatTimer(context.state.elapsedSeconds), systemImage: "clock")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "Время: \(formatTimer(context.state.elapsedSeconds))"))
            }
        }
        .padding()
        .activityBackgroundTint(Color.purple.opacity(0.15))
        .activitySystemActionForegroundColor(.purple)
    }

    // MARK: - Helpers

    private func formatTimer(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
