import AppIntents

// MARK: - HappySpeechAppShortcuts

/// App Shortcuts Provider — регистрирует 9 Siri Shortcuts для HappySpeech.
/// Фразы используют \(.applicationName) placeholder, который iOS подставляет
/// как название приложения из CFBundleDisplayName.
///
/// Все заголовки и фразы — на русском языке (Russian-only mandate).
@available(iOS 17.0, *)
public struct HappySpeechAppShortcuts: AppShortcutsProvider {

    public static var appShortcuts: [AppShortcut] {

        // MARK: 1. Открыть урок

        AppShortcut(
            intent: OpenLessonIntent(),
            phrases: [
                "Открой урок в \(.applicationName)",
                "Запусти урок \(.applicationName)",
                "\(.applicationName) открой урок",
                "Урок звука в \(.applicationName)"
            ],
            shortTitle: "Открыть урок",
            systemImageName: "book.closed.fill"
        )

        // MARK: 2. Показать прогресс

        AppShortcut(
            intent: ShowChildProgressIntent(),
            phrases: [
                "Покажи прогресс в \(.applicationName)",
                "Прогресс \(.applicationName)",
                "\(.applicationName) прогресс",
                "Как дела с занятиями в \(.applicationName)"
            ],
            shortTitle: "Прогресс",
            systemImageName: "chart.line.uptrend.xyaxis"
        )

        // MARK: 3. Дыхательное упражнение

        AppShortcut(
            intent: StartBreathingIntent(),
            phrases: [
                "Начни дыхательное упражнение в \(.applicationName)",
                "Дыхание \(.applicationName)",
                "\(.applicationName) дыхание",
                "Дыхательная гимнастика в \(.applicationName)"
            ],
            shortTitle: "Дыхание",
            systemImageName: "lungs.fill"
        )

        // MARK: 4. Играть с Лялей

        AppShortcut(
            intent: PlayWithLyalyaIntent(),
            phrases: [
                "Играй с Лялей в \(.applicationName)",
                "Открой Лялю в \(.applicationName)",
                "\(.applicationName) Ляля",
                "Хочу к Ляле в \(.applicationName)"
            ],
            shortTitle: "Играть с Лялей",
            systemImageName: "face.smiling.fill"
        )

        // MARK: 5. Задание на сегодня / Начать сессию

        AppShortcut(
            intent: ShowTodaysMissionIntent(),
            phrases: [
                "Покажи задание на сегодня в \(.applicationName)",
                "Сегодняшнее задание \(.applicationName)",
                "\(.applicationName) задание дня",
                "Начни занятие в \(.applicationName)"
            ],
            shortTitle: "Задание дня",
            systemImageName: "calendar.badge.checkmark"
        )

        // MARK: 6. Достижения

        AppShortcut(
            intent: ListAchievementsIntent(),
            phrases: [
                "Покажи достижения в \(.applicationName)",
                "Мои награды в \(.applicationName)",
                "\(.applicationName) достижения",
                "Что я получил в \(.applicationName)"
            ],
            shortTitle: "Достижения",
            systemImageName: "trophy.fill"
        )

        // MARK: 7. Сводка за неделю

        AppShortcut(
            intent: GetWeeklySummaryIntent(),
            phrases: [
                "Расскажи про успехи за неделю в \(.applicationName)",
                "Сводка недели \(.applicationName)",
                "\(.applicationName) неделя",
                "Итоги недели в \(.applicationName)"
            ],
            shortTitle: "Сводка недели",
            systemImageName: "calendar.badge.clock"
        )

        // MARK: 8. Установить напоминание

        AppShortcut(
            intent: SetReminderIntent(),
            phrases: [
                "Напомни заниматься в \(.applicationName)",
                "Поставь напоминание в \(.applicationName)",
                "\(.applicationName) напоминание",
                "Каждый день напоминай про \(.applicationName)"
            ],
            shortTitle: "Напоминание",
            systemImageName: "bell.badge.fill"
        )

        // MARK: 9. Кастомное занятие

        AppShortcut(
            intent: StartCustomSessionIntent(),
            phrases: [
                "Начни кастомное занятие в \(.applicationName)",
                "Своё занятие в \(.applicationName)",
                "\(.applicationName) кастомное занятие",
                "Настрой занятие в \(.applicationName)"
            ],
            shortTitle: "Своё занятие",
            systemImageName: "slider.horizontal.3"
        )

        // MARK: 10. v31 — Звуковой светофор

        AppShortcut(
            intent: OpenSoundTrafficLightIntent(),
            phrases: [
                "Открой звуковой светофор в \(.applicationName)",
                "Светофор звуков \(.applicationName)",
                "\(.applicationName) звуковой светофор",
                "Покажи звуки в работе \(.applicationName)"
            ],
            shortTitle: "Звуковой светофор",
            systemImageName: "light.beacon.max.fill"
        )
    }
}
