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
        var isEmpty: Bool

        init(kpis: [KPI], chartValues: [Double], isEmpty: Bool = false) {
            self.kpis = kpis
            self.chartValues = chartValues
            self.isEmpty = isEmpty
        }

        /// Честное «пока нет занятий» — до загрузки реальных данных и для
        /// нового ребёнка без сессий. Никаких выдуманных чисел.
        static let empty = ViewState(kpis: [], chartValues: [], isEmpty: true)

        /// Демонстрационное состояние ТОЛЬКО для preview/snapshot.
        static let preview = ViewState(
            kpis: [
                .init(id: "min",     title: String(localized: "weeklyRecap.kpi.minutes"), value: "57", trend: "+12", icon: "clock.fill"),
                .init(id: "acc",     title: String(localized: "weeklyRecap.kpi.accuracy"), value: "84%", trend: "+4%", icon: "target"),
                .init(id: "sessions", title: String(localized: "weeklyRecap.kpi.sessions"), value: "8", trend: "+3", icon: "checkmark.circle.fill"),
                .init(id: "streak",  title: String(localized: "weeklyRecap.kpi.streak"), value: "5 дн", trend: "+2", icon: "flame.fill")
            ],
            chartValues: [6, 9, 4, 12, 8, 11, 7]
        )
    }

    /// Построить KPI и дневной график из РЕАЛЬНОГО недельного агрегата.
    static func makeState(from aggregate: DashboardAggregate) -> ViewState {
        guard !aggregate.isEmpty else { return .empty }

        let accuracyPercent = Int((aggregate.summary.overallAccuracy * 100).rounded())
        let sessionCount = aggregate.daily.count
        let kpis: [KPI] = [
            .init(
                id: "min",
                title: String(localized: "weeklyRecap.kpi.minutes"),
                value: "\(aggregate.summary.totalMinutes)",
                trend: "",
                icon: "clock.fill"
            ),
            .init(
                id: "acc",
                title: String(localized: "weeklyRecap.kpi.accuracy"),
                value: "\(accuracyPercent)%",
                trend: "",
                icon: "target"
            ),
            .init(
                id: "sessions",
                title: String(localized: "weeklyRecap.kpi.sessions"),
                value: "\(sessionCount)",
                trend: "",
                icon: "checkmark.circle.fill"
            ),
            .init(
                id: "streak",
                title: String(localized: "weeklyRecap.kpi.streak"),
                value: String(
                    format: String(localized: "weeklyRecap.kpi.streakValue"),
                    aggregate.summary.streakDays
                ),
                trend: "",
                icon: "flame.fill"
            )
        ]

        // Дневной график = точность по дням окна, в процентах (0…100), масштаб для бар-чарта.
        let chartValues = aggregate.daily.map { Double($0.accuracy) * 100.0 / 8.0 }

        return ViewState(kpis: kpis, chartValues: chartValues)
    }

    static func shareText(_ state: ViewState) -> String {
        guard !state.isEmpty, !state.kpis.isEmpty else {
            return String(localized: "weeklyRecap.share.empty")
        }
        let kpis = state.kpis
            .map { kpi in
                kpi.trend.isEmpty ? "\(kpi.title): \(kpi.value)" : "\(kpi.title): \(kpi.value) (\(kpi.trend))"
            }
            .joined(separator: ", ")
        return String(format: String(localized: "weeklyRecap.share.body"), kpis)
    }
}
