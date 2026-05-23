import Foundation

// MARK: - ImitationLabModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum ImitationLabModels {

    struct SoundSample: Identifiable, Hashable {
        let id: String
        let emoji: String
        let name: String
        let onomatopoeia: String
        var isPlayed: Bool
    }

    struct ViewState: Equatable {
        var samples: [SoundSample]
        var currentSampleId: String?

        static let initial = ViewState(samples: [
            SoundSample(id: "tr", emoji: "🚂", name: "Поезд", onomatopoeia: "Чух-чух", isPlayed: false),
            SoundSample(id: "duck", emoji: "🦆", name: "Утка", onomatopoeia: "Кря-кря", isPlayed: false),
            SoundSample(id: "wind", emoji: "🌬", name: "Ветер", onomatopoeia: "У-у-у", isPlayed: false),
            SoundSample(id: "cat", emoji: "🐱", name: "Кошка", onomatopoeia: "Мяу-мяу", isPlayed: false),
            SoundSample(id: "drum", emoji: "🥁", name: "Барабан", onomatopoeia: "Бум-бум", isPlayed: false),
            SoundSample(id: "bee", emoji: "🐝", name: "Пчела", onomatopoeia: "Ж-ж-ж", isPlayed: false),
            SoundSample(id: "snake", emoji: "🐍", name: "Змейка", onomatopoeia: "С-с-с", isPlayed: false),
            SoundSample(id: "car", emoji: "🚗", name: "Машина", onomatopoeia: "Би-би", isPlayed: false)
        ], currentSampleId: nil)
    }
}
