import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Activity Control Intents

/// Intent для кнопки "Завершить" на Lock Screen.
@available(iOS 17.0, *)
struct EndSessionLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Завершить урок"
    static let description = IntentDescription("Завершить текущий урок досрочно")
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// Intent для кнопки "Продолжить" / открыть приложение.
@available(iOS 17.0, *)
struct ResumeSessionLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Продолжить урок"
    static let description = IntentDescription("Вернуться к уроку в приложении")
    static let isDiscoverable: Bool = false
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - LessonSessionLiveActivity

/// Live Activity + Dynamic Island для активного урока HappySpeech.
///
/// Dynamic Island expanded:
///   - Leading:  маскот иконка + текущий звук
///   - Trailing: счёт + «очков»
///   - Center:   название урока
///   - Bottom:   раунд X/Y + таймер
///
/// Dynamic Island compact:
///   - Leading:  flame + streak count
///   - Trailing: таймер mm:ss
///
/// Dynamic Island minimal: счёт
///
/// Lock Screen:
///   - Hero row: маскот + название + раунд/total
///   - Score progress bar (score / maxScore)
///   - Round progress bar
///   - Кнопки «Завершить» и «Продолжить»
@available(iOSApplicationExtension 16.1, *)
struct LessonSessionLiveActivity: Widget {

    private let maxScore: Int = 100

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonSessionAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded — Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "face.smiling.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                            .accessibilityHidden(true)
                        Text(context.attributes.soundId.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                            .accessibilityLabel(
                                String(localized: "Звук \(context.attributes.soundId)")
                            )
                    }
                }

                // MARK: Expanded — Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.score)")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text(String(localized: "очков"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Счёт: \(context.state.score) очков"))
                }

                // MARK: Expanded — Center
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.lessonTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(context.attributes.lessonTitle)
                }

                // MARK: Expanded — Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(
                            String(localized: "Раунд \(context.state.currentRound)/\(context.attributes.totalRounds)"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        if context.state.streakCount >= 2 {
                            Label("\(context.state.streakCount)", systemImage: "flame.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                                .accessibilityLabel(String(localized: "Стрик: \(context.state.streakCount)"))
                        }

                        Spacer()

                        Label(
                            formatTimer(context.state.elapsedSeconds),
                            systemImage: "clock"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(
                            String(localized: "Время: \(formatTimer(context.state.elapsedSeconds))")
                        )
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                // MARK: Compact — Leading: streak
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    if context.state.streakCount > 0 {
                        Text("\(context.state.streakCount)")
                            .font(.caption2.bold())
                            .contentTransition(.numericText())
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Стрик: \(context.state.streakCount)"))
            } compactTrailing: {
                // MARK: Compact — Trailing: timer
                Text(formatTimer(context.state.elapsedSeconds))
                    .font(.caption.monospacedDigit())
                    .accessibilityLabel(
                        String(localized: "Время: \(formatTimer(context.state.elapsedSeconds))")
                    )
            } minimal: {
                // MARK: Minimal — score
                Text("\(context.state.score)")
                    .font(.caption2.bold())
                    .foregroundStyle(.purple)
                    .accessibilityLabel(String(localized: "Счёт: \(context.state.score)"))
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<LessonSessionAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            // Hero row
            HStack(spacing: 8) {
                Image(systemName: "face.smiling.fill")
                    .font(.title)
                    .foregroundStyle(.purple)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.lessonTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "Звук: \(context.attributes.soundId)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(context.state.currentRound)/\(context.attributes.totalRounds)")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        String(localized: "Раунд \(context.state.currentRound) из \(context.attributes.totalRounds)")
                    )
            }

            // Round progress bar
            ProgressView(
                value: Double(context.state.currentRound),
                total: Double(max(context.attributes.totalRounds, 1))
            )
            .tint(.purple)
            .accessibilityLabel(
                String(localized: "Прогресс раундов: \(context.state.currentRound) из \(context.attributes.totalRounds)")
            )

            // Score row with progress bar
            HStack(spacing: 6) {
                Label("\(context.state.score)", systemImage: "star.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(String(localized: "Счёт: \(context.state.score)"))

                ProgressView(
                    value: Double(min(context.state.score, maxScore)),
                    total: Double(maxScore)
                )
                .tint(.yellow)
                .accessibilityLabel(
                    String(localized: "Очки: \(context.state.score) из \(maxScore)")
                )

                if context.state.streakCount > 1 {
                    Label("\(context.state.streakCount)", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .accessibilityLabel(String(localized: "Стрик: \(context.state.streakCount)"))
                }
            }

            // Timer + Action buttons
            HStack {
                Label(formatTimer(context.state.elapsedSeconds), systemImage: "clock")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "Прошло \(formatTimer(context.state.elapsedSeconds))"))

                Spacer()

                // Кнопки доступны только на iOS 17.2+
                if #available(iOSApplicationExtension 17.2, *) {
                    HStack(spacing: 8) {
                        Button(intent: EndSessionLiveActivityIntent()) {
                            Text(String(localized: "Завершить"))
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)

                        Button(intent: ResumeSessionLiveActivityIntent()) {
                            Text(String(localized: "Продолжить"))
                                .font(.caption.bold())
                                .foregroundStyle(.purple)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
