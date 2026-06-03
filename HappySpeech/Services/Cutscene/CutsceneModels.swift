import Foundation

// MARK: - Cutscene system models
//
// «Путешествие Ляли по Стране Звуков» — нарративные кат-сцены, маршрутизированные
// по карте звуков (см. спеку cutscene-narrative-spec-2026-06-03). Кат-сцена — это
// fullscreen-видео (9:16) с озвучкой Ляли (Chirp3-HD-Aoede) ИЛИ постер + субтитр
// в Reduce-Motion / при отсутствии видеофайла.
//
// Архитектура: сервис (`CutsceneServiceProtocol`) + один fullScreen-overlay
// (`CutscenePlayerView`) поверх `AppCoordinatorView` — НЕ новый VIP-модуль и НЕ
// `AppRoute` (чтобы не раздувать 200+ маршрутов и не ломать back-stack).
//
// Кат-сцены НЕ зависят от Data/ML/Sync — каталог статический, прогресс приходит
// через триггеры от фич (WorldMap / SessionComplete).

// MARK: - CutsceneKind

/// Тип кат-сцены — определяет приоритет показа и место в нарративной арке.
enum CutsceneKind: String, Sendable, CaseIterable, Equatable {
    /// Завязка арки (после онбординга, перед первым входом на карту).
    case prologue
    /// Интро острова (перед первым уроком острова).
    case islandIntro
    /// Триумф острова (когда остров завершён — все уровни пройдены).
    case islandTriumph
    /// Концовка арки (когда все контентные острова завершены).
    case finale
    /// Интерлюдия-майлстоун (стрик-7 / стрик-30), вне основной линии.
    case milestone

    /// Приоритет показа при «созревании» нескольких сцен одновременно:
    /// `finale (100) > islandTriumph (80) > islandIntro (60) > milestone (40) >
    /// prologue (20)`. Пролог самый низкий — он одноразовый и не конкурирует с
    /// прогрессом островов.
    var priority: Int {
        switch self {
        case .finale:        return 100
        case .islandTriumph: return 80
        case .islandIntro:   return 60
        case .milestone:     return 40
        case .prologue:      return 20
        }
    }
}

// MARK: - CutsceneTrigger

/// Событие, при котором кат-сцена может быть поставлена в очередь показа.
/// Триггеры эмитятся фичами (WorldMap / SessionComplete) и маппятся каталогом
/// в конкретную ``Cutscene``.
enum CutsceneTrigger: Sendable, Equatable {
    /// Онбординг завершён, ребёнок впервые на карте → пролог.
    case onboardingComplete
    /// Перед первым уроком указанного острова → интро.
    case islandIntro(MapIslandID)
    /// Указанный остров завершён (все уровни пройдены) → триумф.
    case islandComplete(MapIslandID)
    /// Все контентные острова завершены → финал.
    case allIslandsComplete
    /// Достигнут стрик в `days` дней (7 / 30) → майлстоун.
    case streak(days: Int)
}

// MARK: - Cutscene

/// Запись каталога кат-сцен. `videoResourceName` — имя `.mp4` без расширения,
/// резолвится через `VideoPlayerServiceProtocol`. Если видеофайла ещё нет в
/// бандле, плеер graceful-фолбэчит на постер + субтитр (`posterAssetName` /
/// `voiceoverKey`) и не падает.
struct Cutscene: Identifiable, Sendable, Equatable {

    let id: String
    let kind: CutsceneKind
    let trigger: CutsceneTrigger
    /// Имя видеофайла без `.mp4` (например `cs_isl_whistling_in`).
    let videoResourceName: String
    /// Имя imageset-постера для Reduce-Motion / missing-video фолбэка.
    let posterAssetName: String
    /// Ключ `Localizable.xcstrings` для субтитр-карточки фолбэка.
    let voiceoverKey: String
    /// Опц. имя `.m4a` озвучки (для фолбэка / проигрывания вне видео).
    let voiceoverAudioName: String?
    /// Остров (`.whistling` и т.д.) — nil для prologue / finale / milestone.
    let mapNode: MapIslandID?
    /// Приоритет показа (по умолчанию берётся из `kind.priority`).
    let priority: Int
    /// Флаг включения. `false` → сцена не показывается (зарезервировано на
    /// будущее, напр. `cs-halfway`).
    let enabled: Bool
    /// Помечено в каталоге, если видео ещё не сгенерировано (плеер фолбэчит на
    /// постер/субтитр). Чисто информационное поле для каталога/кинозала.
    let videoReady: Bool

