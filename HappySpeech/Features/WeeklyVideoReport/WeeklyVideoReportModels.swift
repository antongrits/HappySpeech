import Foundation

// MARK: - WeeklyVideoReport VIP Models
//
// Контур: parent. Анимированный еженедельный ВИДЕО-отчёт о прогрессе ребёнка.
// Видео-фон — пред-рендеренный шаблон (Remotion, node на маке, не on-device).
// Поверх видео накладывается оверлей с РЕАЛЬНЫМИ числами ребёнка из недельной
// агрегации `SessionRepository` (точность по звукам, серия, минуты, звёзды).
//
// Честное ограничение: полная персонализация самой композиции на лету
// недоступна (Remotion рендерит на маке). Поэтому видео — общий тёплый шаблон,
// а конкретные данные ребёнка показываются оверлеем (реальные, не выдуманные).

enum WeeklyVideoReportModels {

    enum Load {
        struct Request: Sendable {
            let childId: String
        }
        struct Response: Sendable {
            /// Реальный недельный агрегат (пустой → ViewState.empty).
            let aggregate: DashboardAggregate
            /// Имя ребёнка (для подписи). Пустое → нейтральная подпись.
            let childName: String
            /// Метка недели, напр. «2–8 июня».
            let weekLabel: String
        }
    }

    // MARK: - ViewState

    struct ViewState: Equatable, Sendable {
        var isEmpty: Bool
        var childName: String
        var weekLabel: String
        var overlayMetrics: [OverlayMetric]
        var sounds: [SoundRow]

        static let empty = ViewState(
            isEmpty: true,
            childName: "",
            weekLabel: "",
            overlayMetrics: [],
            sounds: []
        )
    }

    /// Одна метрика-чип оверлея (точность / серия / минуты / звёзды).
    struct OverlayMetric: Identifiable, Equatable, Sendable, Hashable {
        let id: String
        let icon: String
        let value: String
        let caption: String
    }

    /// Строка прогресса по звуку (для оверлея «реальные данные»).
    struct SoundRow: Identifiable, Equatable, Sendable, Hashable {
        let id: String
        let sound: String
        let accuracyPercent: Int
        let trend: ProgressTrend
    }
}
