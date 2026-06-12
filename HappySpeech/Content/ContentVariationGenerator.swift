import Foundation
import OSLog

// MARK: - GeneratedActivity

/// Сгенерированная активность — единица контента, которую видит ребёнок в одном
/// «окне» урока: конкретный шаблон, наполненный реальным пулом элементов одной
/// `(звук, этап)` и опционально одной темы.
///
/// Активности **строятся в рантайме** из существующих паков (`ContentVariationGenerator`)
/// по матрице `звук × этап × шаблон [× тема]`, описанной в спеке
/// `content-generator-matrix-2026-06-12.md`. Слова и картинки **не выдумываются** —
/// `items` ссылаются на реальные `ContentItem` из канонических `sound_*`-паков.
public struct GeneratedActivity: Sendable, Identifiable, Equatable {

    /// Категория активности.
    public enum Kind: String, Sendable {
        /// Звуковая тройка `(звук, этап, шаблон)` без тематической окраски.
        case sound
        /// Тематическая четвёрка `(звук, позиционный-этап, тема, шаблон)`.
        case themed
        /// Дифференциация `(звук, diff, minimal-pairs)` с контрастным звуком.
        case differentiation
    }

    /// Стабильный детерминированный id вида
    /// `gen_<latin>_<stage>_<theme?>_<template>` (`contrastSound` для diff).
    public let id: String
    public let kind: Kind
    /// Кириллический целевой звук («Р», «Ш», «Рь» …).
    public let sound: String
    /// Контрастный звук — только для `differentiation`.
    public let contrastSound: String?
    public let stage: CorrectionStage
    /// Тема — только для `themed`.
    public let theme: String?
    public let template: TemplateType
    /// Минимальный возраст (лет) для допуска активности (возрастные гейты §6.3).
    public let minAge: Int
    /// Диапазон сложности items, попавших в активность ([min, max] из difficulty).
    public let difficultyBand: ClosedRange<Int>
    /// Реальные элементы пака (слова с картинками/аудио). Не копии, а отобранный
    /// срез существующих `ContentItem`.
    public let items: [ContentItem]
    /// Нужен ли микрофон для шаблона.
    public let requiresMic: Bool

    public var itemCount: Int { items.count }

    public static func == (lhs: GeneratedActivity, rhs: GeneratedActivity) -> Bool {
        lhs.id == rhs.id && lhs.items.map(\.id) == rhs.items.map(\.id)
    }
}

// MARK: - TemplateSpec

/// Методические параметры шаблона: совместимые этапы, размер пула и активности,
/// требование микрофона/картинок, возрастной минимум. Формализация §3 спеки.
struct TemplateSpec: Sendable {
    let template: TemplateType
    /// Этапы, на которых шаблон уместен.
    let stages: Set<CorrectionStage>
    /// Минимальный размер ДОСТУПНОГО пула, ниже которого активность не строится.
    let minPool: Int
    /// Сколько элементов кладётся в одну активность (берётся `prefix`).
    let itemsPerActivity: Int
    /// Требует ли каждый элемент валидной картинки (image-backed механика).
    let imageBacked: Bool
    let requiresMic: Bool
    /// Возрастной минимум именно от шаблона (например letter-tracing — 7 лет).
    let minAge: Int
}

// MARK: - ContentVariationGenerator

