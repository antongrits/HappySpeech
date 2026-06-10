import Foundation
import os

// MARK: - ActiveChildIdHolder

/// Потокобезопасный Sendable-снимок идентификатора активного ребёнка.
///
/// `AppContainer.currentChildId` — `@MainActor`-изолированное состояние, его нельзя
/// синхронно прочитать из не-isolated слоёв (например из `phoneticAccuracy`, которая
/// вызывается вне MainActor). Контейнер зеркалит изменения сюда через `set`, а
/// не-isolated слои читают через `get`. Под капотом — `OSAllocatedUnfairLock`.
public final class ActiveChildIdHolder: Sendable {
    private let storage = OSAllocatedUnfairLock<String>(initialState: "")

    public init() {}

    /// Обновляет снимок (вызывается из `AppContainer.currentChildId.didSet`).
    public func set(_ value: String) {
        storage.withLock { $0 = value }
    }

    /// Текущий снимок childId (пустая строка, если активный ребёнок не выбран).
    public func get() -> String {
        storage.withLock { $0 }
    }
}

// MARK: - RegionalDialectPhonetics
//
// ==================================================================================
// Лингвистические правила региональных русских диалектов для скоринга произношения.
//
// ПРОБЛЕМА. Экран `DialectAdaptation` позволял выбрать региональный диалект, но
// выбор был «мёртвым»: он сохранялся как UI-предпочтение и НИКАК не влиял на оценку
// произношения. Ребёнок из южного региона, говорящий фрикативное [ɣ] вместо
// взрывного [g], или из северного — с оканьем, штрафовался скорером, хотя это НЕ
// дефект речи, а нормативная региональная черта.
//
// РЕШЕНИЕ. Диалект даёт набор ДОПУСТИМЫХ фонемных эквивалентностей. Если ребёнок
// произнёс эталонную фонему её диалектным вариантом — замена считается НУЛЕВОЙ по
// цене (как совпадение), а не штрафуется. Это применяется в
// ``ChildSpeechScoringPolicy/childAwareSubstitutionCost(_:_:)`` и далее в
// `EnsembleASRService.phoneticAccuracy`, т.е. в РЕАЛЬНОМ пайплайне оценки.
//
// ВАЖНО — методическая корректность. Диалектная черта ≠ дефект и ≠ возрастная
// замена (Р→Л). Поэтому диалектный вариант:
//   • НЕ штрафуется (cost 0.0, а не 0.2 как у developmental),
//   • НЕ помечается как `developmentalSubstitution` (это не «звук в работе»),
//   • даёт вердикт `correct`, если в остальном слово произнесено верно.
//
// ИСТОЧНИК ПРАВИЛ — общепризнанные факты русской диалектологии (Аванесов,
// «Русское литературное произношение»; описания южно- и северновеликорусского
// наречий). В таблицы включены ТОЛЬКО проверяемые черты; спорные/узколокальные
// варианты намеренно опущены, чтобы не выдумывать.
//
// Все фонемные символы согласованы с инвентарём ``RussianPhonemeInventory``
// (выход акустического ``RussianPhonemeClassifier``) и ``RussianG2P`` (эталон):
//   • Эталон: взрывное Г → "g" / "gʲ"; южный фрикативный г в акустике
//     распознаётся как ближайший велярный фрикатив "x" / "xʲ" (отдельного класса
//     [ɣ] в инвентаре нет) → правило задано как "g" ↔ "x".
//   • Редуцированные безударные о/а в эталоне → "ʌ" (1-й предударный) / "ə";
//     северное оканье произносит их как полное "o" → правило "ʌ"/"ə" ↔ "o".
//   • ц → "ts", ч → "tɕ" (северное цоканье/чоканье — их неразличение).
//   • Петербургское эканье: предударная /e/ ближе к "e", а не к "ɪ".
// Все правила заданы в символах, КОТОРЫЕ реально могут встретиться по обе стороны
// сравнения (классификатор → "x"/"o"/"ts"/"tɕ"/"e"; G2P → "g"/"ʌ"/"ə"/"ɪ"/…).
// ==================================================================================

/// Чистый, детерминированный справочник диалектных фонемных эквивалентностей.
///
/// Stateless namespace: только статические данные и функции. COPPA-safe (локальный,
/// без сети). Используется ``ChildSpeechScoringPolicy`` для диалект-толерантного
/// сравнения фонем.
public enum RegionalDialectPhonetics {

    /// Допустимые диалектные варианты для одного диалекта.
    ///
    /// `equivalences[ipa]` — множество фонем, которые в данном диалекте являются
    /// нормативными произнесениями `ipa`. Отношение применяется СИММЕТРИЧНО при
    /// сравнении (эталон↔произнесённое), т.к. ребёнок мог как «диалектизировать»
    /// эталон, так и наоборот произнести литературный вариант диалектного слова.
    public struct Ruleset: Sendable, Equatable {
        /// Карта: эталонная фонема → допустимые диалектные эквиваленты.
        public let equivalences: [String: Set<String>]

        public init(equivalences: [String: Set<String>]) {
            self.equivalences = equivalences
        }

        /// Пустой набор — для литературной нормы (никаких поблажек сверх базовых).
        public static let none = Ruleset(equivalences: [:])
    }

    // MARK: - Диалектные правила

