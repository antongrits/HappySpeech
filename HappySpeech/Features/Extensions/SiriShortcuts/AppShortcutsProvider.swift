import AppIntents

// MARK: - HappySpeechAppShortcuts

/// App Shortcuts Provider — регистрирует 5 Siri Shortcuts для HappySpeech.
/// Фразы используют \(.applicationName) placeholder, который iOS подставляет
/// как название приложения из CFBundleDisplayName.
///
/// Все заголовки и описания — на русском языке (Russian-only mandate).
@available(iOS 17.0, *)
public struct HappySpeechAppShortcuts: AppShortcutsProvider {

    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLessonIntent(),
            phrases: [
                "Открой урок в \(.applicationName)",
                "Запусти урок \(.applicationName)",
                "\(.applicationName) открой урок"
            ],
            shortTitle: "Открыть урок",
            systemImageName: "book.closed.fill"
        )
        AppShortcut(
            intent: ShowChildProgressIntent(),
            phrases: [
                "Покажи прогресс в \(.applicationName)",
                "Прогресс \(.applicationName)",
                "\(.applicationName) прогресс"
            ],
            shortTitle: "Прогресс",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: StartBreathingIntent(),
            phrases: [
                "Начни дыхательное упражнение в \(.applicationName)",
                "Дыхание \(.applicationName)",
                "\(.applicationName) дыхание"
            ],
            shortTitle: "Дыхание",
            systemImageName: "lungs.fill"
        )
        AppShortcut(
            intent: PlayWithLyalyaIntent(),
            phrases: [
                "Играй с Лялей в \(.applicationName)",
                "Открой Лялю в \(.applicationName)",
                "\(.applicationName) Ляля"
            ],
            shortTitle: "Играть с Лялей",
            systemImageName: "face.smiling.fill"
        )
        AppShortcut(
            intent: ShowTodaysMissionIntent(),
            phrases: [
                "Покажи задание на сегодня в \(.applicationName)",
                "Сегодняшнее задание \(.applicationName)",
                "\(.applicationName) задание дня"
            ],
            shortTitle: "Задание дня",
            systemImageName: "calendar.badge.checkmark"
        )
    }
}