    init(
        id: String,
        kind: CutsceneKind,
        trigger: CutsceneTrigger,
        videoResourceName: String,
        posterAssetName: String,
        voiceoverKey: String,
        voiceoverAudioName: String? = nil,
        mapNode: MapIslandID? = nil,
        priority: Int? = nil,
        enabled: Bool = true,
        videoReady: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.trigger = trigger
        self.videoResourceName = videoResourceName
        self.posterAssetName = posterAssetName
        self.voiceoverKey = voiceoverKey
        self.voiceoverAudioName = voiceoverAudioName
        self.mapNode = mapNode
        self.priority = priority ?? kind.priority
        self.enabled = enabled
        self.videoReady = videoReady
    }
}

// MARK: - CutsceneCatalog

/// Статический каталог из 16 кат-сцен (1 пролог + 6×2 острова + финал +
/// 2 майлстоуна). Compile-time гарантия имён (паттерн `HelpCenterCorpus`).
/// JSON-зеркало — `Content/Seed/cutscenes.json` (для будущей удалённой конфы).
///
/// `videoReady: true` стоит только у 3 пилот-роликов (пролог + интро/триумф
/// Свистящих). У остальных 13 видео ещё не сгенерировано — плеер их корректно
/// фолбэчит на постер/субтитр или пропускает.
enum CutsceneCatalog {

    static let all: [Cutscene] = prologue + islands + finaleAndMilestones

    // MARK: Пролог

    private static let prologue: [Cutscene] = [
        Cutscene(
            id: "cs-prologue",
            kind: .prologue,
            trigger: .onboardingComplete,
            videoResourceName: "cs_prologue",
            posterAssetName: "cutscene_poster_prologue",
            voiceoverKey: "cutscene.cs-prologue.subtitle",
            mapNode: nil,
            videoReady: true
        )
    ]

    // MARK: Острова (интро + триумф)

    private static let islands: [Cutscene] = [
        // Свистящие (С/З/Ц) — ПИЛОТ.
        Cutscene(
            id: "cs-isl-whistling-in",
            kind: .islandIntro,
            trigger: .islandIntro(.whistling),
            videoResourceName: "cs_isl_whistling_in",
            posterAssetName: "cutscene_poster_whistling_in",
            voiceoverKey: "cutscene.cs-isl-whistling-in.subtitle",
            mapNode: .whistling,
            videoReady: true
        ),
        Cutscene(
            id: "cs-isl-whistling-out",
            kind: .islandTriumph,
            trigger: .islandComplete(.whistling),
            videoResourceName: "cs_isl_whistling_out",
            posterAssetName: "cutscene_poster_whistling_out",
            voiceoverKey: "cutscene.cs-isl-whistling-out.subtitle",
            mapNode: .whistling,
            videoReady: true
        ),
        // Шипящие (Ш/Ж).
        Cutscene(
            id: "cs-isl-hissing-in",
            kind: .islandIntro,
            trigger: .islandIntro(.hissing),
            videoResourceName: "cs_isl_hissing_in",
            posterAssetName: "cutscene_poster_hissing_in",
            voiceoverKey: "cutscene.cs-isl-hissing-in.subtitle",
            mapNode: .hissing
        ),
        Cutscene(
            id: "cs-isl-hissing-out",
            kind: .islandTriumph,
            trigger: .islandComplete(.hissing),
            videoResourceName: "cs_isl_hissing_out",
            posterAssetName: "cutscene_poster_hissing_out",
            voiceoverKey: "cutscene.cs-isl-hissing-out.subtitle",
            mapNode: .hissing
        ),
        // Аффрикаты (Ч/Щ).
        Cutscene(
            id: "cs-isl-affr-in",
            kind: .islandIntro,
            trigger: .islandIntro(.affricates),
            videoResourceName: "cs_isl_affr_in",
            posterAssetName: "cutscene_poster_affr_in",
            voiceoverKey: "cutscene.cs-isl-affr-in.subtitle",
            mapNode: .affricates
        ),
        Cutscene(
            id: "cs-isl-affr-out",
            kind: .islandTriumph,
            trigger: .islandComplete(.affricates),
            videoResourceName: "cs_isl_affr_out",
            posterAssetName: "cutscene_poster_affr_out",
            voiceoverKey: "cutscene.cs-isl-affr-out.subtitle",
            mapNode: .affricates
        ),
        // Соноры (Р/Л) — кульминация.
        Cutscene(
            id: "cs-isl-sonor-in",
            kind: .islandIntro,
            trigger: .islandIntro(.sonorant),
            videoResourceName: "cs_isl_sonor_in",
            posterAssetName: "cutscene_poster_sonor_in",
            voiceoverKey: "cutscene.cs-isl-sonor-in.subtitle",
            mapNode: .sonorant
        ),
        Cutscene(
            id: "cs-isl-sonor-out",
            kind: .islandTriumph,
            trigger: .islandComplete(.sonorant),
            videoResourceName: "cs_isl_sonor_out",
            posterAssetName: "cutscene_poster_sonor_out",
            voiceoverKey: "cutscene.cs-isl-sonor-out.subtitle",
            mapNode: .sonorant
        ),
        // Заднеязычные (К/Г/Х).
        Cutscene(
            id: "cs-isl-velar-in",
            kind: .islandIntro,
            trigger: .islandIntro(.velar),
            videoResourceName: "cs_isl_velar_in",
            posterAssetName: "cutscene_poster_velar_in",
            voiceoverKey: "cutscene.cs-isl-velar-in.subtitle",
            mapNode: .velar
        ),
        Cutscene(
            id: "cs-isl-velar-out",
            kind: .islandTriumph,
            trigger: .islandComplete(.velar),
            videoResourceName: "cs_isl_velar_out",
            posterAssetName: "cutscene_poster_velar_out",
            voiceoverKey: "cutscene.cs-isl-velar-out.subtitle",
            mapNode: .velar
        ),
        // Грамматика.
        Cutscene(
            id: "cs-isl-grammar-in",
            kind: .islandIntro,
            trigger: .islandIntro(.special),
            videoResourceName: "cs_isl_grammar_in",
            posterAssetName: "cutscene_poster_grammar_in",
            voiceoverKey: "cutscene.cs-isl-grammar-in.subtitle",
            mapNode: .special
        ),
        Cutscene(
            id: "cs-isl-grammar-out",
            kind: .islandTriumph,
            trigger: .islandComplete(.special),
            videoResourceName: "cs_isl_grammar_out",
            posterAssetName: "cutscene_poster_grammar_out",
            voiceoverKey: "cutscene.cs-isl-grammar-out.subtitle",
            mapNode: .special
        )
    ]

