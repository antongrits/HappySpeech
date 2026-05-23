import Foundation

// MARK: - WeeklyRecapModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum WeeklyRecapModels {

    struct KPI: Identifiable, Hashable {
        let id: String
        let title: String
        let value: String
        let trend: String
        let icon: String
    }

    struct ViewState: Equatable {
        var kpis: [KPI]
        var chartValues: [Double]

        static let preview = ViewState(
            kpis: [
                .init(id: "min",     title: "Минут", value: "57", trend: "+12", icon: "clock.fill"),
                .init(id: "acc",     title: "Точность", value: "84%", trend: "+4%", icon: "target"),
                .init(id: "sounds",  title: "Новых звуков", value: "3", trend: "+1", icon: "speaker.wave.2.fill"),
                .init(id: "streak",  title: "Серия", value: "5 дн", trend: "+2", icon: "flame.fill")
            ],
            chartValues: [6, 9, 4, 12, 8, 11, 7]
        )
    }

    static func shareText(_ state: ViewState) -> String {
        let kpis = state.kpis.map { "\($0.title): \($0.value) (\($0.trend))" }.joined(separator: ", ")
        return "HappySpeech — отчёт за неделю. \(kpis)."
    }
}
