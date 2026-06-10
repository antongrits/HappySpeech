import Foundation
import OSLog

// MARK: - VideoCatalog
//
// Type-safe реестр Lyalya-cartoon и articulation-demo видеоклипов.
//
// Источники:
// - `Resources/Videos/Lyalya/videos_manifest.json` — 20 cartoon-клипов (greetings,
//   emotions, objects, scenes), голос Ляли как пчёлка.
// - `Resources/Videos/Articulation/articulation_manifest.json` — 15 анатомических
//   demo-роликов (Р/Ш/С/Л), kawaii anatomical illustration.
//
// `Videos/` подключён в project.yml как folder-reference, поэтому подпапки
// `Lyalya/` и `Articulation/` сохраняются внутри .app bundle.
//
// Использование:
// ```swift
// if let url = VideoCatalog.url(for: .lyalya(.waveHello)) {
//     // VideoPlayer(player: AVPlayer(url: url))
// }
// ```
//
// Метаданные манифестов кэшируются лениво на первом обращении. Конкретный
// эталонный список enum-cases синхронизирован с manifest-файлами; новые
// клипы добавляются вручную (compiler-time guarantee на используемые имена).

enum VideoCatalog {

    // MARK: - Public types

    /// Один из 20 Lyalya-cartoon клипов (Resources/Videos/Lyalya/*.mp4).
    enum LyalyaClip: String, CaseIterable, Sendable {
        // greetings
        case waveHello = "wave_hello"
        case excitedJump = "excited_jump"
        case clapping
        case flying
        case bouncing
        // emotions
        case happyDance = "happy_dance"
        case thinkingPose = "thinking_pose"
        case surprised
        case proudStand = "proud_stand"
        case sleepyYawn = "sleepy_yawn"
        // objects
        case pointingRight = "pointing_right"
        case holdingStar = "holding_star"
        case playingDrum = "playing_drum"
        case readingBook = "reading_book"
        case painting
        // scenes
        case forestPath = "forest_path"
        case nightStars = "night_stars"
        case rainbowFly = "rainbow_fly"
        case flowerGarden = "flower_garden"
        case sunnyDay = "sunny_day"
    }

    /// Один из 15 articulation-demo клипов (Resources/Videos/Articulation/*.mp4).
    enum ArticulationDemo: String, CaseIterable, Sendable {
        // Р (4)
        case rTonguePosition = "r_tongue_position"
        case rBarabanshchik = "r_barabanshchik"
        case rMotorchik = "r_motorchik"
        case rDyatel = "r_dyatel"
        // Ш (4)
        case shCupPosition = "sh_cup_position"
        case shAirFlow = "sh_air_flow"
        case shLipRound = "sh_lip_round"
        case shZhukZhuzhit = "sh_zhuk_zhuzhit"
        // С (4)
        case sTongueLow = "s_tongue_low"
        case sAirCool = "s_air_cool"
        case sSmileLips = "s_smile_lips"
        case sZmeyaShipit = "s_zmeya_shipit"
        // Л (3)
        case lTongueTipAlveolar = "l_tongue_tip_alveolar"
        case lSideAir = "l_side_air"
        case lLopata = "l_lopata"
        // Программные side-view профили (Remotion, 1280×720, научно корректные)
        case articulationSProfile = "articulation_s_profile"
        case articulationShProfile = "articulation_sh_profile"
        case articulationRProfile = "articulation_r_profile"
        case articulationLProfile = "articulation_l_profile"
        // Озвонченные профили: артикуляция = глухой аналог, отличие — работа голоса
        case articulationZProfile = "articulation_z_profile"
        case articulationZhProfile = "articulation_zh_profile"
    }

    /// Унифицированная ссылка на видео в каталоге.
    enum Reference: Sendable {
        case lyalya(LyalyaClip)
        case articulation(ArticulationDemo)
    }

    /// Метаданные клипа (длительность + размер файла).
    struct Metadata: Sendable {
        let slug: String
        let durationSeconds: Double
        let fileSizeBytes: Int
    }

