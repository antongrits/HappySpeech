import Foundation

// MARK: - SoundOfTheDayModels
//
// «Звук дня» — ребёнок видит один сфокусированный звук дня + 3 быстрых
// активности. Снижает выбор-перегрузку и помогает войти в практику.

enum SoundOfTheDayModels {

    // MARK: - LoadToday

    enum LoadToday {

        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let childName: String
            let targetSound: String     // «Р»
            let weekdayDateText: String // «суббота, 23 мая»
            let reasonText: String      // «Ты вчера хорошо его узнавал!»
            let streakDays: Int
            let activities: [ActivityCard]
        }

        struct ViewModel: Sendable {
            let greeting: String        // «Привет, Миша!»
            let subtitle: String        // «Сегодня — суббота, 23 мая»
            let heroTitle: String       // «Звук дня: «Р»»
            let soundLetter: String     // «Р» — только буква для кружка-якоря
            let heroReason: String
            let streakText: String      // «3 дня подряд»
            let streakProgress: Double  // 0…1
            let activities: [ActivityCard]
            let primaryCtaTitle: String
            let accessibilityLabel: String
        }
    }

    // MARK: - SelectActivity

    enum SelectActivity {

        struct Request: Sendable {
            let activity: ActivityCard
        }
    }
}

// MARK: - ActivityCard

/// Одна активность дня. Имеет иконку, заголовок и тип, который Router
/// переводит в `AppRoute.lessonPlayer(...)`.
struct ActivityCard: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let templateRoute: String   // совпадает с GameType.fromTemplateRoute

    static let listen = ActivityCard(
        id: "listen",
        title: "Послушай",
        systemImage: "speaker.wave.2.fill",
        templateRoute: "repeat-after-model"
    )

    static let play = ActivityCard(
        id: "play",
        title: "Поиграй",
        systemImage: "gamecontroller.fill",
        templateRoute: "bingo"
    )

    static let tell = ActivityCard(
        id: "tell",
        title: "Расскажи",
        systemImage: "mic.fill",
        templateRoute: "repeat-after-model"
    )

    static let all: [ActivityCard] = [.listen, .play, .tell]
}