    /// Южнорусское наречие.
    ///
    /// Черты (нормативные для региона, НЕ дефекты):
    ///   • Фрикативное Г: вместо взрывного [g] произносится щелевой звонкий
    ///     велярный [ɣ]. В акустическом инвентаре классификатора
    ///     (``RussianPhonemeInventory``) отдельного класса [ɣ] НЕТ — велярный
    ///     фрикатив распознаётся как ближайший щелевой велярный [x]. Поэтому
    ///     эквивалентность задаётся в РЕАЛИЗУЕМЫХ классификатором символах:
    ///     эталонное [g]/[gʲ] ↔ произнесённое [x]/[xʲ] (южный фрикативный г).
    ///   • Мягкое [tʲ] в окончаниях 3-го лица глаголов («идёть») — допускаем
    ///     эквивалент [t]↔[tʲ] как региональный вариант.
    private static let south = Ruleset(equivalences: [
        "g":  ["x"],
        "gʲ": ["xʲ", "x"],
        // мягкое окончание глаголов «идёть»: t ↔ tʲ как региональный вариант.
        "t":  ["tʲ"]
    ])

    /// Севернорусское наречие (включая уральские говоры).
    ///
    /// Черты:
    ///   • Оканье: безударные /o/ не редуцируются до [ʌ]/[ə], а сохраняют [o]
    ///     («молоко» как [moloko], а не [mʌlʌko]). Допускаем [ʌ]↔[o] и [ə]↔[o].
    ///   • Цоканье/чоканье: неразличение [ts] и [tɕ] (ц↔ч) — северная черта.
    private static let north = Ruleset(equivalences: [
        "ʌ":  ["o"],
        "ə":  ["o"],
        // цоканье/чоканье: ц и ч могут совпадать.
        "ts": ["tɕ"],
        "tɕ": ["ts"]
    ])

    /// Петербургское произношение.
    ///
    /// Надёжно проверяемая и инвентарю-совместимая черта — эканье: более чёткие
    /// безударные гласные, где предударная /e/ реализуется ближе к [e], а не
    /// редуцируется к [ɪ] (как в московском иканье). Консервативно — одно правило
    /// [ɪ] ↔ [e]; узколокальные/спорные черты намеренно не включены.
    private static let petersburg = Ruleset(equivalences: [
        "ɪ": ["e"]
    ])

    /// Московское произношение — это и есть база литературной нормы (аканье,
    /// редукция). Дополнительных поблажек сверх базовой child-aware политики не
    /// требуется: правил нет.
    private static let moscow = Ruleset.none

    /// Центральный / литературная норма — без диалектных поблажек.
    private static let central = Ruleset.none

    // MARK: - Доступ

    /// Возвращает набор диалектных правил по идентификатору диалекта.
    ///
    /// Неизвестный/`central`/`moscow` → ``Ruleset/none`` (без поблажек). Это
    /// гарантирует: стандартный диалект сохраняет ПРЕЖНЕЕ поведение скоринга.
    public static func ruleset(for dialectId: String) -> Ruleset {
        switch dialectId {
        case "south":      return south
        case "ural":       return north   // уральские говоры — северного типа (оканье)
        case "petersburg": return petersburg
        case "moscow":     return moscow
        case "central":    return central
        default:           return .none
        }
    }

    /// true, если в данном диалекте `produced` — нормативный вариант `reference`
    /// (или наоборот). Сравнение симметрично.
    ///
    /// - Parameters:
    ///   - reference: эталонная фонема из G2P-транскрипции слова.
    ///   - produced: фонема, фактически произнесённая (распознанная).
    ///   - ruleset: правила выбранного диалекта.
    public static func isPermissibleVariant(
        reference: String,
        produced: String,
        ruleset: Ruleset
    ) -> Bool {
        if ruleset.equivalences[reference]?.contains(produced) == true { return true }
        if ruleset.equivalences[produced]?.contains(reference) == true { return true }
        return false
    }
}

// MARK: - DialectProfileProviding

/// Источник текущего выбранного диалекта ребёнка для слоёв скоринга/ASR.
///
/// Реализуется поверх того же `UserDefaults`-хранилища, в которое пишет
/// ``DialectAdaptationInteractor`` — единый источник правды, без дублирования
/// ключей. Мок-реализация подставляется в тестах и Preview.
public protocol DialectProfileProviding: Sendable {
    /// Возвращает выбранный диалект для ребёнка. Если выбор не сделан — `.default`
    /// (литературная норма).
    func currentDialect(childId: String) -> RegionalDialect
}

// MARK: - DialectProfileStore (live)

/// Live-реализация ``DialectProfileProviding`` поверх `UserDefaults`.
///
/// Читает тот же ключ, что пишет ``DialectAdaptationInteractor``
/// (`happyspeech.dialect.<childId>.id`). Потокобезопасна: `UserDefaults` сам по
/// себе thread-safe для чтения; собственного мутабельного состояния нет.
public struct DialectProfileStore: DialectProfileProviding, @unchecked Sendable {

    private let userDefaults: UserDefaults

    /// Префикс ключей — ОБЯЗАН совпадать с ``DialectAdaptationInteractor``.
    private static let keyPrefix = "happyspeech.dialect."

    /// Ключ выбранного диалекта для ребёнка (единый формат с интерактором).
    public static func selectedKey(childId: String) -> String {
        "\(keyPrefix)\(childId).id"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func currentDialect(childId: String) -> RegionalDialect {
        let storedId = userDefaults.string(forKey: Self.selectedKey(childId: childId))
        return storedId.flatMap { RegionalDialect.find(id: $0) } ?? RegionalDialect.default
    }
}

// MARK: - DialectProfileProviding helpers

public extension DialectProfileProviding {

    /// Удобный доступ к ruleset выбранного диалекта ребёнка.
    func ruleset(childId: String) -> RegionalDialectPhonetics.Ruleset {
        RegionalDialectPhonetics.ruleset(for: currentDialect(childId: childId).id)
    }
}
