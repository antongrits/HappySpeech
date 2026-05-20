import Foundation
import OSLog

// MARK: - LogorhythmicsCorpus

/// Стат-фасад над `pack_logorhythmics.json`. При отказе бандла отдаёт
/// безопасный fallback из 3 chants, чтобы фича оставалась рабочей.
enum LogorhythmicsCorpus {

    static let exercises: [LogorhythmicsExercise] = LogorhythmicsPackLoader.shared.exercises
    static let categoriesInOrder: [String] = LogorhythmicsPackLoader.shared.categoriesInOrder
    static let categoryTitles: [String: String] = LogorhythmicsPackLoader.shared.categoryTitles

    /// Группирует chants по категориям, сохраняя порядок из `categoriesInOrder`.
    static func grouped() -> [(category: String, items: [LogorhythmicsExercise])] {
        categoriesInOrder.map { category in
            (category, exercises.filter { $0.category == category })
        }
    }

    /// Поиск упражнения по id.
    static func exercise(id: String) -> LogorhythmicsExercise? {
        exercises.first { $0.id == id }
    }
}

// MARK: - Loader

struct LogorhythmicsPackLoader {

    static let shared = LogorhythmicsPackLoader()

    let exercises: [LogorhythmicsExercise]
    let categoriesInOrder: [String]
    let categoryTitles: [String: String]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Logorhythmics.PackLoader"
    )

    // MARK: - DTOs

    private struct Pack: Decodable {
        let categoriesInOrder: [String]
        let categoryTitles: [String: String]
        let exercises: [ExerciseDTO]
    }

    private struct ExerciseDTO: Decodable {
        let id: String
        let title: String
        let ageMin: Int
        let category: String
        let bpm: Int
        let patternSource: String
        let syllables: [String]
        let pattern: [Int]
        let strongBeats: [Int]
        let rhymeText: String
    }

    // MARK: - Init

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_logorhythmics",
            withExtension: "json"
        ) else {
            Self.logger.error("pack_logorhythmics.json not found — using fallback corpus")
            self.exercises = Self.fallback()
            self.categoriesInOrder = ["топот", "хлопок", "качание"]
            self.categoryTitles = [
                "топот": "Шаги и топот",
                "хлопок": "Ладушки",
                "качание": "Качание"
            ]
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            self.categoriesInOrder = pack.categoriesInOrder
            self.categoryTitles = pack.categoryTitles
            self.exercises = pack.exercises.map { dto in
                // Защита от мисматча длин (на случай ручной правки JSON).
                let pattern = dto.pattern.count == dto.syllables.count
                    ? dto.pattern
                    : Array(repeating: 1, count: dto.syllables.count)
                return LogorhythmicsExercise(
                    id: dto.id,
                    title: dto.title,
                    ageMin: dto.ageMin,
                    category: dto.category,
                    bpm: max(40, min(160, dto.bpm)),
                    patternSource: dto.patternSource,
                    syllables: dto.syllables,
                    pattern: pattern,
                    strongBeats: dto.strongBeats,
                    rhymeText: dto.rhymeText
                )
            }
            let count = self.exercises.count
            Self.logger.info("Loaded \(count) logorhythmics chants.")
        } catch {
            Self.logger.error("Decode failed: \(error.localizedDescription) — fallback corpus")
            self.exercises = Self.fallback()
            self.categoriesInOrder = ["топот", "хлопок", "качание"]
            self.categoryTitles = [
                "топот": "Шаги и топот",
                "хлопок": "Ладушки",
                "качание": "Качание"
            ]
        }
    }

    // MARK: - Fallback (на случай отсутствия бандла)

    private static func fallback() -> [LogorhythmicsExercise] {
        [
            LogorhythmicsExercise(
                id: "fb_topotushki",
                title: "Топ-топ топотушки",
                ageMin: 5,
                category: "топот",
                bpm: 90,
                patternSource: "approximation_by_syllables",
                syllables: ["Топ", "топ", "то", "по", "туш", "ки"],
                pattern: [1, 1, 1, 1, 1, 1],
                strongBeats: [0, 4],
                rhymeText: "Топ-топ топотушки!"
            ),
            LogorhythmicsExercise(
                id: "fb_baraban",
                title: "Барабан",
                ageMin: 6,
                category: "топот",
                bpm: 100,
                patternSource: "approximation_by_syllables",
                syllables: ["Ба", "ра", "бан", "ба", "ра", "бан"],
                pattern: [1, 1, 2, 1, 1, 2],
                strongBeats: [0, 3],
                rhymeText: "Барабан, барабан!"
            ),
            LogorhythmicsExercise(
                id: "fb_khlop",
                title: "Хлоп-хлоп",
                ageMin: 5,
                category: "хлопок",
                bpm: 80,
                patternSource: "approximation_by_syllables",
                syllables: ["Хлоп", "хлоп", "ла", "до", "шки"],
                pattern: [1, 1, 1, 1, 1],
                strongBeats: [0, 2],
                rhymeText: "Хлоп-хлоп, ладошки!"
            )
        ]
    }
}