    // MARK: - Public API

    /// URL `.mp4`-файла клипа в .app bundle. `nil` если файл отсутствует
    /// (асимметрия с манифестом → log warning).
    static func url(for reference: Reference) -> URL? {
        switch reference {
        case .lyalya(let clip):
            return Bundle.main.url(
                forResource: clip.rawValue,
                withExtension: "mp4",
                subdirectory: "Videos/Lyalya"
            )
        case .articulation(let demo):
            // Программные side-view профили лежат в подпапке programmatic/
            let subdirectory: String
            switch demo {
            case .articulationSProfile, .articulationShProfile,
                 .articulationRProfile, .articulationLProfile,
                 .articulationZProfile, .articulationZhProfile:
                subdirectory = "Videos/Articulation/programmatic"
            default:
                subdirectory = "Videos/Articulation"
            }
            return Bundle.main.url(
                forResource: demo.rawValue,
                withExtension: "mp4",
                subdirectory: subdirectory
            )
        }
    }

    /// Метаданные клипа из соответствующего манифеста (`nil` если не найден).
    static func metadata(for reference: Reference) -> Metadata? {
        switch reference {
        case .lyalya(let clip):
            return lyalyaIndex[clip.rawValue]
        case .articulation(let demo):
            return articulationIndex[demo.rawValue]
        }
    }

    /// Возвращает все клипы articulation-семьи (Р/Ш/С/Л).
    /// `family` — заглавная русская буква-имя звука.
    static func articulationDemos(for family: String) -> [ArticulationDemo] {
        articulationFamilyMap[family] ?? []
    }

    // MARK: - Lazy-loaded indices

    private static let lyalyaIndex: [String: Metadata] = {
        loadIndex(
            manifestName: "videos_manifest",
            subdirectory: "Videos/Lyalya",
            slugKey: "slug",
            durationKey: "duration_seconds",
            sizeKey: "file_size_bytes"
        )
    }()

    private static let articulationIndex: [String: Metadata] = {
        loadIndex(
            manifestName: "articulation_manifest",
            subdirectory: "Videos/Articulation",
            slugKey: "slug",
            durationKey: "duration_seconds",
            sizeKey: "file_size_bytes"
        )
    }()

    private static let articulationFamilyMap: [String: [ArticulationDemo]] = {
        var result: [String: [ArticulationDemo]] = [:]
        guard let url = Bundle.main.url(
            forResource: "articulation_manifest",
            withExtension: "json",
            subdirectory: "Videos/Articulation"
        ),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [:] }

        for entry in entries {
            guard let slug = entry["slug"] as? String,
                  let family = entry["soundFamily"] as? String,
                  let demo = ArticulationDemo(rawValue: slug)
            else { continue }
            result[family, default: []].append(demo)
        }
        return result
    }()

    // MARK: - Private helpers

    private static func loadIndex(
        manifestName: String,
        subdirectory: String,
        slugKey: String,
        durationKey: String,
        sizeKey: String
    ) -> [String: Metadata] {
        let logger = Logger(subsystem: "ru.happyspeech", category: "VideoCatalog")

        guard let url = Bundle.main.url(
            forResource: manifestName,
            withExtension: "json",
            subdirectory: subdirectory
        ),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            logger.warning("\(manifestName, privacy: .public).json missing or malformed in \(subdirectory, privacy: .public)")
            return [:]
        }

        var result: [String: Metadata] = [:]
        for entry in entries {
            guard let slug = entry[slugKey] as? String else { continue }
            let duration = (entry[durationKey] as? Double) ?? 0
            let size = (entry[sizeKey] as? Int) ?? 0
            result[slug] = Metadata(slug: slug, durationSeconds: duration, fileSizeBytes: size)
        }
        logger.info("VideoCatalog: \(result.count, privacy: .public) entries from \(manifestName, privacy: .public)")
        return result
    }
}
