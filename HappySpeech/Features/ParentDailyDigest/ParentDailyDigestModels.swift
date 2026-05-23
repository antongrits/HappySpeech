import Foundation

// MARK: - ParentDailyDigestModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum ParentDailyDigestModels {

    struct KPI: Identifiable, Hashable {
        let id: String
        let icon: String
        let value: String
        let label: String
    }

    struct Tip: Hashable {
        let text: String
        let author: String
    }

    struct ViewState: Equatable {
        var kpis: [KPI]
        var photoMomentEmoji: String
        var photoMomentCaption: String
        var tip: Tip

        static let initial = ViewState(
            kpis: [
                KPI(id: "min", icon: "clock.fill", value: "8 мин", label: "Сегодня"),
                KPI(id: "score", icon: "star.fill", value: "82%", label: "Точность"),
                KPI(id: "streak", icon: "flame.fill", value: "5 дн", label: "Серия"),
                KPI(id: "stickers", icon: "rosette", value: "3", label: "Наклейки")
            ],
            photoMomentEmoji: "🌟",
            photoMomentCaption: "Аня впервые произнесла «Р» в слове «рак»",
            tip: Tip(
                text: "Хвалите ребёнка за усилия, а не за результат — это поддерживает мотивацию.",
                author: "Ольга Логопед"
            )
        )
    }
}
