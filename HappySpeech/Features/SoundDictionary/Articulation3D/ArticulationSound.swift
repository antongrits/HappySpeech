import SceneKit

// MARK: - ArticulationSound
//
// Звук → артикуляционная поза языка. Кириллица фонемы из SoundDictionary
// маппится на одну из научных поз укладов (отчёт A-06). Каждый case несёт:
// смещение/наклон/масштаб узла `Tongue` реальной анатомической модели
// (Z-Anatomy USDZ), флаг звонкости (для индикатора голоса) и текстовую
// подсказку позы для SwiftUI-оверлея.
//
// Анатомия модели: сагиттальный разрез, upAxis = Y, фронт лица → +Z,
// плоскость среза = X = 0. Кончик языка смотрит в сторону губ (+Z),
// корень — назад к глотке (−Z). Поэтому смещения языка задаются в локальных
// осях модели: +Y — вверх (к нёбу), +Z — вперёд (к зубам/губам),
// −Z — назад (к мягкому нёбу/глотке).

enum ArticulationSound: String, CaseIterable, Sendable {

    case neutral   // нейтральная поза покоя
    case s         // С/Сь/Ц — кончик у нижних зубов, спинка горкой
    case z         // З/Зь — как С, звонкий
    case sh        // Ш/Ч/Щ — язык «чашечкой» назад-вверх
    case zh        // Ж — как Ш, звонкий
    case r         // Р/Рь — кончик вверх к альвеолам (+вибрация), звонкий
    case soundL    // Л/Ль — кончик вверх к верхним резцам, звонкий
    case k         // К — задняя часть вверх к мягкому нёбу, глухой
    case g         // Г — как К, звонкий
    case kh        // Х — задняя часть к нёбу со щелью, глухой

    // MARK: Кириллица → поза

    /// Маппинг кириллической буквы фонемы (как в SoundDictionary title) на позу.
    /// Возвращает `nil`, если для звука нет научной 3D-позы (гласные/прочее) —
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

    // MARK: Поза языка (трансформ узла `Tongue` относительно базовой)

    /// Смещение узла языка в долях габарита модели по осям (x, y, z).
    /// Применяется как доля от размера bounding box → независимо от масштаба usdz.
    var tongueOffset: SIMD3<Float> {
        switch self {
        case .neutral:
            return SIMD3(0, 0, 0)
        case .s, .z:
            // Кончик к нижним зубам: язык чуть вперёд и вниз, спинка горкой.
            return SIMD3(0, -0.02, 0.05)
        case .sh, .zh:
            // «Чашечкой» назад-вверх: язык приподнят и оттянут назад.
            return SIMD3(0, 0.05, -0.04)
        case .r:
            // Кончик вверх к альвеолам: вперёд-вверх.
            return SIMD3(0, 0.06, 0.04)
        case .soundL:
            // Кончик к верхним резцам: вперёд-вверх, чуть сильнее вперёд.
            return SIMD3(0, 0.05, 0.06)
        case .k, .g:
            // Задняя часть к мягкому нёбу: язык назад-вверх (сильнее, чем Ш).
            return SIMD3(0, 0.07, -0.07)
        case .kh:
            // Задняя часть к нёбу со щелью: чуть слабее смыкания К.
            return SIMD3(0, 0.05, -0.06)
        }
    }

    /// Наклон узла языка (питч вокруг локальной оси X, рад). Положительный —
    /// кончик вверх (к нёбу), отрицательный — кончик вниз (к дну рта).
    var tonguePitch: Float {
        switch self {
        case .neutral: return 0
        case .s, .z: return -0.18      // кончик вниз
        case .sh, .zh: return 0.16     // спинка вверх
        case .r: return 0.32           // кончик резко вверх
        case .soundL: return 0.28      // кончик вверх к резцам
        case .k, .g: return -0.22      // передняя часть вниз, задняя вверх
        case .kh: return -0.18
        }
    }

    /// Лёгкое неравномерное масштабирование (вытягивание/поджатие) языка.
    var tongueScale: SIMD3<Float> {
        switch self {
        case .neutral: return SIMD3(1, 1, 1)
        case .s, .z: return SIMD3(1, 0.94, 1.04)   // плоский, чуть длиннее
        case .sh, .zh: return SIMD3(1, 1.08, 0.96) // выше, короче (чашечка)
        case .r: return SIMD3(1, 1.06, 1.0)
        case .soundL: return SIMD3(1, 1.04, 1.02)
        case .k, .g: return SIMD3(1, 1.1, 0.92)    // задняя часть вздута
        case .kh: return SIMD3(1, 1.06, 0.94)
        }
    }

    /// Подпись позы для SwiftUI-оверлея (краткая, без текста внутри 3D).
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
