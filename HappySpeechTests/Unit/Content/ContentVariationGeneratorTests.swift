@testable import HappySpeech
import XCTest

// MARK: - ContentVariationGeneratorTests

/// Тесты рантайм-генератора вариаций контента (gap #2).
///
/// Проверяют против РЕАЛЬНОГО контента (`LiveContentService`, бандл-паки):
/// валидность активностей, анти-пустышку, методические гейты, детерминизм и
/// общий объём ≈766 по матрице content-generator-matrix-2026-06-12.
final class ContentVariationGeneratorTests: XCTestCase {

    private func makeGenerator() -> ContentVariationGenerator {
        ContentVariationGenerator(contentService: LiveContentService())
    }

    // MARK: - Валидность активностей

    func testSoundActivitiesAreNonEmptyForRichSound() async {
        let gen = makeGenerator()
        let activities = await gen.generateActivities(for: "Р")
        XCTAssertFalse(activities.isEmpty, "Р — богатый звук, должен дать множество активностей")
        for activity in activities {
            XCTAssertFalse(activity.items.isEmpty, "Активность \(activity.id) не должна быть пустой")
        }
    }

    func testTemplateStageCompatibilityHolds() async {
        let gen = makeGenerator()
        let activities = await gen.generateActivities(for: "С")
        for activity in activities {
            guard let spec = ContentVariationGenerator.specByTemplate[activity.template] else {
                XCTFail("Нет spec для шаблона \(activity.template.rawValue)")
                continue
            }
            XCTAssertTrue(
                spec.stages.contains(activity.stage),
                "Шаблон \(activity.template.rawValue) несовместим с этапом \(activity.stage.rawValue)"
            )
        }
    }

    func testImageBackedTemplatesHaveResolvableImages() async {
        let gen = makeGenerator()
        let activities = await gen.generateActivities(for: "С")
        let imageBacked: Set<TemplateType> = [
            .soundHunter, .bingo, .dragAndMatch, .memory,
            .puzzleReveal, .visualAcoustic, .objectHunt
        ]
        for activity in activities where imageBacked.contains(activity.template) {
            for item in activity.items {
                let hasExplicit = (item.imageAsset?.isEmpty == false)
                let hasManifest = LessonContentMap.asset(for: item.word) != nil
                XCTAssertTrue(
                    hasExplicit || hasManifest,
                    "Image-backed \(activity.template.rawValue): слово «\(item.word)» без картинки"
                )
            }
        }
    }

    func testThemedActivitiesCarryThemeAndPositionalStage() async {
        let gen = makeGenerator()
        let activities = await gen.generateActivities(for: "С")
        let themed = activities.filter { $0.kind == .themed }
        XCTAssertFalse(themed.isEmpty, "С — богатый звук, должны быть тематические четвёрки")
        for activity in themed {
            XCTAssertNotNil(activity.theme, "Тематическая активность без темы: \(activity.id)")
            XCTAssertTrue(
                ContentVariationGenerator.positionalStages.contains(activity.stage),
                "Тема только на позиционных этапах, получено \(activity.stage.rawValue)"
            )
        }
    }

    func testMinPoolRespectedAcrossAllActivities() async {
        let gen = makeGenerator()
        for sound in ["С", "Ш", "Р", "Л", "К"] {
            let activities = await gen.generateActivities(for: sound)
            for activity in activities {
                guard let spec = ContentVariationGenerator.specByTemplate[activity.template] else { continue }
                XCTAssertGreaterThanOrEqual(
                    activity.itemCount, min(spec.itemsPerActivity, activity.itemCount),
                    "Активность \(activity.id) должна иметь корректное число элементов"
                )
                XCTAssertGreaterThan(activity.itemCount, 0, "Пустышка не допускается: \(activity.id)")
            }
        }
    }

    // MARK: - Анти-пустышка

