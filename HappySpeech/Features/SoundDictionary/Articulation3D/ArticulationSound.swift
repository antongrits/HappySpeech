import Foundation

// MARK: - ArticulationSound
//
// Звук → метаданные артикуляции для карточки SoundDictionary. Кириллица фонемы
// маппится на одну из научных групп укладов (отчёт A-06). Каждый case несёт:
// флаг звонкости (для индикатора голоса) и текстовую подсказку позы языка для
// SwiftUI-оверлея под 3D-сценой.
//
// 3D-модель рта (`articulation_mouth.usdz`) — статичный объект для рассматривания
// (вращение жестом), ОДИНАКОВЫЙ для всех звуков. Конкретную позу языка по звуку
// показывает текстовая подсказка `localizedHint` и 2D/видео-схема в карточке —
// внутри 3D язык не двигается (в модели нет отдельной ноды языка и рига).

enum ArticulationSound: String, CaseIterable, Sendable {

    case neutral   // нейтральная поза покоя
    case s         // С/Сь/Ц — кончик у нижних зубов, спинка горкой
    case z         // З/Зь — как С, звонкий
    case sh        // Ш/Ч/Щ — язык «чашечкой» назад-вверх
    case zh        // Ж — как Ш, звонкий
    case r         // Р/Рь — кончик вверх к альвеолам, звонкий
    case soundL    // Л/Ль — кончик вверх к верхним резцам, звонкий
    case k         // К — задняя часть вверх к мягкому нёбу, глухой
    case g         // Г — как К, звонкий
    case kh        // Х — задняя часть к нёбу со щелью, глухой

    // MARK: Кириллица → поза

    /// Маппинг кириллической буквы фонемы (как в SoundDictionary title) на позу.
    /// Возвращает `nil`, если для звука нет научной позы (гласные/прочее) —
    /// тогда показывается видео-фоллбэк.
    static func fromCyrillic(_ cyrillic: String) -> ArticulationSound? {
        let normalized = cyrillic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ь", with: "")
        switch normalized {
        case "с", "ц": return .s
        case "з": return .z
        case "ш", "ч", "щ": return .sh
        case "ж": return .zh
        case "р": return .r
        case "л": return .soundL
        case "к": return .k
        case "г": return .g
        case "х": return .kh
        default: return nil
        }
    }

    // MARK: Звонкость

    /// Звонкий звук → показывать индикатор голоса (голосовые связки вибрируют).
    var isVoiced: Bool {
        switch self {
        case .z, .zh, .r, .soundL, .g: return true
        case .neutral, .s, .sh, .k, .kh: return false
        }
    }

    // MARK: Подсказка позы языка (SwiftUI-оверлей под 3D-сценой)

    /// Краткое описание положения языка для звука (текст под 3D-моделью).
    var localizedHint: String {
        switch self {
        case .neutral:
            return String(localized: "articulation3d.pose.neutral")
        case .s, .z:
            return String(localized: "articulation3d.pose.s")
        case .sh, .zh:
            return String(localized: "articulation3d.pose.sh")
        case .r:
            return String(localized: "articulation3d.pose.r")
        case .soundL:
            return String(localized: "articulation3d.pose.l")
        case .k, .g:
            return String(localized: "articulation3d.pose.k")
        case .kh:
            return String(localized: "articulation3d.pose.kh")
        }
    }
}
