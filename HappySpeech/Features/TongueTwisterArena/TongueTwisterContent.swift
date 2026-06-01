import Foundation

// MARK: - TongueTwisterContent

/// Курируемый набор русских скороговорок по группам звуков.
///
/// Это методический контент (классические скороговорки на отработку звуков),
/// единый источник правды для игры. Запись и оценка произношения выполняются
/// интерактором по-настоящему, контент же фиксирован.
enum TongueTwisterContent {

    static let all: [TongueTwisterArenaModels.Twister] = [
        .init(id: "tt-s-sh", text: "Шла Саша по шоссе и сосала сушку.", targetSound: "С/Ш"),
        .init(id: "tt-r-1", text: "На дворе трава, на траве дрова.", targetSound: "Р"),
        .init(id: "tt-r-k", text: "Ехал Грека через реку, видит Грека — в реке рак.", targetSound: "Р/К"),
        .init(id: "tt-t-p", text: "От топота копыт пыль по полю летит.", targetSound: "Т/П"),
        .init(id: "tt-r-l", text: "Карл у Клары украл кораллы, Клара у Карла украла кларнет.", targetSound: "Р/Л"),
        .init(id: "tt-zh-sh", text: "Жук жужжит, шмель шумит, шершень шуршит.", targetSound: "Ж/Ш"),
        .init(id: "tt-c", text: "Цапля цветик целовала, цапле цветик подарили.", targetSound: "Ц"),
        .init(id: "tt-shch-ch", text: "Щёткой чищу я щенка, щекочу ему бока.", targetSound: "Щ/Ч")
    ]

    /// Скороговорки, релевантные рабочим звукам ребёнка (если совпадений нет —
    /// весь набор).
    static func twisters(forTargetSounds targets: [String]) -> [TongueTwisterArenaModels.Twister] {
        guard !targets.isEmpty else { return all }
        let upper = Set(targets.map { $0.uppercased() })
        let matched = all.filter { twister in
            twister.targetSound
                .split(whereSeparator: { $0 == "/" })
                .contains { upper.contains($0.trimmingCharacters(in: .whitespaces).uppercased()) }
        }
        return matched.isEmpty ? all : matched + all.filter { !matched.contains($0) }
    }
}