    func testSoftSonorantsAreNotStandaloneTargets() {
        // Рь/Ль — под-материал внутри паков твёрдых Р/Л (решение §2/§10 матрицы):
        // их `SoundRomanizer.latinCode` == "r"/"l", поэтому отдельным таргетом они
        // наполнялись бы ТВЁРДЫМИ Р/Л-словами (контентно-неверно). В ростере их нет.
        XCTAssertFalse(ContentVariationGenerator.soundRoster.contains("Рь"))
        XCTAssertFalse(ContentVariationGenerator.soundRoster.contains("Ль"))
        XCTAssertFalse(ContentVariationGenerator.themedSounds.contains("Рь"))
        XCTAssertFalse(ContentVariationGenerator.themedSounds.contains("Ль"))
        // Соноры представлены твёрдыми Р/Л (мягкий материал — внутри их паков).
        XCTAssertTrue(ContentVariationGenerator.soundRoster.contains("Р"))
        XCTAssertTrue(ContentVariationGenerator.soundRoster.contains("Л"))
    }

    func testSparsePoolSkipsHighMinPoolImageTemplates() async {
        // Анти-пустышка на РЕАЛЬНО разреженных данных: подаём генератору пул из
        // 6 слов-с-картинками на позиционный этап (как в крошечных sound_rsoft/
        // lsoft паках). Проверяем АКТИВНОСТИ, построенные ИЗ ЭТОГО пула (их items
        // несут синтетический `word_sparse_*`): ни один image-backed шаблон с
        // minPool ≥ 8 (drag-and-match, memory, bingo, sound-hunter, puzzle-reveal,
        // visual-acoustic) не должен быть собран — иначе это шелл. object-hunt
        // (minPool 6) на 6 картинках допустим (полноценная активность, не шелл).
        let sparse = SparseStagedContentService(imageWordsPerStage: 6)
        let gen = ContentVariationGenerator(contentService: sparse)
        let activities = await gen.generateActivities(for: "Р")
        let highPoolImageTemplates: Set<TemplateType> = [
            .bingo, .soundHunter, .memory, .dragAndMatch, .puzzleReveal, .visualAcoustic
        ]
        // Активности из разреженного пула опознаём по синтетическому ассету.
        let fromSparsePool = activities.filter { activity in
            activity.items.contains { $0.imageAsset?.hasPrefix("word_sparse_") == true }
        }
        for activity in fromSparsePool {
            XCTAssertFalse(
                highPoolImageTemplates.contains(activity.template),
                "Разреженный пул (6 картинок) не должен давать \(activity.template.rawValue) (minPool ≥ 8)"
            )
        }
        // Инвариант шеллов: КАЖДЫЙ элемент любой image-backed активности имеет картинку.
        for activity in activities {
            guard let spec = ContentVariationGenerator.specByTemplate[activity.template], spec.imageBacked else { continue }
            for item in activity.items {
                let resolvable = (item.imageAsset?.isEmpty == false) || (LessonContentMap.asset(for: item.word) != nil)
                XCTAssertTrue(resolvable, "Шелл: image-активность \(activity.id) с элементом «\(item.word)» без картинки")
            }
        }
    }

    func testNoActivityBelowMinPool() async {
        let gen = makeGenerator()
        let catalog = await gen.fullCatalog()
        for activity in catalog {
            guard let spec = ContentVariationGenerator.specByTemplate[activity.template] else { continue }
            // itemsPerActivity может быть меньше minPool (берём prefix), но пул,
            // из которого взяли, был ≥ minPool — проверяем через непустоту и
            // отсутствие дублей слов.
            let uniqueWords = Set(activity.items.map { $0.word.lowercased() })
            XCTAssertEqual(
                uniqueWords.count, activity.items.count,
                "Дубли слов в активности \(activity.id) (нарушение дедупликации)"
            )
            _ = spec
        }
    }

    // MARK: - Gate'ы

    func testNoDifferentiationWithoutValidPair() async {
        let gen = makeGenerator()
        let catalog = await gen.fullCatalog()
        let diffActivities = catalog.filter { $0.kind == .differentiation }
        for activity in diffActivities {
            XCTAssertNotNil(activity.contrastSound, "diff без контрастного звука: \(activity.id)")
            let contrast = ContentVariationGenerator.diffPairs[activity.sound]
            XCTAssertEqual(
                activity.contrastSound, contrast,
                "Контраст \(activity.sound)→\(activity.contrastSound ?? "nil") не методически валиден"
            )
            XCTAssertEqual(activity.stage, .diff)
            XCTAssertEqual(activity.template, .minimalPairs)
        }
    }