/// Рантайм-генератор вариаций контента уроков (gap #2).
///
/// По матрице из `content-generator-matrix-2026-06-12.md` строит активности
/// `(звук × этап × шаблон [× тема])` из уже существующих, image-backed,
/// позиционно-разложенных элементов канонических `sound_*`-паков и тем
/// `pack_lexical_themes`. Генерация **ленивая и детерминированная** — ничего не
/// раздувает бандл (нет 766 JSON), активности собираются по запросу
/// планировщика / каталога.
///
/// Принципы (из спеки):
/// - **Анти-пустышка:** активность строится ТОЛЬКО если `|пул| ≥ minPool`;
///   image-backed шаблоны дополнительно требуют валидной картинки у каждого
///   элемента (фильтр ДО подсчёта порога). Недостаточный пул → пропуск.
/// - **Gate'ы:** template↔stage совместимость, stage-ladder, diff только для
///   методически валидных пар, возрастные ограничения (§6).
/// - **Детерминизм:** порядок звуков/этапов/тем/шаблонов фиксирован; выбор
///   элементов — стабильный `prefix` по difficulty-band (без `shuffled`).
public actor ContentVariationGenerator {

    // MARK: - Dependencies

    private let contentService: any ContentService
    /// Кэш загруженных staged-паков на время жизни генератора.
    private var stagedPackCache: [String: StagedContentPack] = [:]

    public init(contentService: any ContentService) {
        self.contentService = contentService
    }

    // MARK: - Sound roster (14 реальных таргетов с паками, §2)

    /// Кириллические таргет-звуки в онтогенетическом порядке (свистящие →
    /// шипящие → соноры → заднеязычные). Совпадает с реальными `sound_*`-паками.
    ///
    /// **Рь/Ль — НЕ самостоятельные таргеты генератора** (решение по §2/§10
    /// матрицы — открытый вопрос закрыт): мягкие соноры ведутся как под-материал
    /// ВНУТРИ паков твёрдых Р/Л (sound_r_pack содержит ~278 мягких items,
    /// sound_l_pack ~227). Причины:
    ///   1. `SoundRomanizer.latinCode("Рь") == "r"` → `loadStagedPack("Рь")`
    ///      резолвится в `sound_r_pack` (полный пул твёрдого Р). Включи мы Рь в
    ///      ростер — генератор наполнял бы «Рь»-активности ТВЁРДЫМИ Р-словами
    ///      (рак/роза) — контентно-неверно (битая активность по смыслу).
    ///   2. Выделенные `sound_rsoft_pack`/`sound_lsoft_pack` крошечны (5–7
    ///      image-слов/позицию) — image-backed шаблоны (minPool ≥ 6/8/12/16) на
    ///      них дали бы шеллы. Анти-пустышка их и так отсекает.
    /// Поэтому Рь/Ль покрываются через таргеты Р/Л (их паки содержат мягкий
    /// материал), а отдельных троек/четвёрок генератор для них не строит.
    public static let soundRoster: [String] = [
        "С", "З", "Ц",            // свистящие
        "Ш", "Ж", "Ч", "Щ",       // шипящие
        "Р", "Л",                 // соноры (Рь/Ль — под-материал внутри Р/Л, не отдельные таргеты)
        "К", "Г", "Х"             // заднеязычные
    ]

    /// Звуки с природно-поздней нормой (Р) — возрастной гейт «золотого окна» §6.3.
    /// Рь (та же поздняя норма) ведётся как под-материал внутри Р (см. `soundRoster`),
    /// поэтому в ростер не входит; его активности наследуют Р-гейт автоматически.
    private static let lateSounds: Set<String> = ["Р"]

    // MARK: - Template registry (§3)

    static let templateSpecs: [TemplateSpec] = [
        TemplateSpec(
            template: .articulationImitation, stages: [.prep, .isolated],
            minPool: 4, itemsPerActivity: 5, imageBacked: false, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .breathing, stages: [.prep],
            minPool: 3, itemsPerActivity: 4, imageBacked: false, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .arActivity, stages: [.prep, .isolated],
            minPool: 1, itemsPerActivity: 1, imageBacked: false, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .rhythm, stages: [.prep, .syllable, .story],
            minPool: 4, itemsPerActivity: 6, imageBacked: false, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .listenAndChoose, stages: [.isolated, .syllable, .wordInit, .wordMed, .wordFinal, .diff],
            minPool: 6, itemsPerActivity: 4, imageBacked: false, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .sorting, stages: [.isolated, .syllable, .wordInit, .wordMed, .wordFinal, .phrase, .diff],
            minPool: 10, itemsPerActivity: 12, imageBacked: false, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .soundHunter, stages: [.isolated, .wordInit, .wordMed],
            minPool: 12, itemsPerActivity: 12, imageBacked: true, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .repeatAfterModel, stages: [.syllable, .wordInit, .wordMed, .wordFinal, .phrase, .sentence, .story],
            minPool: 8, itemsPerActivity: 8, imageBacked: false, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .bingo, stages: [.syllable, .wordInit],
            minPool: 16, itemsPerActivity: 16, imageBacked: true, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .dragAndMatch, stages: [.wordInit, .wordMed, .wordFinal, .phrase, .diff],
            minPool: 8, itemsPerActivity: 8, imageBacked: true, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .memory, stages: [.wordInit, .wordMed, .wordFinal, .diff],
            minPool: 12, itemsPerActivity: 8, imageBacked: true, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .puzzleReveal, stages: [.wordInit, .wordMed],
            minPool: 8, itemsPerActivity: 8, imageBacked: true, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .visualAcoustic, stages: [.wordInit, .wordMed],
            minPool: 8, itemsPerActivity: 8, imageBacked: true, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .minimalPairs, stages: [.wordInit, .wordMed, .wordFinal, .phrase, .sentence, .diff],
            minPool: 10, itemsPerActivity: 10, imageBacked: false, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .storyCompletion, stages: [.phrase, .sentence, .story],
            minPool: 4, itemsPerActivity: 5, imageBacked: false, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .narrativeQuest, stages: [.sentence, .story],
            minPool: 5, itemsPerActivity: 6, imageBacked: false, requiresMic: true, minAge: 5
        ),
        TemplateSpec(
            template: .objectHunt, stages: [.wordInit, .wordMed],
            minPool: 6, itemsPerActivity: 8, imageBacked: true, requiresMic: false, minAge: 5
        ),
        TemplateSpec(
            template: .letterTracing, stages: [.wordInit],
            minPool: 1, itemsPerActivity: 1, imageBacked: false, requiresMic: false, minAge: 7
        )
    ]

    /// `template → spec` для O(1) доступа.
    static let specByTemplate: [TemplateType: TemplateSpec] = Dictionary(
        templateSpecs.map { ($0.template, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// Совместимые шаблоны для этапа, в детерминированном порядке `templateSpecs`.
    static func templates(for stage: CorrectionStage) -> [TemplateType] {
        templateSpecs.filter { $0.stages.contains(stage) }.map(\.template)
    }

    /// Позиционные этапы — единственные, что окрашиваются темой (§4, §6.4).
    static let positionalStages: Set<CorrectionStage> = [.wordInit, .wordMed, .wordFinal]

    /// Шаблоны, которыми окрашиваются темы (§4.1: «≥8 слов» набор —
    /// L&C / sorting / drag-and-match / memory). Остальные шаблоны на тему не
    /// натягиваются (sound-hunter/bingo требуют ≥12/16 картинок — отсеются сами;
    /// repeat-after-model/minimal-pairs внетематичны по методике). Тематический
    /// этап нормализуем к `wordInit` (тема описывает словарь, не позицию) — это
    /// исключает ×3-дублирование одинаковых тематических активностей на
    /// wordInit/wordMed/wordFinal. §4, §7.3.
    static let themedTemplates: [TemplateType] = [
        .listenAndChoose, .sorting, .dragAndMatch, .memory
    ]

    /// Звуки, получающие тематические четвёрки — только базовые с собственными
    /// тематическими ячейками. Мягкие Рь/Ль ведутся как под-материал внутри Р/Л
    /// и своих тематических четвёрок не получают (§4 примечание).
    static let themedSounds: Set<String> = [
        "С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Л", "К", "Г", "Х"
    ]

    // MARK: - Differentiation pairs (§6.2)

    /// Методически валидные diff-пары (главная пара дифференциации, sound-groups §6).
    /// `звук → контрастный звук`. Произвольные пары не генерируются.
    static let diffPairs: [String: String] = [
        "С": "Ш", "Ш": "С",   // свистящая ↔ шипящая
        "З": "Ж", "Ж": "З",   // звонкая свистящая ↔ звонкая шипящая
        "Ц": "С",             // аффриката ↔ свистящая
        "Ч": "Щ", "Щ": "Ч",   // аффриката ↔ щелевая мягкая
        "Р": "Л", "Л": "Р",   // вибрант ↔ латеральный (мягкая пара Рь–Ль ведётся внутри Р/Л)
        "Г": "К", "К": "Г",   // звонкая ↔ глухая заднеязычная
        "Х": "К"
    ]

    // MARK: - Public API

    /// Полный каталог сгенерированных активностей по всем валидным тройкам/
    /// четвёркам. Детерминированный порядок; пустышки исключены. Без фильтра по
    /// возрасту (возрастной гейт применяет вызывающий — см. `catalog(forAge:)`).
    public func fullCatalog() async -> [GeneratedActivity] {
        var result: [GeneratedActivity] = []
        for sound in Self.soundRoster {
            result.append(contentsOf: await generateActivities(for: sound))
        }
        return result
    }

    /// Каталог, отфильтрованный по возрасту ребёнка (возрастные гейты §6.3:
    /// letter-tracing 7+, поздние Р/Рь выше isolated — 6+).
    public func catalog(forAge age: Int) async -> [GeneratedActivity] {
        await fullCatalog().filter { $0.minAge <= age }
    }

    /// Активности конкретного звука (все валидные этапы/темы/шаблоны).
    /// Детерминированный порядок: сначала звуковые тройки по этапам
    /// (`CorrectionStage.allCases`), затем diff, затем тематические четвёрки.
    public func generateActivities(for sound: String) async -> [GeneratedActivity] {
        guard let pack = await loadStaged(sound) else { return [] }
        var activities: [GeneratedActivity] = []

        // 1. Звуковые тройки `(звук, этап, шаблон)` — из пула пака по этапам.
        for stage in CorrectionStage.allCases {
            let pool = pack.items(for: stage)
            guard !pool.isEmpty else { continue }

            if stage == .diff {
                activities.append(contentsOf: diffActivities(sound: sound, pool: pool))
                continue
            }
            for template in Self.templates(for: stage) {
                if let activity = makeSoundActivity(sound: sound, stage: stage, template: template, pool: pool) {
                    activities.append(activity)
                }
            }
        }

        // 2. Тематические четвёрки — один раз на (звук × тема × шаблон),
        // на нормализованном позиционном этапе `wordInit`. Пул — слова темы с
        // целевым звуком (матрица §4.1), резолвленные в картинки через manifest.
        activities.append(contentsOf: themedActivities(for: sound))
        return activities
    }

    /// Тематические четвёрки для звука: пул — слова темы с целевым звуком.
    private func themedActivities(for sound: String) -> [GeneratedActivity] {
        guard Self.themedSounds.contains(sound) else { return [] }
        var result: [GeneratedActivity] = []
        for themeID in ThemeWordIndex.validThemes(for: sound) {
            let themedPool = ThemeWordIndex.soundWords(theme: themeID, sound: sound)
            guard themedPool.count >= ThemeWordIndex.validCellThreshold else { continue }
            for template in Self.themedTemplates {
                if let activity = makeThemedActivity(
                    sound: sound, stage: .wordInit, theme: themeID, template: template, pool: themedPool
                ) {
                    result.append(activity)
                }
            }
        }
        return result
    }

    /// Сводный счётчик валидных активностей (честная замена `estimatedContentCount`).
    public func totalActivityCount() async -> Int {
        await fullCatalog().count
    }

    // MARK: - Activity builders

    /// Звуковая тройка `(звук, этап, шаблон)`. Возвращает nil при пустышке.
    private func makeSoundActivity(
        sound: String,
        stage: CorrectionStage,
        template: TemplateType,
        pool: [ContentItem]
    ) -> GeneratedActivity? {
        guard let spec = Self.specByTemplate[template] else { return nil }
        let available = filterAvailable(pool, spec: spec)
        guard available.count >= spec.minPool else { return nil }
        let picked = pick(available, count: spec.itemsPerActivity)
        guard !picked.isEmpty else { return nil }
        let theme: String? = nil
        return GeneratedActivity(
            id: activityID(sound: sound, stage: stage, theme: theme, template: template, contrast: nil),
            kind: .sound,
            sound: sound,
            contrastSound: nil,
            stage: stage,
            theme: theme,
            template: template,
            minAge: minAge(sound: sound, stage: stage, spec: spec),
            difficultyBand: difficultyBand(of: picked),
            items: picked,
            requiresMic: spec.requiresMic
        )
    }

    /// Тематическая четвёрка `(звук, позиционный-этап, тема, шаблон)`.
    private func makeThemedActivity(
        sound: String,
        stage: CorrectionStage,
        theme: String,
        template: TemplateType,
        pool: [ContentItem]
    ) -> GeneratedActivity? {
        guard let spec = Self.specByTemplate[template] else { return nil }
        let available = filterAvailable(pool, spec: spec)
        guard available.count >= spec.minPool else { return nil }
        let picked = pick(available, count: spec.itemsPerActivity)
        guard !picked.isEmpty else { return nil }
        return GeneratedActivity(
            id: activityID(sound: sound, stage: stage, theme: theme, template: template, contrast: nil),
            kind: .themed,
            sound: sound,
            contrastSound: nil,
            stage: stage,
            theme: theme,
            template: template,
            minAge: minAge(sound: sound, stage: stage, spec: spec),
            difficultyBand: difficultyBand(of: picked),
            items: picked,
            requiresMic: spec.requiresMic
        )
    }

    /// Дифференциация `(звук, diff, minimal-pairs)` — только для валидной пары
    /// и при ≥10 реальных пар-паронимов (§6.2, §5.3).
    private func diffActivities(sound: String, pool: [ContentItem]) -> [GeneratedActivity] {
        guard let contrast = Self.diffPairs[sound] else { return [] }
        // minimal-pairs на diff: каждый diff-item — пара паронимов («A — B» или
        // pipe-encoded картинка). Требуется ≥ minPool реальных пар.
        guard let spec = Self.specByTemplate[.minimalPairs] else { return [] }
        let pairs = pool.filter { isParonymPair($0) }
        guard pairs.count >= spec.minPool else { return [] }
        let picked = pick(pairs, count: spec.itemsPerActivity)
        guard !picked.isEmpty else { return [] }
        let activity = GeneratedActivity(
            id: activityID(sound: sound, stage: .diff, theme: nil, template: .minimalPairs, contrast: contrast),
            kind: .differentiation,
            sound: sound,
            contrastSound: contrast,
            stage: .diff,
            theme: nil,
            template: .minimalPairs,
            // Дифференциация надстраивается над автоматизацией → не раньше 6 лет
            // (и для поздних Р/Рь тоже 6+). §6.3.
            minAge: 6,
            difficultyBand: difficultyBand(of: picked),
            items: picked,
            requiresMic: spec.requiresMic
        )
        return [activity]
    }

    // MARK: - Pool helpers

    /// Фильтр доступности: для image-backed шаблонов оставляет только элементы с
    /// валидной картинкой (`imageAsset` или резолв в `word_manifest`). §5.3.
    private func filterAvailable(_ pool: [ContentItem], spec: TemplateSpec) -> [ContentItem] {
        guard spec.imageBacked else { return pool }
        return pool.filter { hasResolvableImage($0) }
    }

    /// Есть ли у элемента валидная картинка: явный `imageAsset` (в т.ч. pipe-пара)
    /// либо резолв слова через `LessonContentMap` (word_manifest).
    private func hasResolvableImage(_ item: ContentItem) -> Bool {
        if let asset = item.imageAsset, !asset.isEmpty { return true }
        return LessonContentMap.asset(for: item.word) != nil
    }

    /// Является ли diff-item реальной парой паронимов (содержит разделитель
    /// «—»/«-» в слове или pipe в картинке). Фабрикация несуществующих пар
    /// запрещена — берём только то, что уже есть в паке. §5.3, §6.2.
    private func isParonymPair(_ item: ContentItem) -> Bool {
        if let asset = item.imageAsset, asset.contains("|") { return true }
        let word = item.word
        return word.contains(" — ") || word.contains(" - ") || word.contains("—")
    }

    /// Детерминированный отбор `count` элементов. Без `shuffled` — стабильный
    /// `prefix` по уже-детерминированному порядку пула (порядок файла). Между
    /// активностями одной тройки дедупликация обеспечивается уникальностью id
    /// (одна тройка = одна активность). §5.3.
    private func pick(_ pool: [ContentItem], count: Int) -> [ContentItem] {
        // Дедуп по слову внутри активности (одно слово не повторяется).
        var seen = Set<String>()
        var unique: [ContentItem] = []
        for item in pool {
            let key = item.word.lowercased()
            if seen.insert(key).inserted { unique.append(item) }
        }
        return Array(unique.prefix(count))
    }

    private func difficultyBand(of items: [ContentItem]) -> ClosedRange<Int> {
        let levels = items.map(\.difficulty)
        let lo = levels.min() ?? 1
        let hi = levels.max() ?? 1
        return lo...max(lo, hi)
    }

    // MARK: - Gates

    /// Возрастной минимум активности (макс из шаблона и звука-этапа). §6.3:
    /// поздние Р/Рь выше изолированного звука — только с 6 лет.
    private func minAge(sound: String, stage: CorrectionStage, spec: TemplateSpec) -> Int {
        var age = spec.minAge
        if Self.lateSounds.contains(sound), stage > .isolated {
            age = max(age, 6)
        }
        return age
    }

    /// Стабильный детерминированный id активности.
    private func activityID(
        sound: String,
        stage: CorrectionStage,
        theme: String?,
        template: TemplateType,
        contrast: String?
    ) -> String {
        let latin = SoundRomanizer.latinCode(for: sound)
        var parts = ["gen", latin, stage.rawValue]
        if let theme { parts.append(theme) }
        parts.append(template.rawValue)
        if let contrast { parts.append(SoundRomanizer.latinCode(for: contrast)) }
        return parts.joined(separator: "_")
    }

    // MARK: - Loading

    private func loadStaged(_ sound: String) async -> StagedContentPack? {
        let key = SoundRomanizer.latinCode(for: sound)
        if let cached = stagedPackCache[key] { return cached }
        do {
            let pack = try await contentService.loadStagedPack(soundCode: sound)
            stagedPackCache[key] = pack
            return pack
        } catch {
            HSLogger.content.error(
                "ContentVariationGenerator: pack for \(sound, privacy: .public) unavailable: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
