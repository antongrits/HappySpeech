import Foundation

// MARK: - WordOfTheDayModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum WordOfTheDayModels {

    struct Card: Equatable {
        let word: String
        let targetSound: String
        let illustrationSymbol: String
        let hint: String
    }

    enum RecordingPhase: Equatable {
        case idle
        case recording
        case scored(Int) // 0...3 stars
        /// Нет реального ввода/оценки — мягко предлагаем повторить, БЕЗ звёзд.
        case tryAgain
    }

    /// Простой ротатор слов на основании дня года, чтобы было детерминированно.
    static func wordForToday(now: Date = Date()) -> Card {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 1
        let pool: [Card] = [
            Card(word: "сова", targetSound: "С", illustrationSymbol: "bird.fill",
                 hint: "Большая ночная птица"),
            Card(word: "лиса", targetSound: "С", illustrationSymbol: "pawprint.fill",
                 hint: "Рыжий хитрый зверь"),
            Card(word: "роза", targetSound: "Р", illustrationSymbol: "flower",
                 hint: "Цветок с шипами"),
            Card(word: "шар", targetSound: "Ш", illustrationSymbol: "circle.fill",
                 hint: "Большой и круглый"),
            Card(word: "жук", targetSound: "Ж", illustrationSymbol: "ladybug.fill",
                 hint: "Маленькое насекомое"),
            Card(word: "часы", targetSound: "Ч", illustrationSymbol: "clock.fill",
                 hint: "Показывают время"),
            Card(word: "щётка", targetSound: "Щ", illustrationSymbol: "paintbrush.fill",
                 hint: "Чистит зубы")
        ]
        return pool[day % pool.count]
    }
}