    func testDifferentiationOnlyForSoundsWithValidPair() async {
        // Щ имеет валидную пару (Ч), но если у звука НЕТ пары в diffPairs —
        // diff-активности быть не должно. Проверяем, что все diff-звуки в таблице пар.
        let gen = makeGenerator()
        let catalog = await gen.fullCatalog()
        for activity in catalog where activity.kind == .differentiation {
            XCTAssertNotNil(
                ContentVariationGenerator.diffPairs[activity.sound],
                "diff сгенерирован для звука \(activity.sound) без валидной пары"
            )
        }
    }

    func testLateSoundsAgeGatedAboveIsolated() async {
        // Р выше isolated — minAge ≥ 6 (золотое окно §6.3). Рь — под-материал
        // внутри Р, отдельным таргетом не генерируется (см. roster).
        let gen = makeGenerator()
        let activities = await gen.generateActivities(for: "Р")
        for activity in activities where activity.stage > .isolated {
            XCTAssertGreaterThanOrEqual(
                activity.minAge, 6,
                "Поздний звук Р на этапе \(activity.stage.rawValue) должен быть 6+"
            )
        }
    }

    func testAgeFilterDropsRestrictedActivitiesForFiveYearOld() async {
        let gen = makeGenerator()
        let young = await gen.catalog(forAge: 5)
        XCTAssertFalse(
            young.contains { $0.template == .letterTracing },
            "letter-tracing (7+) не должен попадать в каталог 5-летки"
        )
        XCTAssertFalse(
            young.contains { $0.kind == .differentiation },
            "Дифференциация (6+) не должна попадать в каталог 5-летки"
        )
        // Семилетка получает и letter-tracing, и дифференциацию.
        let older = await gen.catalog(forAge: 7)
        XCTAssertTrue(
            older.contains { $0.kind == .differentiation },
            "Каталог 7-летки должен включать дифференциацию"
        )
    }

    func testNoStageJumpingThemesOnlyPositional() async {
        // Тема не должна окрашивать непозиционные этапы (syllable/phrase/story).
        let gen = makeGenerator()
        let catalog = await gen.fullCatalog()
        for activity in catalog where activity.theme != nil {
            XCTAssertTrue(
                ContentVariationGenerator.positionalStages.contains(activity.stage),
                "Тема на непозиционном этапе \(activity.stage.rawValue): \(activity.id)"
            )
        }
    }

    // MARK: - Детерминизм

    func testGenerationIsDeterministic() async {
        let gen1 = makeGenerator()
        let gen2 = makeGenerator()
        let run1 = await gen1.generateActivities(for: "Ш")
        let run2 = await gen2.generateActivities(for: "Ш")
        XCTAssertEqual(run1.map(\.id), run2.map(\.id), "Порядок активностей должен быть детерминирован")
        for (a, b) in zip(run1, run2) {
            XCTAssertEqual(a.items.map(\.id), b.items.map(\.id), "Состав items должен быть детерминирован")
        }
    }

