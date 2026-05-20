import Foundation
import OSLog

// MARK: - FingerPlayCorpus
//
// Загружает 16 пальчиковых упражнений из бандла `pack_fingerplay.json`.
// На случай отказа бандла — три безопасных fallback-упражнения, чтобы
// модуль оставался рабочим.

enum FingerPlayCorpus {

    static let exercises: [FingerExercise] = FingerPlayPackLoader.shared.exercises

    /// Сессия из 5 случайных упражнений.
    static func sessionExercises(count: Int = 5) -> [FingerExercise] {
        Array(exercises.shuffled().prefix(count))
    }
}

// MARK: - Loader

struct FingerPlayPackLoader {

    static let shared = FingerPlayPackLoader()

    let exercises: [FingerExercise]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FingerPlay.PackLoader"
    )

    private struct Pack: Decodable {
        let exercises: [ExerciseDTO]
    }

    private struct ExerciseDTO: Decodable {
        let id: String
        let title: String
        let rhyme: String
        let stages: [StageDTO]
    }

    private struct StageDTO: Decodable {
        let target: String
        let symbol: String
        let description: String
        let reps: Int
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "pack_fingerplay", withExtension: "json") else {
            Self.logger.error("pack_fingerplay.json not found in bundle — using fallback corpus")
            self.exercises = Self.fallback()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            self.exercises = pack.exercises.map { dto in
                FingerExercise(
                    id: dto.id,
                    title: dto.title,
                    rhymeText: dto.rhyme,
                    stages: dto.stages.map { stage in
                        FingerStage(
                            targetPose: stage.target,
                            symbol: stage.symbol,
                            description: stage.description,
                            repetitions: stage.reps
                        )
                    }
                )
            }
            let count = self.exercises.count
            Self.logger.info("Loaded \(count) finger-play exercises.")
        } catch {
            Self.logger.error("Decode failed: \(error.localizedDescription) — fallback")
            self.exercises = Self.fallback()
        }
    }

    private static func fallback() -> [FingerExercise] {
        [
            FingerExercise(
                id: "fp_fallback_zaichik",
                title: "Зайчик",
                rhymeText: "Зайчик прыг, зайчик скок — поднял ушки на бочок.",
                stages: [
                    FingerStage(targetPose: "point",
                                symbol: "hand.point.up.left.fill",
                                description: "Подними ушки зайчика.",
                                repetitions: 1)
                ]
            ),
            FingerExercise(
                id: "fp_fallback_ladoshka",
                title: "Ладошка",
                rhymeText: "Ладушки-ладушки.",
                stages: [
                    FingerStage(targetPose: "open_palm",
                                symbol: "hand.raised.fill",
                                description: "Покажи ладошку.",
                                repetitions: 1)
                ]
            ),
            FingerExercise(
                id: "fp_fallback_kulak",
                title: "Кулачок",
                rhymeText: "Этот пальчик хочет спать.",
                stages: [
                    FingerStage(targetPose: "fist",
                                symbol: "hand.raised.fingers.spread.fill",
                                description: "Сожми кулачок.",
                                repetitions: 1)
                ]
            )
        ]
    }
}