    // MARK: Финал + майлстоуны

    private static let finaleAndMilestones: [Cutscene] = [
        Cutscene(
            id: "cs-finale",
            kind: .finale,
            trigger: .allIslandsComplete,
            videoResourceName: "cs_finale",
            posterAssetName: "cutscene_poster_finale",
            voiceoverKey: "cutscene.cs-finale.subtitle",
            mapNode: nil
        ),
        Cutscene(
            id: "cs-streak-7",
            kind: .milestone,
            trigger: .streak(days: 7),
            videoResourceName: "cs_streak_7",
            posterAssetName: "cutscene_poster_streak_7",
            voiceoverKey: "cutscene.cs-streak-7.subtitle",
            mapNode: nil
        ),
        Cutscene(
            id: "cs-streak-30",
            kind: .milestone,
            trigger: .streak(days: 30),
            videoResourceName: "cs_streak_30",
            posterAssetName: "cutscene_poster_streak_30",
            voiceoverKey: "cutscene.cs-streak-30.subtitle",
            mapNode: nil
        )
    ]

    // MARK: - Lookup

    /// Находит кат-сцену по триггеру. Для `.islandIntro` / `.islandComplete`
    /// матчит остров; для `.streak` — точное число дней.
    static func cutscene(for trigger: CutsceneTrigger) -> Cutscene? {
        all.first { $0.trigger == trigger }
    }

    /// Находит кат-сцену по `id`.
    static func cutscene(id: String) -> Cutscene? {
        all.first { $0.id == id }
    }

    /// Кат-сцены для «кинозала» в HelpCenter (read-only пересмотр, parent-контур).
    /// Только включённые; порядок — как в каталоге (нарративный).
    static var movieReel: [Cutscene] {
        all.filter { $0.enabled }
    }
}

// MARK: - MapIslandID Codable conformance

// `MapIslandID` объявлен в `Features/WorldMap/WorldMapInteractor.swift` как
// `String`-enum. Здесь добавляем `Codable` для JSON-зеркала каталога — это не
// меняет существующее поведение и нужно только сериализации сидов.
extension MapIslandID: Codable {}