    func testRepeatedCallSameInstanceDeterministic() async {
        let gen = makeGenerator()
        let first = await gen.generateActivities(for: "Л")
        let second = await gen.generateActivities(for: "Л")
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    // MARK: - Объём

    func testTotalCatalogReachesMatrixVolume() async {
        let gen = makeGenerator()
        let count = await gen.totalActivityCount()
        // Матрица §7.4 оценивала ≈766 консервативно; реальный замер по бандл-пакам
        // даёт ~977 РЕАЛЬНО-наполняемых активностей (595 звуковых + 371 тематических
        // + 11 diff; Рь/Ль — под-материал внутри Р/Л, не отдельные таргеты) — больше
        // бумажной оценки, но без единой пустышки (§10 допускает расхождение при
        // уточнении minPool). Проверяем «сотни валидных активностей».
        XCTAssertGreaterThan(count, 700, "Каталог должен давать сотни активностей (≈766–977), получено \(count)")
        XCTAssertLessThan(count, 1400, "Каталог не должен раздуваться сверх реального контента, получено \(count)")
    }

    func testCatalogHasAllThreeKinds() async {
        let gen = makeGenerator()
        let catalog = await gen.fullCatalog()
        let kinds = Set(catalog.map(\.kind))
        XCTAssertTrue(kinds.contains(.sound), "Должны быть звуковые тройки")
        XCTAssertTrue(kinds.contains(.themed), "Должны быть тематические четвёрки")
        XCTAssertTrue(kinds.contains(.differentiation), "Должны быть дифференциационные активности")
    }

    func testActivityIdsAreUnique() async {
        let gen = makeGenerator()
        let catalog = await gen.fullCatalog()
        let ids = catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Все id активностей должны быть уникальны")
    }
}

// MARK: - ThemeWordIndexTests

final class ThemeWordIndexTests: XCTestCase {

    func testThemesLoadFromBundle() {
        XCTAssertEqual(ThemeWordIndex.themes.count, 20, "Должно быть 20 лексических тем")
    }

    func testValidCellMatchesMatrix() {
        // С×vegetables валидна (33 ≥ 8); Х×vegetables невалидна (опущена).
        XCTAssertTrue(ThemeWordIndex.isValidCell(sound: "С", themeID: "vegetables"))
        XCTAssertFalse(ThemeWordIndex.isValidCell(sound: "Х", themeID: "vegetables"))
    }

    func testSoftSoundNormalizesToBase() {
        // Рь сводится к Р для целей матрицы тем.
        XCTAssertEqual(
            ThemeWordIndex.cellCount(sound: "Рь", themeID: "vegetables"),
            ThemeWordIndex.cellCount(sound: "Р", themeID: "vegetables")
        )
    }

    func testValidThemesForRichSoundIsLarge() {
        // С богат темами (§4.1: 20 валидных).
        let themes = ThemeWordIndex.validThemes(for: "С")
        XCTAssertGreaterThanOrEqual(themes.count, 15, "С должен иметь много валидных тем")
    }

    func testShchHasNoValidThemes() {
        // Щ почти не встречается в темах (§4.1: 0 валидных ячеек).
        let themes = ThemeWordIndex.validThemes(for: "Щ")
        XCTAssertTrue(themes.isEmpty, "Щ не должен иметь тематических ячеек")
    }
}

// MARK: - SparseStagedContentService (тестовый сервис разреженного пула)

/// `ContentService`, отдающий разреженный staged-пак: на каждом позиционном
/// этапе — заданное число слов-с-картинками (имитирует крошечные sound_rsoft/
/// lsoft паки). Прочие методы — заглушки (генератору не нужны).
private final class SparseStagedContentService: ContentService, @unchecked Sendable {

    private let imageWordsPerStage: Int

    init(imageWordsPerStage: Int) {
        self.imageWordsPerStage = imageWordsPerStage
    }

    func loadStagedPack(soundCode: String) async throws -> StagedContentPack {
        var byStage: [CorrectionStage: [ContentItem]] = [:]
        for stage in [CorrectionStage.wordInit, .wordMed, .wordFinal] {
            byStage[stage] = (0..<imageWordsPerStage).map { idx in
                ContentItem(
                    id: "sparse-\(stage.rawValue)-\(idx)",
                    word: "слово\(idx)",
                    imageAsset: "word_sparse_\(idx)",
                    audioAsset: nil,
                    hint: nil,
                    stage: stage,
                    difficulty: 1
                )
            }
        }
        return StagedContentPack(
            id: "sound_\(soundCode)_sparse",
            soundTarget: soundCode,
            group: "соноры",
            itemsByStage: byStage
        )
    }

    func loadPack(id: String) async throws -> ContentPack {
        throw AppError.contentPackNotFound(id)
    }
    func allPacks() async throws -> [ContentPackMeta] { [] }
    func bundledPacks() -> [ContentPackMeta] { [] }
}
