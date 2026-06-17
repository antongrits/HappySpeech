import Foundation

// MARK: - ParentDailyDigestModels

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
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
        /// Загружены ли реальные KPI из сессий. До первого резолва View рисует
        /// скелетон, а не плейсхолдеры «—», чтобы не мелькали «нулевые» метрики.
        var isLoaded: Bool = false

        /// Есть ли непустой «момент дня» (показывать карточку только тогда).
        var hasPhotoMoment: Bool { !photoMomentCaption.isEmpty }

        /// «Тихий день» — сегодня ещё не было занятий: KPI «Занятий» = 0/—.
        /// В этом случае показываем дружелюбную подсказку вместо ощущения «дыры»
        /// с нулями. Метрики при этом честно остаются нулевыми (не фабрикуем).
        var isQuietDay: Bool {
            guard let sessions = kpis.first(where: { $0.id == "sessions" }) else { return false }
            return sessions.value == "0" || sessions.value == "—"
        }

        /// Стартовое состояние с НУЛЕВЫМИ KPI (без зашитых «8 мин»/«82%»/«5 дн»).
        /// Реальные KPI и «момент дня» подставляет `Interactor.makeState(from:)`
        /// из фактических сессий. `tip` — курируемый методический совет
        /// (легитимный контент, не фабрикация статистики).
        static let initial = ViewState(
            kpis: [
                KPI(id: "min", icon: "clock.fill", value: "—", label: "Сегодня"),
                KPI(id: "score", icon: "star.fill", value: "—", label: "Точность"),
                KPI(id: "streak", icon: "flame.fill", value: "—", label: "Серия"),
                KPI(id: "sessions", icon: "checkmark.seal.fill", value: "—", label: "Занятий")
            ],
            photoMomentEmoji: "🌟",
            photoMomentCaption: "",
            tip: Tip(
                text: "Хвалите ребёнка за усилия, а не за результат — это поддерживает мотивацию.",
                author: "Ольга Логопед"
            )
        )
    }
}
