import Foundation

// MARK: - SoundRomanizer

/// Единый источник правды для маппинга русского звука → латинский код пака.
///
/// До его появления три места кодировали маппинг звук→latin **независимо** и
/// расходились между собой, из-за чего контент звуков Ц/Х/Й де-факто не грузился:
///   1. `ListenAndChooseInteractor.canonicalPackId` (строил `sound_ts_v1` для Ц);
///   2. `LiveContentService.romanize` (ц→`ts`, х→`h`, щ→`sch`);
///   3. имена файлов в `Content/Seed/` (`sound_c_pack`, `sound_kh_pack`, `sound_y_pack`,
///      `sound_shch_pack`).
///
/// Латинские коды здесь **совпадают с реальными именами бандл-файлов** — единственный
/// контракт, от которого зависит резолв `sound_<latin>_pack.json`. Любой новый
/// потребитель обязан звать `SoundRomanizer.latinCode(for:)`, а не хардкодить switch.
public enum SoundRomanizer {

    /// Возвращает латинский код пака для русского звука (или уже-латинского кода).
    ///
    /// Регистр и мягкость («рь», «ль») нормализуются к базовому звуку. Неизвестные
    /// значения возвращаются как есть в нижнем регистре (back-compat для legacy id).
    ///
    /// - Parameter sound: русская буква («с», «ц», «х», «й», …) либо латинский код.
    /// - Returns: латинский код, совпадающий с именем файла `sound_<code>_pack.json`.
    public static func latinCode(for sound: String) -> String {
        switch sound.lowercased() {
        case "с", "s":         return "s"
        case "з", "z":         return "z"
        // Ц: файл `sound_c_pack.json` (id `sound_c_v1`). Ранее ошибочно `ts` → пак не грузился.
        case "ц", "c", "ts":   return "c"
        case "ш", "sh":        return "sh"
        case "ж", "zh":        return "zh"
        case "ч", "ch":        return "ch"
        // Щ: файл `sound_shch_pack.json`. Ранее romanize отдавал `sch` → расхождение.
        case "щ", "shch", "sch": return "shch"
        case "р", "рь", "r":   return "r"
        case "л", "ль", "l":   return "l"
        case "к", "k":         return "k"
        case "г", "g":         return "g"
        // Х: файл `sound_kh_pack.json` (id `sound_kh_v1`). Ранее ошибочно `h` → пак не грузился.
        case "х", "kh", "h":   return "kh"
        // Й: файл `sound_y_pack.json` (id `sound_y_v1`). Ранее отсутствовал в switch → default.
        case "й", "y":         return "y"
        default:               return sound.lowercased()
        }
    }

    /// Каноничный playable-id пака для звука: `sound_<latin>_v1`.
    /// Используется фичами (ListenAndChoose и т.п.) для запроса контента у `ContentService`.
    public static func canonicalPackId(for sound: String) -> String {
        "sound_\(latinCode(for: sound))_v1"
    }
}
